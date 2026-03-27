/*import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'chat_message.dart';

class MemoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _groqApiKey;
  final String _groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  MemoryService({required String groqApiKey}) : _groqApiKey = groqApiKey;

  // Extract and save memories from conversation
  Future<void> extractAndSaveMemories({
    required String userId,
    required String userMessage,
    required String aiResponse,
  }) async {
    try {
      // Use Groq to extract important information
      final extractedMemories = await _extractMemoriesWithAI(
        userMessage: userMessage,
        aiResponse: aiResponse,
      );

      // Save each memory to database
      for (var memory in extractedMemories) {
        await _saveMemory(userId: userId, memory: memory);
      }
    } catch (e) {
      print('Error extracting memories: $e');
    }
  }

  // Use AI to extract memories from conversation
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
              'content': '''You are a memory extraction system. Analyze conversations and extract important information to remember about the user.

Extract information in this JSON format:
{
  "memories": [
    {
      "type": "important_event|preference|relationship|goal|concern|achievement",
      "category": "personal|work|family|health|hobby|education",
      "content": "brief description of what to remember",
      "importance": "high|medium|low",
      "keywords": ["keyword1", "keyword2"],
      "emotionalContext": "description of emotional state"
    }
  ]
}

Only extract genuinely important information worth remembering long-term.
If nothing important, return empty memories array.'''
            },
            {
              'role': 'user',
              'content': '''User said: "$userMessage"
AI responded: "$aiResponse"

Extract important memories from this exchange.'''
            }
          ],
          'temperature': 0.3,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // Parse JSON response
        final memoryData = jsonDecode(content);
        return List<Map<String, dynamic>>.from(memoryData['memories'] ?? []);
      }
    } catch (e) {
      print('Error in AI memory extraction: $e');
    }

    return [];
  }

  // Save memory to database
  Future<void> _saveMemory({
    required String userId,
    required Map<String, dynamic> memory,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('memories')
        .add({
      ...memory,
      'createdAt': FieldValue.serverTimestamp(),
      'lastAccessed': FieldValue.serverTimestamp(),
    });
  }

  // Load user's memories for context
  Future<String> loadUserMemoryContext(String userId) async {
    try {
      // Get recent memories (last 30 days)
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('memories')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) {
        return 'This is a new user. No previous memories.';
      }

      // Build context string
      final memories = snapshot.docs.map((doc) {
        final data = doc.data();
        return '- [${data['type']}] ${data['content']} (${data['emotionalContext']})';
      }).join('\n');

      return '''User's Memory Capsule (Important things to remember):
$memories

Use this context to provide personalized responses and ask follow-up questions.''';
    } catch (e) {
      print('Error loading memories: $e');
      return 'This is a new user. No previous memories.';
    }
  }

  // Get conversation starters based on memories
  Future<List<String>> getPersonalizedQuestions(String userId) async {
    try {
      final memoryContext = await loadUserMemoryContext(userId);

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
              'content': '''Based on the user's memories, generate 3 thoughtful follow-up questions.
Format as JSON:
{
  "questions": ["question1", "question2", "question3"]
}'''
            },
            {
              'role': 'user',
              'content': memoryContext
            }
          ],
          'temperature': 0.8,
          'max_tokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        final questionsData = jsonDecode(content);
        return List<String>.from(questionsData['questions'] ?? []);
      }
    } catch (e) {
      print('Error generating questions: $e');
    }

    return [
      'How are you feeling today?',
      'What\'s on your mind?',
      'Tell me about your day!'
    ];
  }

  // Update user profile with emotional patterns
  Future<void> updateEmotionalProfile({
    required String userId,
    required String sentiment,
    required List<String> topics,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);

    await userRef.set({
      'lastActive': FieldValue.serverTimestamp(),
      'emotionalHistory': FieldValue.arrayUnion([
        {
          'sentiment': sentiment,
          'timestamp': DateTime.now().toIso8601String(),
        }
      ]),
    }, SetOptions(merge: true));
  }

  // Save conversation
  Future<void> saveConversation({
    required String userId,
    required List<ChatMessage> messages,
    required String dominantSentiment,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .add({
      'messages': messages
          .map((m) => {
                'text': m.text,
                'isUser': m.isUser,
                'timestamp': m.timestamp.toIso8601String(),
                'sentiment': m.sentiment,
              })
          .toList(),
      'dominantSentiment': dominantSentiment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Search memories by keyword
  Future<List<Map<String, dynamic>>> searchMemories({
    required String userId,
    required String keyword,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('memories')
        .where('keywords', arrayContains: keyword.toLowerCase())
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get memory statistics
  Future<Map<String, dynamic>> getMemoryStats(String userId) async {
    final snapshot = await _firestore
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
  }
}


/*import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save conversation directly as memory
  Future<void> saveConversationAsMemory({
    required String userId,
    required String userMessage,
    required String aiResponse,
    String? sentiment,
  }) async {
    try {
      print('💾 Saving conversation for user: $userId');
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .add({
        'userMessage': userMessage,
        'aiResponse': aiResponse,
        'sentiment': sentiment ?? 'neutral',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('✅ Conversation saved successfully');
    } catch (e) {
      print('❌ Error saving conversation: $e');
    }
  }

  // Load recent conversations for context
  Future<String> loadConversationHistory(String userId) async {
    try {
      print('📂 Loading conversation history for: $userId');
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .orderBy('timestamp', descending: true)
          .limit(10) // Get last 10 conversations
          .get();

      print('📊 Found ${snapshot.docs.length} previous conversations');

      if (snapshot.docs.isEmpty) {
        print('⚠️ No previous conversations found');
        return 'This is a new user. No previous conversations.';
      }

      // Build conversation history in reverse order (oldest first)
      final conversations = snapshot.docs.reversed.map((doc) {
        final data = doc.data();
        return 'User: ${data['userMessage']}\nBuddy: ${data['aiResponse']}';
      }).join('\n\n');

      final fullContext = '''Previous conversations with this user:

$conversations

Important: Use this conversation history to:
1. Remember what the user has told you before
2. Ask relevant follow-up questions
3. Show that you care by recalling past discussions
4. Be consistent with previous responses''';

      print('✅ Conversation history loaded successfully');
      return fullContext;
      
    } catch (e) {
      print('❌ Error loading conversation history: $e');
      return 'This is a new user. No previous conversations.';
    }
  }

  // Get conversation statistics
  Future<Map<String, dynamic>> getConversationStats(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .get();

      final conversations = snapshot.docs.map((doc) => doc.data()).toList();
      
      // Count sentiments
      final sentimentCounts = <String, int>{};
      for (var conv in conversations) {
        final sentiment = conv['sentiment'] ?? 'neutral';
        sentimentCounts[sentiment] = (sentimentCounts[sentiment] ?? 0) + 1;
      }

      // Find most common sentiment
      String dominantSentiment = 'neutral';
      int maxCount = 0;
      sentimentCounts.forEach((sentiment, count) {
        if (count > maxCount) {
          maxCount = count;
          dominantSentiment = sentiment;
        }
      });

      return {
        'totalConversations': conversations.length,
        'sentimentBreakdown': sentimentCounts,
        'dominantSentiment': dominantSentiment,
      };
    } catch (e) {
      print('❌ Error getting stats: $e');
      return {
        'totalConversations': 0,
        'sentimentBreakdown': {},
        'dominantSentiment': 'neutral',
      };
    }
  }

  // Get personalized greeting based on history
  Future<String> getPersonalizedGreeting(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 'Hello! I\'m your friendly buddy. How are you feeling today? 😊';
      }

      // User has chatted before
      final lastConv = snapshot.docs.first.data();
      final lastSentiment = lastConv['sentiment'] ?? 'neutral';

      switch (lastSentiment.toLowerCase()) {
        case 'happy':
        case 'positive':
          return 'Hello again! It\'s wonderful to see you! How have you been? 😊';
        case 'sad':
        case 'negative':
          return 'Hi there. I\'ve been thinking about you. How are you feeling today? 💙';
        case 'anxious':
          return 'Hello! I hope you\'re doing okay. I\'m here if you want to talk. 🤗';
        default:
          return 'Welcome back! It\'s good to see you again. How have things been? 😊';
      }
    } catch (e) {
      print('❌ Error getting greeting: $e');
      return 'Hello! How are you feeling today? 😊';
    }
  }

  // Clear conversation history (if user wants to start fresh)
  Future<void> clearConversationHistory(String userId) async {
    try {
      print('🗑️ Clearing conversation history for: $userId');
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      print('✅ Conversation history cleared');
    } catch (e) {
      print('❌ Error clearing history: $e');
    }
  }

  // Get recent topics discussed
  Future<List<String>> getRecentTopics(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      if (snapshot.docs.isEmpty) {
        return ['Tell me about yourself', 'How are you feeling?', 'What\'s on your mind?'];
      }

      // Extract key phrases from recent conversations
      final recentMessages = snapshot.docs.map((doc) {
        final data = doc.data();
        return data['userMessage'] as String;
      }).toList();

      // Simple topic extraction based on common keywords
      final topics = <String>[];
      
      for (var message in recentMessages) {
        final lower = message.toLowerCase();
        
        if (lower.contains('son') || lower.contains('daughter') || lower.contains('family')) {
          if (!topics.contains('How is your family doing?')) {
            topics.add('How is your family doing?');
          }
        }
        if (lower.contains('pain') || lower.contains('hurt') || lower.contains('sick')) {
          if (!topics.contains('How are you feeling physically?')) {
            topics.add('How are you feeling physically?');
          }
        }
        if (lower.contains('worry') || lower.contains('anxious') || lower.contains('stressed')) {
          if (!topics.contains('What\'s been on your mind lately?')) {
            topics.add('What\'s been on your mind lately?');
          }
        }
        if (lower.contains('happy') || lower.contains('excited') || lower.contains('good')) {
          if (!topics.contains('What made you happy recently?')) {
            topics.add('What made you happy recently?');
          }
        }
      }

      if (topics.isEmpty) {
        return ['Tell me more about what we discussed last time', 'How has your day been?', 'Anything new you\'d like to share?'];
      }

      return topics;
      
    } catch (e) {
      print('❌ Error getting recent topics: $e');
      return ['How are you feeling?', 'What\'s on your mind?', 'Tell me about your day'];
    }
  }

  // Update user profile with basic info
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      final updates = <String, dynamic>{
        'lastActive': FieldValue.serverTimestamp(),
      };

      if (name != null) {
        updates['name'] = name;
      }

      if (preferences != null) {
        updates['preferences'] = preferences;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .set(updates, SetOptions(merge: true));

      print('✅ User profile updated');
    } catch (e) {
      print('❌ Error updating profile: $e');
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting profile: $e');
      return null;
    }
  }

  // Export conversation history (for backup or analysis)
  Future<List<Map<String, dynamic>>> exportConversations(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userMessage': data['userMessage'],
          'aiResponse': data['aiResponse'],
          'sentiment': data['sentiment'],
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate().toString() ?? 'Unknown',
        };
      }).toList();
    } catch (e) {
      print('❌ Error exporting conversations: $e');
      return [];
    }
  }

  // Check if user is returning (has previous conversations)
  Future<bool> isReturningUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking user status: $e');
      return false;
    }
  }

  // Get conversation count
  Future<int> getConversationCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Error getting conversation count: $e');
      return 0;
    }
  }
}
*/*/

