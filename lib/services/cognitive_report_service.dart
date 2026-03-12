import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/cognitive/cognitive_report.dart';
import 'caretaker_data_service.dart';

class CognitiveReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _groqApiKey;
  final String _groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  final CaretakerDataService _dataService = CaretakerDataService();

  CognitiveReportService({required String groqApiKey}) : _groqApiKey = groqApiKey;

  static const Map<String, List<String>> _gameDomainMapping = {
    'Color Tap': ['Attention', 'Processing Speed'],
    'Color Tap (Reaction)': ['Attention', 'Processing Speed'],
    'Flip Card': ['Memory'],
    'Flip Card Match': ['Memory'],
    'City Atlas': ['Executive Function', 'Memory'],
    'Event Ordering': ['Executive Function', 'Memory'],
    'Routine Recall': ['Memory', 'Executive Function'],
    'Monument Recall': ['Memory', 'Language'],
  };

  /// Generates a daily cognitive report for a specific user
  Future<void> generateDailyCognitiveReport(
    String elderlyId, {
    String? caretakerIdOverride,
  }) async {
    try {
      // 1. Get user profile
      final userDoc = await _firestore.collection('users').doc(elderlyId).get();
      if (!userDoc.exists) return;
      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'Elderly User';
      final caretakerId = userData['caretakerId'];
      if (caretakerId == null) return;

      // 2. Fetch game sessions for the last 24 hours
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final sessions = await _fetchRecentSessions(elderlyId, yesterday);

      if (sessions.isEmpty) {
        print('No game sessions found for $userName in the last 24h. Skipping daily report.');
        return;
      }

      // 3. Calculate domains FOR TODAY specifically
      final todayScores = _calculateTodayScores(sessions);

      // 4. Get current historical cognitive health summary (for context/comparison)
      final historicalSummary = await _dataService.getCognitiveHealthFuture(elderlyId);

      // 5. Prepare data for Groq
      final gamesDataSummary = _prepareGamesSummary(sessions);

      // 6. Call Groq
      final aiReport = await _getAIAnalysis(
        userName: userName,
        gamesSummary: gamesDataSummary,
        domainScores: historicalSummary,
        todayScores: todayScores,
        type: 'daily',
      );

      // 7. Save Report
      final sessionDetails = sessions.map((s) {
        return {
          'gameType': _normalizeGameType(s['gameType']),
          'score': s['score'] ?? 0,
          'accuracy': s['accuracy'],
          'average_reaction_time': s['average_reaction_time'],
          'efficiency': s['efficiency'],
          'metrics': s['metrics'] ?? {},
          'playedAt': _extractSessionTime(s['createdAt'] ?? s['timestamp'])?.toIso8601String(),
        };
      }).toList();

      final contributions = _calculateContributions(sessions);

      final report = CognitiveReport(
        id: '', // Firestore will generate
        elderlyId: elderlyId,
        elderlyName: userName,
        date: DateTime.now(),
        type: 'daily',
        domainScores: todayScores, // Store today's specific scores in the report
        overallScore: _calculateOverallAverage(todayScores),
        analysis: aiReport['analysis'] ?? '',
        suggestions: List<String>.from(aiReport['suggestions'] ?? []),
        metadata: {
          'sessionCount': sessions.length,
          'gamesPlayed': sessions.map((s) => s['gameType']).toSet().toList(),
          'historicalAverage': historicalSummary['overallScore'],
          'sessionDetails': sessionDetails,
          'domainContributions': contributions['domainContributions'],
          'overallContributions': contributions['overallContributions'],
          'activeDomainCount': contributions['activeDomainCount'],
        },
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .add(report.toMap());

      print('✅ Daily cognitive report generated for $userName');
    } catch (e) {
      print('❌ Error generating daily cognitive report: $e');
    }
  }

  /// Generates a weekly cognitive report by comparing daily reports
  Future<void> generateWeeklyCognitiveReport(String elderlyId, {DateTime? periodStart, DateTime? periodEnd}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(elderlyId).get();
      final caretakerId = userDoc.data()?['caretakerId'];
      final userName = userDoc.data()?['name'] ?? 'Elderly User';
      if (caretakerId == null) return;

      // Use supplied period or default to last 7 days
      final effectiveEnd = periodEnd ?? DateTime.now();
      final effectiveStart = periodStart ?? effectiveEnd.subtract(const Duration(days: 7));

      // 1. Fetch daily reports from the requested period
      final reportsSnapshot = await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .where('elderlyId', isEqualTo: elderlyId)
          .where('type', isEqualTo: 'daily')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveStart))
          .where('date', isLessThan: Timestamp.fromDate(effectiveEnd))
          .get();

      if (reportsSnapshot.docs.isEmpty) {
        print('Not enough daily reports to generate weekly summary for $userName in $effectiveStart – $effectiveEnd');
        return;
      }

      final dailyReports = reportsSnapshot.docs.map((doc) => doc.data()).toList();
      final dailyReportsForAi = _formatDailyReportsForAi(dailyReports);
      final weeklyTrendData = _buildWeeklyTrendData(dailyReports);

      // 2. Call Groq for Trend Analysis
      final aiReport = await _getAIAnalysis(
        userName: userName,
        dailyReports: dailyReportsForAi,
        weeklyTrendData: weeklyTrendData,
        type: 'weekly',
      );

      // 3. Calculate Average Overall Score for the week
      int avgScore = 0;
      if (dailyReports.isNotEmpty) {
        final num sum = dailyReports.fold<num>(
          0,
          (prev, element) => prev + ((element['overallScore'] as num?) ?? 0),
        );
        avgScore = (sum / dailyReports.length).round();
      }

      // 4. Save Weekly Report
      final report = CognitiveReport(
        id: '',
        elderlyId: elderlyId,
        elderlyName: userName,
        date: effectiveEnd,
        type: 'weekly',
        domainScores: {}, // Weekly is a trend, domains are in text
        overallScore: avgScore,
        analysis: aiReport['analysis'] ?? '',
        suggestions: List<String>.from(aiReport['suggestions'] ?? []),
        metadata: {
          'dailyReportsAnalyzed': dailyReports.length,
          'periodStart': effectiveStart.toIso8601String(),
          'periodEnd': effectiveEnd.toIso8601String(),
          if (periodStart != null) 'isBackfilled': true,
        },
        createdAt: effectiveEnd,
      );

      await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .add(report.toMap());

      print('✅ Weekly cognitive trend report generated for $userName ($effectiveStart)');
    } catch (e) {
      print('❌ Error generating weekly cognitive report: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRecentSessions(String userId, DateTime since) async {
    final List<Map<String, dynamic>> all = [];
    
    // Fetch from all 3 collections
    final collections = ['colorTapGameSessions', 'flipCardGameSessions', 'game_sessions'];
    
    for (var col in collections) {
      if (col == 'game_sessions') {
        // Avoid composite indexes by filtering client-side
        final snap = await _firestore
            .collection(col)
            .where('userId', isEqualTo: userId)
            .limit(200)
            .get();
        for (var doc in snap.docs) {
          final data = doc.data();
          final sessionTime = _extractSessionTime(data['timestamp'] ?? data['createdAt']);
          if (sessionTime != null && sessionTime.isAfter(since)) {
            data['gameType'] = _normalizeGameType(data['gameType']);
            data['createdAt'] = data['timestamp'] ?? data['createdAt'];
            all.add(data);
          }
        }
      } else {
        final snap = await _firestore
            .collection(col)
            .where('userId', isEqualTo: userId)
            .limit(200)
            .get();
        
        for (var doc in snap.docs) {
          final data = doc.data();
          final sessionTime = _extractSessionTime(data['createdAt']);
          if (sessionTime != null && sessionTime.isAfter(since)) {
            data['gameType'] = data['gameType'] ??
                (col == 'colorTapGameSessions' ? 'Color Tap' : 'Flip Card');
            all.add(data);
          }
        }
      }
    }
    return all;
  }

  DateTime? _extractSessionTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) {
      // assume milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  String _normalizeGameType(dynamic raw) {
    final String gameType = raw?.toString() ?? 'Unknown';
    switch (gameType) {
      case 'city_atlas':
        return 'City Atlas';
      case 'event_ordering':
        return 'Event Ordering';
      case 'daily_routine_recall':
        return 'Routine Recall';
      case 'monument_recall':
        return 'Monument Recall';
      case 'Color Tap (Reaction)':
        return 'Color Tap';
      case 'Flip Card Match':
        return 'Flip Card';
      default:
        return gameType;
    }
  }

  Map<String, dynamic> _calculateContributions(List<Map<String, dynamic>> sessions) {
    final Map<String, Map<String, double>> gameToDomain = {};
    final Map<String, double> domainTotals = {};

    for (final s in sessions) {
      final game = _normalizeGameType(s['gameType']);
      gameToDomain.putIfAbsent(game, () => {});

      // Base contributions by game type
      if (game == 'Color Tap') {
        final accuracy = (s['accuracy'] as num?)?.toDouble() ?? 0.0;
        final rt = (s['average_reaction_time'] as num?)?.toDouble() ?? 2.0;
        final attention = accuracy * 100;
        final processingSpeed = ((2.0 - rt).clamp(0.0, 2.0) * 50);
        _addContribution(gameToDomain[game]!, 'attention', attention);
        _addContribution(gameToDomain[game]!, 'processingSpeed', processingSpeed);
      } else if (game == 'Flip Card') {
        final efficiency = (s['efficiency'] as num?)?.toDouble() ?? 0.0;
        final memory = efficiency * 100;
        _addContribution(gameToDomain[game]!, 'memory', memory);
      }

      // Add any cognitive_contributions from backend
      final cognitive = s['cognitive_contributions'] as Map<String, dynamic>? ?? {};
      cognitive.forEach((key, value) {
        String domainKey = key;
        if (key == 'executive_function') domainKey = 'executiveFunction';
        if (domainKey == 'processing_speed') domainKey = 'processingSpeed';
        if (domainKey == 'language') domainKey = 'language';
        if (domainKey == 'memory') domainKey = 'memory';
        if (domainKey == 'attention') domainKey = 'attention';
        _addContribution(gameToDomain[game]!, domainKey, (value as num).toDouble());
      });
    }

    // Totals per domain
    for (final entry in gameToDomain.entries) {
      for (final d in entry.value.entries) {
        domainTotals[d.key] = (domainTotals[d.key] ?? 0) + d.value;
      }
    }

    final activeDomains = domainTotals.entries.where((e) => e.value > 0).map((e) => e.key).toList();
    final int activeDomainCount = activeDomains.length;

    // Compute percentages per domain and overall contribution per game
    final Map<String, dynamic> domainContributions = {};
    final Map<String, double> overallContributions = {};

    for (final entry in gameToDomain.entries) {
      final game = entry.key;
      final Map<String, double> perDomain = {};
      double overallShare = 0;

      for (final d in entry.value.entries) {
        final total = domainTotals[d.key] ?? 0;
        final share = total > 0 ? (d.value / total) : 0.0;
        perDomain[d.key] = double.parse((share * 100).toStringAsFixed(1));
        if (activeDomainCount > 0) {
          overallShare += share / activeDomainCount;
        }
      }

      domainContributions[game] = perDomain;
      overallContributions[game] = double.parse((overallShare * 100).toStringAsFixed(1));
    }

    return {
      'domainContributions': domainContributions,
      'overallContributions': overallContributions,
      'activeDomainCount': activeDomainCount,
    };
  }

  void _addContribution(Map<String, double> map, String key, double value) {
    map[key] = (map[key] ?? 0) + value;
  }

  /// Generates a daily report only if one hasn't been created today
  Future<void> generateDailyCognitiveReportIfMissing(
    String elderlyId, {
    String? caretakerIdOverride,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(elderlyId).get();
      if (!userDoc.exists) return;
      final userData = userDoc.data()!;
      final caretakerId = caretakerIdOverride ?? userData['caretakerId'];
      if (caretakerId == null) return;

      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final recentSnapshot = await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .orderBy('date', descending: true)
          .limit(25)
          .get();

      for (final doc in recentSnapshot.docs) {
        final data = doc.data();
        if (data['elderlyId'] == elderlyId && data['type'] == 'daily') {
          final ts = data['date'] as Timestamp?;
          if (ts != null && !ts.toDate().isBefore(todayStart)) {
            return; // already have today's daily report
          }
        }
      }

      await generateDailyCognitiveReport(elderlyId, caretakerIdOverride: caretakerId);
    } catch (e) {
      print('Error checking daily report: $e');
    }
  }

  /// Generates a daily report and returns a status string for UI feedback.
  Future<String> generateDailyCognitiveReportWithStatus(
    String elderlyId, {
    String? caretakerIdOverride,
    bool force = false,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(elderlyId).get();
      if (!userDoc.exists) return 'user_not_found';
      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'Elderly User';
      final caretakerId = caretakerIdOverride ?? userData['caretakerId'];
      if (caretakerId == null) return 'no_caretaker';

      String? existingDailyDocId;
      if (!force) {
        final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final recentSnapshot = await _firestore
            .collection('users')
            .doc(caretakerId)
            .collection('cognitive_reports')
            .orderBy('date', descending: true)
            .limit(25)
            .get();

        for (final doc in recentSnapshot.docs) {
          final data = doc.data();
          if (data['elderlyId'] == elderlyId && data['type'] == 'daily') {
            final ts = data['date'] as Timestamp?;
            if (ts != null && !ts.toDate().isBefore(todayStart)) {
              existingDailyDocId = doc.id;
              break;
            }
          }
        }
      }

      final since = DateTime.now().subtract(const Duration(days: 1));
      final sessions = await _fetchRecentSessions(elderlyId, since);
      if (sessions.isEmpty) {
        print('No game sessions found for $userName in the last 24h.');
        return 'no_sessions';
      }

      final todayScores = _calculateTodayScores(sessions);
      final historicalSummary = await _dataService.getCognitiveHealthFuture(elderlyId);
      final gamesDataSummary = _prepareGamesSummary(sessions);

      final aiReport = await _getAIAnalysis(
        userName: userName,
        gamesSummary: gamesDataSummary,
        domainScores: historicalSummary,
        todayScores: todayScores,
        type: 'daily',
      );

      final sessionDetails = sessions.map((s) {
        return {
          'gameType': _normalizeGameType(s['gameType']),
          'score': s['score'] ?? 0,
          'accuracy': s['accuracy'],
          'average_reaction_time': s['average_reaction_time'],
          'efficiency': s['efficiency'],
          'metrics': s['metrics'] ?? {},
          'playedAt': _extractSessionTime(s['createdAt'] ?? s['timestamp'])?.toIso8601String(),
        };
      }).toList();
      final contributions = _calculateContributions(sessions);

      final report = CognitiveReport(
        id: '',
        elderlyId: elderlyId,
        elderlyName: userName,
        date: DateTime.now(),
        type: 'daily',
        domainScores: todayScores,
        overallScore: _calculateOverallAverage(todayScores),
        analysis: aiReport['analysis'] ?? '',
        suggestions: List<String>.from(aiReport['suggestions'] ?? []),
        metadata: {
          'sessionCount': sessions.length,
          'gamesPlayed': sessions.map((s) => s['gameType']).toSet().toList(),
          'historicalAverage': historicalSummary['overallScore'],
          'sessionDetails': sessionDetails,
          'domainContributions': contributions['domainContributions'],
          'overallContributions': contributions['overallContributions'],
          'activeDomainCount': contributions['activeDomainCount'],
        },
        createdAt: DateTime.now(),
      );

      final reportMap = report.toMap();
      reportMap['caretakerId'] = caretakerId;

      if (existingDailyDocId != null) {
        await _firestore
            .collection('users')
            .doc(caretakerId)
            .collection('cognitive_reports')
            .doc(existingDailyDocId)
            .set(reportMap, SetOptions(merge: true));
      } else {
        await _firestore
            .collection('users')
            .doc(caretakerId)
            .collection('cognitive_reports')
            .add(reportMap);
      }

      // Also write to a global collection for debugging/visibility
      // Avoid spamming global collection if updating existing daily
      if (existingDailyDocId == null) {
        await _firestore.collection('cognitive_reports').add(reportMap);
      }

      print('Daily cognitive report generated for $userName');
      return existingDailyDocId != null ? 'updated' : 'generated';
    } catch (e) {
      print('Error generating daily cognitive report: $e');
      return 'error';
    }
  }

  String _prepareGamesSummary(List<Map<String, dynamic>> sessions) {
    StringBuffer sb = StringBuffer();
    for (var s in sessions) {
      final gameType = s['gameType']?.toString() ?? 'Unknown';
      final domains = _gameDomainMapping[gameType]?.join(', ') ?? 'Unknown';
      sb.writeln("- Game: $gameType");
      sb.writeln("  Domains: $domains");
      sb.writeln("  Score: ${s['score']}");
      sb.writeln("  Metrics: ${jsonEncode(s['metrics'] ?? {})}");
      sb.writeln("  Accuracy: ${s['accuracy'] ?? 'N/A'}");
      sb.writeln("  Reaction Time: ${s['average_reaction_time'] ?? 'N/A'}");
      sb.writeln("  Efficiency: ${s['efficiency'] ?? 'N/A'}");
      sb.writeln("");
    }
    return sb.toString();
  }

  /// Generates a 10-minute cognitive report for a specific user
  Future<void> generateTenMinuteCognitiveReport(String elderlyId) async {
    await _generateIntervalCognitiveReport(
      elderlyId: elderlyId,
      interval: const Duration(minutes: 10),
      reportType: 'ten_minute',
    );
  }

  /// Generates an hourly consolidated report from the last 10-minute reports
  Future<void> generateHourlyConsolidatedReport(String elderlyId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(elderlyId).get();
      if (!userDoc.exists) return;
      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'Elderly User';
      final caretakerId = userData['caretakerId'];
      if (caretakerId == null) return;

      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final reportsSnapshot = await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .where('elderlyId', isEqualTo: elderlyId)
          .where('type', isEqualTo: 'ten_minute')
          .where('date', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();

      if (reportsSnapshot.docs.isEmpty) {
        print('No 10-minute reports in last hour for $userName. Skipping hourly.');
        return;
      }

      final intervalReports = reportsSnapshot.docs.map((doc) => doc.data()).toList();
      final intervalReportsForAi = _formatDailyReportsForAi(intervalReports);

      final aiReport = await _getAIAnalysis(
        userName: userName,
        dailyReports: intervalReportsForAi,
        type: 'hourly',
      );

      int avgScore = 0;
      if (intervalReports.isNotEmpty) {
        final num sum = intervalReports.fold<num>(
          0,
          (prev, element) => prev + ((element['overallScore'] as num?) ?? 0),
        );
        avgScore = (sum / intervalReports.length).round();
      }

      final report = CognitiveReport(
        id: '',
        elderlyId: elderlyId,
        elderlyName: userName,
        date: DateTime.now(),
        type: 'hourly',
        domainScores: {},
        overallScore: avgScore,
        analysis: aiReport['analysis'] ?? '',
        suggestions: List<String>.from(aiReport['suggestions'] ?? []),
        metadata: {
          'intervalReportsAnalyzed': intervalReports.length,
          'periodStart': oneHourAgo.toIso8601String(),
          'periodEnd': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
      );

      final reportMap = report.toMap();
      reportMap['caretakerId'] = caretakerId;

      await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .add(reportMap);

      // Also write to a global collection for debugging/visibility
      await _firestore.collection('cognitive_reports').add(reportMap);

      print('Hourly consolidated report generated for $userName');
    } catch (e) {
      print('Error generating hourly consolidated report: $e');
    }
  }

  Future<void> _generateIntervalCognitiveReport({
    required String elderlyId,
    required Duration interval,
    required String reportType,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(elderlyId).get();
      if (!userDoc.exists) return;
      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'Elderly User';
      final caretakerId = userData['caretakerId'];
      if (caretakerId == null) return;

      final since = DateTime.now().subtract(interval);
      final sessions = await _fetchRecentSessions(elderlyId, since);

      if (sessions.isEmpty) {
        print('No game sessions found for $userName in the last ${interval.inMinutes} minutes.');
        return;
      }

      final todayScores = _calculateTodayScores(sessions);
      final historicalSummary = await _dataService.getCognitiveHealthFuture(elderlyId);
      final gamesDataSummary = _prepareGamesSummary(sessions);

      final aiReport = await _getAIAnalysis(
        userName: userName,
        gamesSummary: gamesDataSummary,
        domainScores: historicalSummary,
        todayScores: todayScores,
        type: reportType,
      );

      final sessionDetails = sessions.map((s) {
        return {
          'gameType': _normalizeGameType(s['gameType']),
          'score': s['score'] ?? 0,
          'accuracy': s['accuracy'],
          'average_reaction_time': s['average_reaction_time'],
          'efficiency': s['efficiency'],
          'metrics': s['metrics'] ?? {},
          'playedAt': _extractSessionTime(s['createdAt'] ?? s['timestamp'])?.toIso8601String(),
        };
      }).toList();
      final contributions = _calculateContributions(sessions);

      final report = CognitiveReport(
        id: '',
        elderlyId: elderlyId,
        elderlyName: userName,
        date: DateTime.now(),
        type: reportType,
        domainScores: todayScores,
        overallScore: _calculateOverallAverage(todayScores),
        analysis: aiReport['analysis'] ?? '',
        suggestions: List<String>.from(aiReport['suggestions'] ?? []),
        metadata: {
          'sessionCount': sessions.length,
          'gamesPlayed': sessions.map((s) => s['gameType']).toSet().toList(),
          'historicalAverage': historicalSummary['overallScore'],
          'intervalMinutes': interval.inMinutes,
          'sessionDetails': sessionDetails,
          'domainContributions': contributions['domainContributions'],
          'overallContributions': contributions['overallContributions'],
          'activeDomainCount': contributions['activeDomainCount'],
        },
        createdAt: DateTime.now(),
      );

      final reportMap = report.toMap();
      reportMap['caretakerId'] = caretakerId;

      await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .add(reportMap);

      // Also write to a global collection for debugging/visibility
      await _firestore.collection('cognitive_reports').add(reportMap);

      print('Interval report ($reportType) generated for $userName');
    } catch (e) {
      print('Error generating interval report ($reportType): $e');
    }
  }

  Map<String, dynamic> _buildWeeklyTrendData(List<Map<String, dynamic>> dailyReports) {
    final List<Map<String, dynamic>> trends = [];

    // Sort by date ascending to show progression
    dailyReports.sort((a, b) {
      final aDate = (a['date'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = (b['date'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });

    for (final report in dailyReports) {
      final date = (report['date'] as Timestamp?)?.toDate();
      trends.add({
        'date': date?.toIso8601String() ?? 'unknown',
        'overallScore': (report['overallScore'] as num?)?.toInt() ?? 0,
      });
    }

    return {
      'overallScoreTrend': trends,
      'reportCount': dailyReports.length,
    };
  }

  List<Map<String, dynamic>> _formatDailyReportsForAi(List<Map<String, dynamic>> dailyReports) {
    final List<Map<String, dynamic>> sanitized = [];
    for (final report in dailyReports) {
      final date = (report['date'] as Timestamp?)?.toDate();
      sanitized.add({
        'date': date?.toIso8601String() ?? 'unknown',
        'type': report['type']?.toString() ?? 'daily',
        'overallScore': (report['overallScore'] as num?)?.toInt() ?? 0,
        'domainScores': Map<String, dynamic>.from(report['domainScores'] ?? {}),
        'analysis': report['analysis']?.toString() ?? '',
        'suggestions': List<String>.from(report['suggestions'] ?? []),
      });
    }
    return sanitized;
  }

  Map<String, int> _calculateTodayScores(List<Map<String, dynamic>> sessions) {
    Map<String, List<double>> domainValues = {
      'memory': [],
      'attention': [],
      'processingSpeed': [],
      'executiveFunction': [],
      'language': [],
    };

    for (var s in sessions) {
      final type = s['gameType'];
      final metrics = s['metrics'] as Map<String, dynamic>? ?? {};
      final cognitive = s['cognitive_contributions'] as Map<String, dynamic>? ?? {};

      if (type == 'Color Tap') {
        final accuracy = (s['accuracy'] as num?)?.toDouble() ?? 0.0;
        final rt = (s['average_reaction_time'] as num?)?.toDouble() ?? 2.0;
        domainValues['attention']?.add(accuracy * 100);
        domainValues['processingSpeed']?.add(((2.0 - rt).clamp(0.0, 2.0) * 50));
      } else if (type == 'Flip Card') {
        final efficiency = (s['efficiency'] as num?)?.toDouble() ?? 0.0;
        domainValues['memory']?.add(efficiency * 100);
      }

      // Add contributions from other games
      cognitive.forEach((key, value) {
        String domainKey = key;
        if (key == 'executive_function') domainKey = 'executiveFunction';
        if (domainValues.containsKey(domainKey)) {
          domainValues[domainKey]?.add((value as num).toDouble());
        }
      });
    }

    Map<String, int> result = {};
    domainValues.forEach((key, list) {
      if (list.isNotEmpty) {
        result[key] = (list.reduce((a, b) => a + b) / list.length).round();
      } else {
        result[key] = 0;
      }
    });

    return result;
  }

  int _calculateOverallAverage(Map<String, int> scores) {
    final active = scores.values.where((v) => v > 0).toList();
    if (active.isEmpty) return 0;
    return (active.reduce((a, b) => a + b) / active.length).round();
  }

  Future<Map<String, dynamic>> _getAIAnalysis({
    required String userName,
    String? gamesSummary,
    Map<String, dynamic>? domainScores,
    Map<String, int>? todayScores,
    List<Map<String, dynamic>>? dailyReports,
    Map<String, dynamic>? weeklyTrendData,
    required String type,
  }) async {
    final bool isTenMinute = type == 'ten_minute';
    final bool isDaily = type == 'daily' || isTenMinute;
    final bool isHourly = type == 'hourly';
    
    final systemPrompt = isDaily
      ? '''You are an Expert Neuropsychologist and Cognitive Health Specialist. Your job is to convert a single day's game sessions into a sharp, focused cognitive health report.
      
      CORE KNOWLEDGE:
      Game Domain Mapping:
      - Color Tap: Attention, Processing Speed
      - Flip Card: Memory
      - City Atlas: Executive Function, Memory
      - Event Ordering: Executive Function, Memory
      - Routine Recall: Memory, Executive Function
      - Monument Recall: Memory, Language

      METRICS TO ANALYZE:
      - Accuracy
      - Reaction Time
      - Efficiency

      OUTPUT JSON FORMAT:
      {
        "analysis": "2-3 paragraphs. First, explain which domains were targeted today. Second, provide a detailed analysis of cognitive sharpness vs. fatigue based on the metrics provided. Compare today's calculated scores with the user's historical performance.",
        "suggestions": ["2-3 reachable, specific suggestions for tomorrow (e.g., 'Try memory games in the morning when alert') to improve scores."]
      }'''
      : isHourly
      ? '''You are a Clinical Analyst. Your job is to consolidate multiple short interval reports into a single hourly snapshot.

      ANALYSIS TASK:
      1. Summarize the dominant domains trained in the last hour.
      2. Identify short-term variability (e.g., sharpness vs fatigue) from the interval reports.
      3. Provide 2-3 short, practical suggestions for the next hour.

      OUTPUT JSON FORMAT:
      {
        "analysis": "Concise hourly summary grounded in the interval reports.",
        "suggestions": ["Actionable next-hour suggestion 1", "Actionable suggestion 2"]
      }'''
      : '''You are a Lead Clinical Psychologist and Senior Neuro-consultant. Your job is to compare 7 days of daily reports to see the "Big Picture" and identify long-term trends.
      
      ANALYSIS TASK:
      1. Trend Conclusion: Identify if domain scores and overall cognitive health scores are dipping, stable, or improving.
      2. Caretaker Directive: Provide professional advice for the next week (e.g., "Increase social interaction," "Consider medical checkup if Attention score dips continue").
      3. Overall Strategy: Long-term advice to improve the elderly person's overall cognitive health scores.

      OUTPUT JSON FORMAT:
      {
        "analysis": "Comprehensive trend analysis. Clearly state the trend conclusion (dipping vs improving) and the reasoning behind it. Compare the average of the dailies to identify shifts.",
        "suggestions": ["Directive for caretaker", "Specific action plan for next week", "Overall strategy suggestion"]
      }''';

    final userPrompt = isDaily
      ? '''Generate a sharp Cognitive Analysis for $userName.
      
      Time Window: ${isTenMinute ? 'Last 10 minutes' : 'Today'}
      
      Today's Games Played & Raw Metrics:
      $gamesSummary
      
      Calculated Scores for Today:
      ${jsonEncode(todayScores)}
      
      Current Historical Domain Scores (for baseline context):
      ${jsonEncode(domainScores)}
      
      Task:
      - Identify the domains targeted today.
      - Analyze sharpness vs fatigue using accuracy/RT/efficiency metrics.
      - Contrast today's performance against the historical baseline.
      - Provide 2-3 actionable suggestions for domain score improvement.'''
      : isHourly
      ? '''Generate an Hourly Consolidated Report for $userName.

      Interval Reports (JSON):
      ${jsonEncode(dailyReports)}

      Task:
      - Summarize the last hour based on the 10-minute reports.
      - Highlight short-term changes and likely fatigue vs sharpness.
      - Provide 2-3 next-hour suggestions.'''
      : '''Generate a Weekly Trend Conclusion Report for $userName.
      
      Past 7 Days of Daily Reports (JSON):
      ${jsonEncode(dailyReports)}

      Overall Score Trend Data (JSON):
      ${jsonEncode(weeklyTrendData)}
      
      Task:
      - Compare daily reports to identify trends.
      - Conclude if scores are dipping or improving overall.
      - provide specific caretaker directives and long-term betterment strategies.''';

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
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.7,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return jsonDecode(data['choices'][0]['message']['content']);
      }
    } catch (e) {
      print('AI Analysis Error: $e');
    }
    
    return {
      'analysis': 'An error occurred while generating the analysis. Please review the raw metrics.',
      'suggestions': ['Encourage the user to stay active and hydrated.', 'Continue regular cognitive sessions.']
    };
  }
}
