import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/elderly/chat_message.dart';

class EnhancedMemoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _groqApiKey;
  final String _groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  EnhancedMemoryService({required String groqApiKey})
    : _groqApiKey = groqApiKey;

  // Extract and save memories with enhanced sentiment analysis
  Future<void> extractAndSaveMemories({
    required String userId,
    required String elderlyId,
    required String userMessage,
    required String aiResponse,
  }) async {
    try {
      // Use Groq to extract important information with sentiment
      final extractedMemories = await _extractMemoriesWithAI(
        userMessage: userMessage,
        aiResponse: aiResponse,
      );

      if (extractedMemories.isEmpty) {
        // Log that an interaction occurred even if no specific memory was extracted
        await _logBuddyActivity(
          elderlyId: elderlyId,
          activityType: 'interaction',
          title: 'Had a conversation with Buddy',
          severity: 'low',
        );
      }

      // Save each memory to database
      for (var memory in extractedMemories) {
        await _saveMemory(userId: userId, elderlyId: elderlyId, memory: memory);

        // Check if this memory requires caretaker notification
        await _checkAndNotifyCaretaker(
          elderlyId: elderlyId,
          memory: memory,
          userMessage: userMessage,
        );

        // Always log buddy activity for the wellness tab
        await _logBuddyActivity(
          elderlyId: elderlyId,
          activityType: memory['type'] ?? 'interaction',
          title:
              memory['content'] != null &&
                      memory['content'].toString().length > 30
                  ? '${memory['content'].toString().substring(0, 30)}...'
                  : memory['content'] ?? 'Buddy Interaction',
          severity: memory['urgency'] ?? 'low',
        );
      }
    } catch (e) {
      print('Error extracting memories: $e');
    }
  }

  // Helper to extract JSON from AI response strings that might contain conversational preamble
  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return text;
  }

  // Enhanced AI memory extraction with sentiment and urgency detection
  Future<List<Map<String, dynamic>>> _extractMemoriesWithAI({
    required String userMessage,
    required String aiResponse,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content':
                  '''You are a memory extraction system for an elderly care app. Analyze conversations and extract important information with special attention to:

1. EMOTIONAL STATE (loneliness, sadness, anxiety, happiness, etc.)
2. MISSING PEOPLE (family, friends mentioned with longing)
3. HEALTH CONCERNS
4. URGENT NEEDS
5. DAILY ACTIVITIES
6. PREFERENCES AND RELATIONSHIPS

Extract information in this JSON format:
{
  "memories": [
    {
      "type": "important_event|preference|relationship|goal|concern|achievement|loneliness|missing_someone|health_concern",
      "category": "personal|work|family|health|hobby|education|emotional",
      "content": "brief description of what to remember",
      "importance": "high|medium|low",
      "urgency": "urgent|moderate|low",
      "keywords": ["keyword1", "keyword2"],
      "emotionalContext": "detailed description of emotional state",
      "sentiment": "positive|negative|neutral|sad|anxious|lonely|happy",
      "requiresCaretakerNotification": true/false,
      "specificDetails": {
        "missingPerson": "name of person they miss (if mentioned)",
        "emotionalIntensity": "high|medium|low",
        "triggerWords": ["miss", "lonely", "worried", etc.]
      }
    }
  ]
}

CRITICAL: Set "requiresCaretakerNotification" to TRUE if:
- User mentions missing someone
- User expresses loneliness or isolation
- User mentions health concerns
- User expresses sadness, depression, or anxiety
- User mentions not eating properly or sleeping issues
- Any urgent or concerning behavior

Only extract genuinely important information worth remembering long-term.''',
            },
            {
              'role': 'user',
              'content': '''User said: "$userMessage"
AI responded: "$aiResponse"

Extract important memories with emphasis on emotional state and any concerning patterns.''',
            },
          ],
          'temperature': 0.3,
          'max_tokens': 800,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        // Parse JSON response robustly
        final cleanedJson = _extractJson(content);
        final memoryData = jsonDecode(cleanedJson);
        return List<Map<String, dynamic>>.from(memoryData['memories'] ?? []);
      }
    } catch (e) {
      print('Error in AI memory extraction: $e');
    }

    return [];
  }

  // Load user's memories into context string for the AI
  Future<String> loadUserMemoryContext(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('memories')
              .orderBy('createdAt', descending: true)
              .limit(15)
              .get();

      if (snapshot.docs.isEmpty) {
        return "This is a new user with no previous memories recorded yet.";
      }

      final memories = snapshot.docs.map((doc) => doc.data()).toList();
      String context =
          "Here is what you know about this user from previous conversations:\n";
      for (var memory in memories) {
        context +=
            "- ${memory['content']} (Related to: ${memory['category']}, Sentiment: ${memory['sentiment']})\n";
      }
      return context;
    } catch (e) {
      print('Error loading memory context: $e');
      return "Unable to load previous memories.";
    }
  }

  // Get personalized questions based on user's memories
  Future<List<String>> getPersonalizedQuestions(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('memories')
              .orderBy('lastAccessed', descending: true)
              .limit(8)
              .get();

      if (snapshot.docs.isEmpty) {
        return [
          "How are you feeling today?",
          "What's on your mind?",
          "Is there anything you'd like to share?",
        ];
      }

      final memoriesText = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return "- ${data['content']} (${data['type']})";
          })
          .join("\n");

      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a caring companion assistant. Based on these user memories, generate 3 thoughtful, open-ended follow-up questions to ask the user. Return ONLY a JSON object: {"questions": ["q1", "q2", "q3"]}',
            },
            {'role': 'user', 'content': 'Known memories:\n$memoriesText'},
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        final cleanedJson = _extractJson(content);
        final json = jsonDecode(cleanedJson);
        return List<String>.from(json['questions'] ?? []);
      }
    } catch (e) {
      print('Error getting personalized questions: $e');
    }
    return [
      "How was your day?",
      "What have you been up to?",
      "How are you feeling?",
    ];
  }

  // Build dynamic context for a specific message by finding relevant past memories
  Future<String> buildDynamicContext({
    required String userId,
    required String currentMessage,
  }) async {
    try {
      // Simplified retrieval: get most recent memories
      // (Could be improved with semantic search/keyword matching)
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('memories')
              .orderBy('lastAccessed', descending: true)
              .limit(5)
              .get();

      if (snapshot.docs.isEmpty) return "";

      String context =
          "Specifically, you remember these things that might be relevant:\n";
      for (var doc in snapshot.docs) {
        context += "- ${doc.data()['content']}\n";
        // Update last accessed time
        doc.reference.update({'lastAccessed': FieldValue.serverTimestamp()});
      }
      return context;
    } catch (e) {
      print('Error building dynamic context: $e');
      return "";
    }
  }

  // Save memory to database with elderly association
  Future<void> _saveMemory({
    required String userId,
    required String elderlyId,
    required Map<String, dynamic> memory,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('memories')
        .add({
          ...memory,
          'elderlyId': elderlyId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastAccessed': FieldValue.serverTimestamp(),
          'accessCount': 0,
        });
  }

  // Check if caretaker needs to be notified
  Future<void> _checkAndNotifyCaretaker({
    required String elderlyId,
    required Map<String, dynamic> memory,
    required String userMessage,
  }) async {
    try {
      // Check if notification is required
      final requiresNotification =
          memory['requiresCaretakerNotification'] == true ||
          memory['urgency'] == 'urgent' ||
          memory['type'] == 'missing_someone' ||
          memory['type'] == 'loneliness' ||
          memory['type'] == 'health_concern';

      if (!requiresNotification) return;

      // Get caretaker ID for this elderly person
      final elderlyDoc =
          await _firestore.collection('users').doc(elderlyId).get();

      String? caretakerId = elderlyDoc.data()?['caretakerId'];

      if (caretakerId == null || caretakerId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        caretakerId = prefs.getString('caretaker_id');
        if (caretakerId != null && caretakerId.isNotEmpty) {
          await _firestore.collection('users').doc(elderlyId).set({
            'caretakerId': caretakerId,
          }, SetOptions(merge: true));
        }
      }

      if (caretakerId == null || caretakerId.isEmpty) return;

      // Create notification
      await _createCaretakerNotification(
        caretakerId: caretakerId,
        elderlyId: elderlyId,
        memory: memory,
        userMessage: userMessage,
      );
    } catch (e) {
      print('Error checking/notifying caretaker: $e');
    }
  }

  // Create a notification for the caretaker
  Future<void> _createCaretakerNotification({
    required String caretakerId,
    required String elderlyId,
    required Map<String, dynamic> memory,
    required String userMessage,
  }) async {
    try {
      // Get elderly person's name
      final elderlyDoc =
          await _firestore.collection('users').doc(elderlyId).get();
      final elderlyName = elderlyDoc.data()?['name'] ?? 'Your loved one';

      // Determine notification type and message
      String notificationType = 'alert';
      String title = 'Attention Required';
      String message = 'Check on $elderlyName';
      String severity = 'moderate';

      if (memory['type'] == 'missing_someone' ||
          memory['type'] == 'loneliness') {
        title = 'Loneliness Detected';
        message = '$elderlyName mentioned missing someone or feeling lonely';
        severity = 'urgent';
        notificationType = 'loneliness';
      } else if (memory['type'] == 'health_concern') {
        title = 'Health Concern';
        message = '$elderlyName mentioned a health issue';
        severity = 'urgent';
        notificationType = 'health';
      } else if (memory['urgency'] == 'urgent') {
        title = 'Urgent Alert';
        message = '$elderlyName needs attention';
        severity = 'urgent';
      }

      // Save notification to elderly profile's buddy_notifications collection (for persistence)
      await _firestore
          .collection('users')
          .doc(elderlyId)
          .collection('buddy_notifications')
          .add({
            'type': notificationType,
            'title': title,
            'message': message,
            'severity': severity,
            'elderlyId': elderlyId,
            'elderlyName': elderlyName,
            'originalMessage': userMessage,
            'memoryType': memory['type'],
            'emotionalContext': memory['emotionalContext'],
            'sentiment': memory['sentiment'],
            'specificDetails': memory['specificDetails'],
            'isRead': false,
            'isResolved': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Also save to caretaker's notifications collection for the main dashboard alert
      await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('notifications')
          .add({
            'type': 'buddy_alert',
            'title': title,
            'message': message,
            'severity': severity,
            'elderlyId': elderlyId,
            'elderlyName': elderlyName,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      print('✅ Caretaker notification created: $title');
    } catch (e) {
      print('Error creating caretaker notification: $e');
    }
  }

  // Log activity in buddy activity log
  Future<void> _logBuddyActivity({
    required String elderlyId,
    required String activityType,
    required String title,
    required String severity,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(elderlyId)
          .collection('buddy_activities')
          .add({
            'type': activityType,
            'title': title,
            'severity': severity,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error logging buddy activity: $e');
    }
  }

  // Generate weekly sentiment analysis report for caretaker
  Future<void> generateWeeklySentimentReport({
    required String elderlyId,
  }) async {
    try {
      // Get elderly person's caretaker
      final elderlyDoc =
          await _firestore.collection('users').doc(elderlyId).get();

      final caretakerId = elderlyDoc.data()?['caretakerId'];
      final elderlyName = elderlyDoc.data()?['name'] ?? 'Your loved one';

      if (caretakerId == null) return;

      // Get conversations from the last 7 days
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));

      final conversationsSnapshot =
          await _firestore
              .collection('users')
              .doc(elderlyId)
              .collection('conversations')
              .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
              .get();

      if (conversationsSnapshot.docs.isEmpty) {
        print('No conversations found for weekly report');
        return;
      }

      // Analyze sentiment patterns
      final sentimentData = await _analyzeSentimentPatterns(
        elderlyId: elderlyId,
        conversationsSnapshot: conversationsSnapshot,
      );

      // Generate AI-powered summary
      final reportSummary = await _generateReportSummary(
        elderlyName: elderlyName,
        sentimentData: sentimentData,
      );

      // Check for existing weekly report in the elderly profile
      String? existingWeeklyDocId;
      final existingWeeklySnapshot = await _firestore
          .collection('users')
          .doc(elderlyId)
          .collection('buddy_weekly_reports')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final targetDate = DateTime.now();
      for (final doc in existingWeeklySnapshot.docs) {
          final data = doc.data();
          final ts = data['createdAt'] as Timestamp?;
          if (ts != null && ts.toDate().year == targetDate.year && ts.toDate().month == targetDate.month && (ts.toDate().day - targetDate.day).abs() <= 3) {
              existingWeeklyDocId = doc.id;
              break;
          }
      }

      final reportData = {
        'elderlyId': elderlyId,
        'elderlyName': elderlyName,
        'reportPeriod': {
          'start': Timestamp.fromDate(weekAgo),
          'end': Timestamp.now(),
        },
        'sentimentData': sentimentData,
        'summary': reportSummary,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Save report to elderly profile
      if (existingWeeklyDocId != null) {
          await _firestore
              .collection('users')
              .doc(elderlyId)
              .collection('buddy_weekly_reports')
              .doc(existingWeeklyDocId)
              .set(reportData, SetOptions(merge: true));
      } else {
          await _firestore
              .collection('users')
              .doc(elderlyId)
              .collection('buddy_weekly_reports')
              .add(reportData);
      }

      // Send notification about new report
      await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('notifications')
          .add({
            'type': 'weekly_report',
            'title': 'Weekly Wellness Report',
            'message': 'New weekly report available for $elderlyName',
            'severity': 'info',
            'elderlyId': elderlyId,
            'elderlyName': elderlyName,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      print('✅ Weekly sentiment report generated for $elderlyName');
    } catch (e) {
      print('Error generating weekly report: $e');
    }
  }

  // Generate a weekly sentiment report for a SPECIFIC historical period (for backfill)
  Future<void> generateWeeklySentimentReportForPeriod({
    required String elderlyId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      final elderlyDoc = await _firestore.collection('users').doc(elderlyId).get();
      final caretakerId = elderlyDoc.data()?['caretakerId'];
      final elderlyName = elderlyDoc.data()?['name'] ?? 'Your loved one';
      if (caretakerId == null) return;

      final conversationsSnapshot = await _firestore
          .collection('users')
          .doc(elderlyId)
          .collection('conversations')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
          .where('createdAt', isLessThan: Timestamp.fromDate(periodEnd))
          .get();

      if (conversationsSnapshot.docs.isEmpty) {
        print('No conversations found for $elderlyId in period $periodStart – $periodEnd');
        return;
      }

      final sentimentData = await _analyzeSentimentPatterns(
        elderlyId: elderlyId,
        conversationsSnapshot: conversationsSnapshot,
      );

      final reportSummary = await _generateReportSummary(
        elderlyName: elderlyName,
        sentimentData: sentimentData,
      );

      final reportData = {
        'elderlyId': elderlyId,
        'elderlyName': elderlyName,
        'reportPeriod': {
          'start': Timestamp.fromDate(periodStart),
          'end': Timestamp.fromDate(periodEnd),
        },
        'sentimentData': sentimentData,
        'summary': reportSummary,
        'createdAt': Timestamp.fromDate(periodEnd), // date it as week end for ordering
        'isRead': false,
        'isBackfilled': true,
      };

      String? existingWeeklyDocId;
      final existingWeeklySnapshot = await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('weekly_reports')
          .where('elderlyId', isEqualTo: elderlyId)
          .get();

      final existingDocs = existingWeeklySnapshot.docs.toList();
      existingDocs.sort((a, b) {
        final tsA = a.data()['createdAt'] as Timestamp?;
        final tsB = b.data()['createdAt'] as Timestamp?;
        if (tsA == null) return 1;
        if (tsB == null) return -1;
        return tsB.compareTo(tsA);
      });

      for (final doc in existingDocs) {
          final data = doc.data();
          final ts = data['createdAt'] as Timestamp?;
          if (ts != null && ts.toDate().year == periodEnd.year && ts.toDate().month == periodEnd.month && (ts.toDate().day - periodEnd.day).abs() <= 3) {
              existingWeeklyDocId = doc.id;
              break;
          }
      }

      if (existingWeeklyDocId != null) {
          await _firestore
              .collection('users')
              .doc(elderlyId)
              .collection('buddy_weekly_reports')
              .doc(existingWeeklyDocId)
              .set(reportData, SetOptions(merge: true));
      } else {
          await _firestore
              .collection('users')
              .doc(elderlyId)
              .collection('buddy_weekly_reports')
              .add(reportData);
      }

      print('✅ Backfill sentiment report saved for $elderlyName ($periodStart)');
    } catch (e) {
      print('Error generating backfill sentiment report: $e');
    }
  }

  // Analyze sentiment patterns from conversations
  Future<Map<String, dynamic>> _analyzeSentimentPatterns({
    required String elderlyId,
    required QuerySnapshot conversationsSnapshot,
  }) async {
    final sentimentCounts = <String, int>{};
    //final emotionalTrends = <String, List<Map<String, dynamic>>>[];
    final concerningPatterns = <String>[];
    int totalMessages = 0;

    for (var doc in conversationsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final messages = data['messages'] as List<dynamic>;

      for (var message in messages) {
        final sentiment = message['sentiment'];
        if (sentiment != null) {
          sentimentCounts[sentiment] = (sentimentCounts[sentiment] ?? 0) + 1;
          totalMessages++;
        }
      }
    }

    // Get memories from the week for additional context
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final memoriesSnapshot =
        await _firestore
            .collection('users')
            .doc(elderlyId)
            .collection('memories')
            .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
            .get();

    // Analyze memories for patterns
    for (var doc in memoriesSnapshot.docs) {
      final memory = doc.data();
      if (memory['type'] == 'loneliness' ||
          memory['type'] == 'missing_someone' ||
          memory['sentiment'] == 'sad' ||
          memory['sentiment'] == 'anxious') {
        concerningPatterns.add(memory['content']);
      }
    }

    // Calculate percentages
    final sentimentPercentages = <String, double>{};
    if (totalMessages > 0) {
      sentimentCounts.forEach((sentiment, count) {
        sentimentPercentages[sentiment] = (count / totalMessages) * 100;
      });
    }

    return {
      'sentimentCounts': sentimentCounts,
      'sentimentPercentages': sentimentPercentages,
      'totalMessages': totalMessages,
      'concerningPatterns': concerningPatterns,
      'dominantSentiment': _getDominantSentiment(sentimentCounts),
      'emotionalWellnessScore': _calculateWellnessScore(sentimentPercentages),
    };
  }

  // Generate AI-powered report summary
  Future<String> _generateReportSummary({
    required String elderlyName,
    required Map<String, dynamic> sentimentData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content':
                  '''You are a compassionate care assistant generating a weekly emotional wellness report for a caretaker. 
              
Analyze the sentiment data and provide:
1. Overall emotional state summary (2-3 sentences)
2. Key observations and patterns
3. Specific recommendations for the caretaker
4. Any concerns that need attention

Be warm, professional, and actionable. Focus on both positive aspects and areas needing support.''',
            },
            {
              'role': 'user',
              'content': '''Generate a weekly report summary for $elderlyName.

Sentiment Data:
${jsonEncode(sentimentData)}

Provide a comprehensive yet concise summary that a caretaker can act upon.''',
            },
          ],
          'temperature': 0.7,
          'max_tokens': 600,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? 'Report generated';
      }
    } catch (e) {
      print('Error generating report summary: $e');
    }

    return 'Weekly emotional wellness report generated. Please review the detailed metrics.';
  }

  // Helper: Get dominant sentiment
  String _getDominantSentiment(Map<String, int> sentimentCounts) {
    if (sentimentCounts.isEmpty) return 'neutral';

    var maxCount = 0;
    var dominantSentiment = 'neutral';

    sentimentCounts.forEach((sentiment, count) {
      if (count > maxCount) {
        maxCount = count;
        dominantSentiment = sentiment;
      }
    });

    return dominantSentiment;
  }

  // Helper: Calculate wellness score (0-100)
  double _calculateWellnessScore(Map<String, double> percentages) {
    double score = 50.0; // Base score

    // Positive sentiments increase score
    score += (percentages['positive'] ?? 0) * 0.5;
    score += (percentages['happy'] ?? 0) * 0.5;

    // Negative sentiments decrease score
    score -= (percentages['negative'] ?? 0) * 0.5;
    score -= (percentages['sad'] ?? 0) * 0.6;
    score -= (percentages['anxious'] ?? 0) * 0.6;
    score -= (percentages['lonely'] ?? 0) * 0.7;

    // Ensure score is between 0 and 100
    return score.clamp(0.0, 100.0);
  }

  // Load user's memories for context (existing method)
  // Build dynamic context for each message (existing method)
  // Get relevant memories based on current message
  Future<List<Map<String, dynamic>>> getRelevantMemories({
    required String userId,
    required String currentMessage,
    required int limit,
  }) async {
    try {
      // Simple keyword-based retrieval
      final messageLower = currentMessage.toLowerCase();
      final keywords =
          messageLower.split(' ').where((word) => word.length > 3).toList();

      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('memories')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();

      final relevantMemories = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final memory = doc.data();
        final content = (memory['content'] ?? '').toString().toLowerCase();
        final memoryKeywords = memory['keywords'] as List<dynamic>? ?? [];

        // Check if any keyword matches
        for (var keyword in keywords) {
          if (content.contains(keyword) ||
              memoryKeywords.any(
                (mk) => mk.toString().toLowerCase().contains(keyword),
              )) {
            relevantMemories.add(memory);
            break;
          }
        }

        if (relevantMemories.length >= limit) break;
      }

      return relevantMemories;
    } catch (e) {
      print('Error getting relevant memories: $e');
      return [];
    }
  }

  // Get personalized questions (existing method)
  // Update emotional profile (existing method)
  Future<void> updateEmotionalProfile({
    required String userId,
    required String sentiment,
    required List<String> topics,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);

    await userRef.set({
      'lastActive': FieldValue.serverTimestamp(),
      'emotionalHistory': FieldValue.arrayUnion([
        {'sentiment': sentiment, 'timestamp': DateTime.now().toIso8601String()},
      ]),
    }, SetOptions(merge: true));
  }

  // Save conversation (existing method)
  Future<void> saveConversation({
    required String userId,
    required List<ChatMessage> messages,
    required String dominantSentiment,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .add({
            'messages':
                messages
                    .map(
                      (m) => {
                        'text': m.text,
                        'isUser': m.isUser,
                        'timestamp': m.timestamp.toIso8601String(),
                        'sentiment': m.sentiment,
                      },
                    )
                    .toList(),
            'dominantSentiment': dominantSentiment,
            'messageCount': messages.length,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error saving conversation: $e');
    }
  }

  // Get memory statistics (used by BuddyChatScreen memory capsule dialog)
  Future<Map<String, dynamic>> getMemoryStats(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('memories')
              .get();

      final memories = snapshot.docs.map((doc) => doc.data()).toList();
      final categories = <String, int>{};
      final types = <String, int>{};

      for (var memory in memories) {
        final category = memory['category'] ?? 'unknown';
        final type = memory['type'] ?? 'unknown';
        categories[category] = (categories[category] ?? 0) + 1;
        types[type] = (types[type] ?? 0) + 1;
      }

      return {
        'totalMemories': memories.length,
        'categories': categories,
        'types': types,
      };
    } catch (e) {
      print('Error getting memory stats: \$e');
      return {'totalMemories': 0, 'categories': {}, 'types': {}};
    }
  }
}