//groq1
/*
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'chat_message.dart';

class MemoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _groqApiKey;
  final String _groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  MemoryService({required String groqApiKey}) : _groqApiKey = groqApiKey;

  // Extract and save memories from conversation
  Future<void> extractAndSaveMemories({
    required String userId,
    required String userMessage,
    required String aiResponse,
  }) async {
    try {
      // Use Groq to extract important information
      final extractedMemories = await _extractMemoriesWithAI(
        userMessage: userMessage,
        aiResponse: aiResponse,
      );

      // Save each memory to database
      for (var memory in extractedMemories) {
        await _saveMemory(userId: userId, memory: memory);
      }
    } catch (e) {
      print('Error extracting memories: $e');
    }
  }

  // Use AI to extract memories from conversation
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
              'content': '''You are a memory extraction system. Analyze conversations and extract important information to remember about the user.

Extract information in this JSON format:
{
  "memories": [
    {
      "type": "important_event|preference|relationship|goal|concern|achievement|personal_info",
      "category": "personal|work|family|health|hobby|education",
      "content": "detailed description of what to remember",
      "importance": "high|medium|low",
      "keywords": ["keyword1", "keyword2"],
      "emotionalContext": "description of emotional state",
      "specificDetails": {
        "names": ["any names mentioned"],
        "dates": ["any dates or timeframes"],
        "places": ["any locations mentioned"],
        "other": "any other specific details"
      }
    }
  ]
}

IMPORTANT: Extract ALL specific details like names, ages, relationships, places, dates, preferences, etc.
Only extract genuinely important information worth remembering long-term.
If nothing important, return empty memories array.'''
            },
            {
              'role': 'user',
              'content': '''User said: "$userMessage"
AI responded: "$aiResponse"

Extract important memories from this exchange.'''
            }
          ],
          'temperature': 0.3,
          'max_tokens': 800,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // Parse JSON response
        try {
          final memoryData = jsonDecode(content);
          return List<Map<String, dynamic>>.from(memoryData['memories'] ?? []);
        } catch (e) {
          print('Error parsing memory JSON: $e');
          print('Content was: $content');
          return [];
        }
      }
    } catch (e) {
      print('Error in AI memory extraction: $e');
    }

    return [];
  }

  // Save memory to database
  Future<void> _saveMemory({
    required String userId,
    required Map<String, dynamic> memory,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('memories')
        .add({
      ...memory,
      'createdAt': FieldValue.serverTimestamp(),
      'lastAccessed': FieldValue.serverTimestamp(),
      'accessCount': 0,
    });
  }

  // NEW: Get relevant memories based on current conversation context
  Future<List<Map<String, dynamic>>> getRelevantMemories({
    required String userId,
    required String currentMessage,
    int limit = 10,
  }) async {
    try {
      // Get all memories
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('memories')
          .orderBy('createdAt', descending: true)
          .limit(50) // Get more to filter from
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      final allMemories = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Use AI to select most relevant memories
      final relevantMemories = await _selectRelevantMemoriesWithAI(
        memories: allMemories,
        currentMessage: currentMessage,
        limit: limit,
      );

      // Update access count and timestamp for accessed memories
      for (var memory in relevantMemories) {
        if (memory['id'] != null) {
          _firestore
              .collection('users')
              .doc(userId)
              .collection('memories')
              .doc(memory['id'])
              .update({
            'lastAccessed': FieldValue.serverTimestamp(),
            'accessCount': FieldValue.increment(1),
          });
        }
      }

      return relevantMemories;
    } catch (e) {
      print('Error getting relevant memories: $e');
      return [];
    }
  }

  // NEW: Use AI to select most relevant memories
  Future<List<Map<String, dynamic>>> _selectRelevantMemoriesWithAI({
    required List<Map<String, dynamic>> memories,
    required String currentMessage,
    required int limit,
  }) async {
    if (memories.isEmpty) return [];

    try {
      // Create a simplified version of memories for the AI
      final memoryList = memories.map((m) => {
        'content': m['content'],
        'type': m['type'],
        'category': m['category'],
        'keywords': m['keywords'],
      }).toList();

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
              'content': '''You are a memory relevance analyzer. Given a user's current message and their past memories, 
select the most relevant memories that would help provide context for responding.

Return ONLY a JSON object in this format:
{
  "relevantIndices": [0, 3, 5]
}

The indices should correspond to the most relevant memories from the provided list.
Select up to $limit memories, prioritizing the most relevant ones.'''
            },
            {
              'role': 'user',
              'content': '''Current message: "$currentMessage"

Available memories:
${memoryList.asMap().entries.map((e) => '${e.key}: ${e.value}').join('\n')}

Select the most relevant memory indices.'''
            }
          ],
          'temperature': 0.2,
          'max_tokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        try {
          final result = jsonDecode(content);
          final indices = List<int>.from(result['relevantIndices'] ?? []);
          
          return indices
              .where((i) => i >= 0 && i < memories.length)
              .map((i) => memories[i])
              .toList();
        } catch (e) {
          print('Error parsing relevance JSON: $e');
          // Fallback: return most recent high-importance memories
          return memories
              .where((m) => m['importance'] == 'high')
              .take(limit)
              .toList();
        }
      }
    } catch (e) {
      print('Error in relevance selection: $e');
    }

    // Fallback: return most recent memories
    return memories.take(limit).toList();
  }

  // UPDATED: Load user's memories for context with better formatting
  Future<String> loadUserMemoryContext(String userId) async {
    try {
      // Get recent high and medium importance memories
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('memories')
          .where('importance', whereIn: ['high', 'medium'])
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      if (snapshot.docs.isEmpty) {
        return 'This is a new user. No previous memories.';
      }

      // Group memories by category
      final Map<String, List<String>> categorizedMemories = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] ?? 'general';
        final content = data['content'] ?? '';
        final type = data['type'] ?? '';
        final emotional = data['emotionalContext'] ?? '';
        
        if (!categorizedMemories.containsKey(category)) {
          categorizedMemories[category] = [];
        }
        
        String memoryEntry = '• [$type] $content';
        if (emotional.isNotEmpty) {
          memoryEntry += ' (emotional state: $emotional)';
        }
        
        // Add specific details if available
        if (data['specificDetails'] != null) {
          final details = data['specificDetails'] as Map<String, dynamic>;
          if (details['names'] != null && (details['names'] as List).isNotEmpty) {
            memoryEntry += ' [Names: ${(details['names'] as List).join(', ')}]';
          }
        }
        
        categorizedMemories[category]!.add(memoryEntry);
      }

      // Build formatted context
      final buffer = StringBuffer();
      buffer.writeln('USER\'S MEMORY CAPSULE - Important Information to Remember:');
      buffer.writeln('=' * 60);
      
      categorizedMemories.forEach((category, memories) {
        buffer.writeln('\n📌 ${category.toUpperCase()}:');
        for (var memory in memories) {
          buffer.writeln('  $memory');
        }
      });
      
      buffer.writeln('\n' + '=' * 60);
      buffer.writeln('INSTRUCTIONS:');
      buffer.writeln('- Reference these memories naturally when relevant');
      buffer.writeln('- Ask follow-up questions about mentioned topics');
      buffer.writeln('- Show that you remember previous conversations');
      buffer.writeln('- Use specific details (names, events) when appropriate');

      return buffer.toString();
    } catch (e) {
      print('Error loading memories: $e');
      return 'This is a new user. No previous memories.';
    }
  }

  // UPDATED: Build dynamic context for each message
  Future<String> buildDynamicContext({
    required String userId,
    required String currentMessage,
  }) async {
    final relevantMemories = await getRelevantMemories(
      userId: userId,
      currentMessage: currentMessage,
      limit: 5,
    );

    if (relevantMemories.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('\n🎯 RELEVANT MEMORIES FOR THIS CONVERSATION:');
    
    for (var memory in relevantMemories) {
      buffer.writeln('• ${memory['content']}');
      if (memory['specificDetails'] != null) {
        final details = memory['specificDetails'] as Map<String, dynamic>;
        if (details['names'] != null && (details['names'] as List).isNotEmpty) {
          buffer.writeln('  → Names: ${(details['names'] as List).join(', ')}');
        }
      }
    }
    
    buffer.writeln('\nUse these memories to provide personalized, context-aware responses.');

    return buffer.toString();
  }

  // Get conversation starters based on memories
  Future<List<String>> getPersonalizedQuestions(String userId) async {
    try {
      // Get recent memories
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('memories')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      if (snapshot.docs.isEmpty) {
        return [
          'How are you feeling today?',
          'What\'s on your mind?',
          'Tell me about your day!'
        ];
      }

      // Build memory summary
      final memories = snapshot.docs.map((doc) {
        final data = doc.data();
        return '- ${data['content']}';
      }).join('\n');

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
              'content': '''Based on the user's memories, generate 3 thoughtful, specific follow-up questions.
Make them personal and reference specific things mentioned in their memories.

Format as JSON:
{
  "questions": ["question1", "question2", "question3"]
}

Each question should be warm, caring, and reference something specific from their memories.'''
            },
            {
              'role': 'user',
              'content': 'User memories:\n$memories'
            }
          ],
          'temperature': 0.8,
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        try {
          final questionsData = jsonDecode(content);
          return List<String>.from(questionsData['questions'] ?? []);
        } catch (e) {
          print('Error parsing questions JSON: $e');
        }
      }
    } catch (e) {
      print('Error generating questions: $e');
    }

    return [
      'How are you feeling today?',
      'What\'s on your mind?',
      'Tell me about your day!'
    ];
  }

  // Update user profile with emotional patterns
  Future<void> updateEmotionalProfile({
    required String userId,
    required String sentiment,
    required List<String> topics,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);

    await userRef.set({
      'lastActive': FieldValue.serverTimestamp(),
      'emotionalHistory': FieldValue.arrayUnion([
        {
          'sentiment': sentiment,
          'timestamp': DateTime.now().toIso8601String(),
        }
      ]),
    }, SetOptions(merge: true));
  }

  // Save conversation
  Future<void> saveConversation({
    required String userId,
    required List<ChatMessage> messages,
    required String dominantSentiment,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .add({
      'messages': messages
          .map((m) => {
                'text': m.text,
                'isUser': m.isUser,
                'timestamp': m.timestamp.toIso8601String(),
                'sentiment': m.sentiment,
              })
          .toList(),
      'dominantSentiment': dominantSentiment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Search memories by keyword
  Future<List<Map<String, dynamic>>> searchMemories({
    required String userId,
    required String keyword,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('memories')
        .where('keywords', arrayContains: keyword.toLowerCase())
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get memory statistics
  Future<Map<String, dynamic>> getMemoryStats(String userId) async {
    final snapshot = await _firestore
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
  }
}
*/
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'chat_message.dart';

class MemoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _groqApiKey;
  final String _groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  MemoryService({required String groqApiKey}) : _groqApiKey = groqApiKey;

  // Extract and save memories from conversation
  Future<void> extractAndSaveMemories({
    required String userId,
    required String userMessage,
    required String aiResponse,
  }) async {
    try {
      //print('🧠 Starting memory extraction...');
      print('User: $userMessage');
      print('AI: $aiResponse');

      // Use Groq to extract important information
      final extractedMemories = await _extractMemoriesWithAI(
        userMessage: userMessage,
        aiResponse: aiResponse,
      );

      print('📝 Extracted ${extractedMemories.length} memories');

      // Save each memory to database
      for (var memory in extractedMemories) {
        // print('💾 Saving memory: ${memory['content']}');
        await _saveMemory(userId: userId, memory: memory);
      }

      //print('✅ Memory extraction complete');
    } catch (e) {
      //print('❌ Error extracting memories: $e');
      //print('Stack trace: ${StackTrace.current}');
    }
  }

  // Use AI to extract memories from conversation
  Future<List<Map<String, dynamic>>> _extractMemoriesWithAI({
    required String userMessage,
    required String aiResponse,
  }) async {
    try {
      //print('🤖 Calling Groq API for memory extraction...');

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
                  '''You are a memory extraction system. Analyze conversations and extract important information to remember about the user.

Extract information in this JSON format (ALWAYS return valid JSON):
{
  "memories": [
    {
      "type": "important_event|preference|relationship|goal|concern|achievement|personal_info",
      "category": "personal|work|family|health|hobby|education",
      "content": "detailed description of what to remember",
      "importance": "high|medium|low",
      "keywords": ["keyword1", "keyword2"],
      "emotionalContext": "description of emotional state",
      "specificDetails": {
        "names": ["any names mentioned"],
        "dates": ["any dates or timeframes"],
        "places": ["any locations mentioned"],
        "other": "any other specific details"
      }
    }
  ]
}

EXTRACTION RULES:
1. ALWAYS extract names mentioned (especially family members like son, daughter, partner, friends)
2. Extract emotional states and feelings
3. Extract life events (missing someone, visiting places, achievements, concerns)
4. Extract preferences and dislikes
5. Extract relationships and important people
6. Extract goals and aspirations
7. Extract health or wellbeing mentions

IMPORTANCE GUIDELINES:
- high: Names, major life events, important relationships, strong emotions, specific personal details
- medium: Preferences, minor events, general feelings
- low: Casual mentions, weather, generic topics

Even if the conversation seems casual, extract the emotional context and any personal details.
Return {"memories": []} ONLY if the conversation is completely generic with zero personal content.
ALWAYS return valid JSON, nothing else.''',
            },
            {
              'role': 'user',
              'content': '''User said: "$userMessage"
AI responded: "$aiResponse"

Extract important memories from this exchange. Return ONLY the JSON object, no additional text.''',
            },
          ],
          'temperature': 0.3,
          'max_tokens': 800,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String content = data['choices'][0]['message']['content'] ?? '';

        //print('📥 Raw AI response: $content');

        // Clean up the content - remove markdown code blocks if present
        content = content.trim();
        if (content.startsWith('```json')) {
          content = content.substring(7);
        }
        if (content.startsWith('```')) {
          content = content.substring(3);
        }
        if (content.endsWith('```')) {
          content = content.substring(0, content.length - 3);
        }
        content = content.trim();

        //print('🧹 Cleaned content: $content');

        // Parse JSON response
        try {
          final memoryData = jsonDecode(content);
          final memories = List<Map<String, dynamic>>.from(
            memoryData['memories'] ?? [],
          );
          //print('✨ Parsed ${memories.length} memories successfully');
          return memories;
        } catch (e) {
          //print('❌ Error parsing memory JSON: $e');
          //print('Content was: $content');
          return [];
        }
      } else {
        // print('❌ API error: ${response.statusCode}');
        // print('Response: ${response.body}');
      }
    } catch (e) {
      //print('❌ Error in AI memory extraction: $e');
      //print('Stack trace: ${StackTrace.current}');
    }

    return [];
  }

  // Save memory to database
  Future<void> _saveMemory({
    required String userId,
    required Map<String, dynamic> memory,
  }) async {
    try {
      //print('💾 Attempting to save memory to Firestore...');
      //print('   User ID: $userId');
      //print('   Memory content: ${memory['content']}');

      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('memories')
          .add({
            ...memory,
            'createdAt': FieldValue.serverTimestamp(),
            'lastAccessed': FieldValue.serverTimestamp(),
            'accessCount': 0,
          });

      //print('✅ Memory saved successfully with ID: ${docRef.id}');
    } catch (e) {
      //print('❌ Error saving memory to Firestore: $e');
      //print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // NEW: Get relevant memories based on current conversation context
  Future<List<Map<String, dynamic>>> getRelevantMemories({
    required String userId,
    required String currentMessage,
    int limit = 10,
  }) async {
    try {
      // Get all memories
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('memories')
              .orderBy('createdAt', descending: true)
              .limit(50) // Get more to filter from
              .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      final allMemories =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();

      // Use AI to select most relevant memories
      final relevantMemories = await _selectRelevantMemoriesWithAI(
        memories: allMemories,
        currentMessage: currentMessage,
        limit: limit,
      );

      // Update access count and timestamp for accessed memories
      for (var memory in relevantMemories) {
        if (memory['id'] != null) {
          _firestore
              .collection('users')
              .doc(userId)
              .collection('memories')
              .doc(memory['id'])
              .update({
                'lastAccessed': FieldValue.serverTimestamp(),
                'accessCount': FieldValue.increment(1),
              });
        }
      }

      return relevantMemories;
    } catch (e) {
      //print('Error getting relevant memories: $e');
      return [];
    }
  }

  // NEW: Use AI to select most relevant memories
  Future<List<Map<String, dynamic>>> _selectRelevantMemoriesWithAI({
    required List<Map<String, dynamic>> memories,
    required String currentMessage,
    required int limit,
  }) async {
    if (memories.isEmpty) return [];

    try {
      // Create a simplified version of memories for the AI
      final memoryList =
          memories
              .map(
                (m) => {
                  'content': m['content'],
                  'type': m['type'],
                  'category': m['category'],
                  'keywords': m['keywords'],
                },
              )
              .toList();

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
                  '''You are a memory relevance analyzer. Given a user's current message and their past memories, 
select the most relevant memories that would help provide context for responding.

Return ONLY a JSON object in this format:
{
  "relevantIndices": [0, 3, 5]
}

The indices should correspond to the most relevant memories from the provided list.
Select up to $limit memories, prioritizing the most relevant ones.''',
            },
            {
              'role': 'user',
              'content': '''Current message: "$currentMessage"

Available memories:
${memoryList.asMap().entries.map((e) => '${e.key}: ${e.value}').join('\n')}

Select the most relevant memory indices.''',
            },
          ],
          'temperature': 0.2,
          'max_tokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        try {
          final result = jsonDecode(content);
          final indices = List<int>.from(result['relevantIndices'] ?? []);

          return indices
              .where((i) => i >= 0 && i < memories.length)
              .map((i) => memories[i])
              .toList();
        } catch (e) {
          print('Error parsing relevance JSON: $e');
          // Fallback: return most recent high-importance memories
          return memories
              .where((m) => m['importance'] == 'high')
              .take(limit)
              .toList();
        }
      }
    } catch (e) {
      print('Error in relevance selection: $e');
    }

    // Fallback: return most recent memories
    return memories.take(limit).toList();
  }

  // UPDATED: Load user's memories for context with better formatting
  Future<String> loadUserMemoryContext(String userId) async {
    try {
      // Get recent high and medium importance memories
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('memories')
              .where('importance', whereIn: ['high', 'medium'])
              .orderBy('createdAt', descending: true)
              .limit(30)
              .get();

      if (snapshot.docs.isEmpty) {
        return 'This is a new user. No previous memories.';
      }

      // Group memories by category
      final Map<String, List<String>> categorizedMemories = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] ?? 'general';
        final content = data['content'] ?? '';
        final type = data['type'] ?? '';
        final emotional = data['emotionalContext'] ?? '';

        if (!categorizedMemories.containsKey(category)) {
          categorizedMemories[category] = [];
        }

        String memoryEntry = '• [$type] $content';
        if (emotional.isNotEmpty) {
          memoryEntry += ' (emotional state: $emotional)';
        }

        // Add specific details if available
        if (data['specificDetails'] != null) {
          final details = data['specificDetails'] as Map<String, dynamic>;
          if (details['names'] != null &&
              (details['names'] as List).isNotEmpty) {
            memoryEntry += ' [Names: ${(details['names'] as List).join(', ')}]';
          }
        }

        categorizedMemories[category]!.add(memoryEntry);
      }

      // Build formatted context
      final buffer = StringBuffer();
      buffer.writeln(
        'USER\'S MEMORY CAPSULE - Important Information to Remember:',
      );
      buffer.writeln('=' * 60);

      categorizedMemories.forEach((category, memories) {
        buffer.writeln('\n📌 ${category.toUpperCase()}:');
        for (var memory in memories) {
          buffer.writeln('  $memory');
        }
      });

      buffer.writeln('\n' + '=' * 60);
      buffer.writeln('INSTRUCTIONS:');
      buffer.writeln('- Reference these memories naturally when relevant');
      buffer.writeln('- Ask follow-up questions about mentioned topics');
      buffer.writeln('- Show that you remember previous conversations');
      buffer.writeln('- Use specific details (names, events) when appropriate');

      return buffer.toString();
    } catch (e) {
      //print('Error loading memories: $e');
      return 'This is a new user. No previous memories.';
    }
  }

  // UPDATED: Build dynamic context for each message
  Future<String> buildDynamicContext({
    required String userId,
    required String currentMessage,
  }) async {
    final relevantMemories = await getRelevantMemories(
      userId: userId,
      currentMessage: currentMessage,
      limit: 5,
    );

    if (relevantMemories.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('\n🎯 RELEVANT MEMORIES FOR THIS CONVERSATION:');

    for (var memory in relevantMemories) {
      buffer.writeln('• ${memory['content']}');
      if (memory['specificDetails'] != null) {
        final details = memory['specificDetails'] as Map<String, dynamic>;
        if (details['names'] != null && (details['names'] as List).isNotEmpty) {
          buffer.writeln('  → Names: ${(details['names'] as List).join(', ')}');
        }
      }
    }

    buffer.writeln(
      '\nUse these memories to provide personalized, context-aware responses.',
    );

    return buffer.toString();
  }

  // Get conversation starters based on memories
  Future<List<String>> getPersonalizedQuestions(String userId) async {
    try {
      // Get recent memories
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('memories')
              .orderBy('createdAt', descending: true)
              .limit(10)
              .get();

      if (snapshot.docs.isEmpty) {
        return [
          'How are you feeling today?',
          'What\'s on your mind?',
          'Tell me about your day!',
        ];
      }

      // Build memory summary
      final memories = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return '- ${data['content']}';
          })
          .join('\n');

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
                  '''Based on the user's memories, generate 3 thoughtful, specific follow-up questions.
Make them personal and reference specific things mentioned in their memories.

Format as JSON:
{
  "questions": ["question1", "question2", "question3"]
}

Each question should be warm, caring, and reference something specific from their memories.''',
            },
            {'role': 'user', 'content': 'User memories:\n$memories'},
          ],
          'temperature': 0.8,
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        try {
          final questionsData = jsonDecode(content);
          return List<String>.from(questionsData['questions'] ?? []);
        } catch (e) {
          //print('Error parsing questions JSON: $e');
        }
      }
    } catch (e) {
      //print('Error generating questions: $e');
    }

    return [
      'How are you feeling today?',
      'What\'s on your mind?',
      'Tell me about your day!',
    ];
  }

  // Update user profile with emotional patterns
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

  // Save conversation
  Future<void> saveConversation({
    required String userId,
    required List<ChatMessage> messages,
    required String dominantSentiment,
  }) async {
    try {
      /*print('💬 Saving conversation...');
      print('   User ID: $userId');
      print('   Number of messages: ${messages.length}');
      print('   Dominant sentiment: $dominantSentiment');*/

      final docRef = await _firestore
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

      //print('✅ Conversation saved successfully with ID: ${docRef.id}');
    } catch (e) {
      //print('❌ Error saving conversation: $e');
      //print('Stack trace: ${StackTrace.current}');
    }
  }

  // Search memories by keyword
  Future<List<Map<String, dynamic>>> searchMemories({
    required String userId,
    required String keyword,
  }) async {
    final snapshot =
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('memories')
            .where('keywords', arrayContains: keyword.toLowerCase())
            .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get memory statistics
  Future<Map<String, dynamic>> getMemoryStats(String userId) async {
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
  }

  // Test function to manually save a memory (for debugging)
  Future<void> testSaveMemory(String userId) async {
    try {
      //print('🧪 Testing manual memory save...');
      await _saveMemory(
        userId: userId,
        memory: {
          'type': 'personal_info',
          'category': 'personal',
          'content': 'Test memory - manual save',
          'importance': 'high',
          'keywords': ['test'],
          'emotionalContext': 'testing',
          'specificDetails': {
            'names': ['Test User'],
            'dates': [],
            'places': [],
            'other': 'Manual test',
          },
        },
      );
      //print('✅ Test memory saved successfully');
    } catch (e) {
      //print('❌ Test memory save failed: $e');
    }
  }
}
