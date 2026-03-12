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

  // ─── Daily Report ───────────────────────────────────────────────

  Future<void> generateDailyCognitiveReport(
    String elderlyId, {
    String? caretakerIdOverride,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(elderlyId).get();
      if (!userDoc.exists) return;
      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'Elderly User';
      final caretakerId = caretakerIdOverride ?? userData['caretakerId'];
      if (caretakerId == null) return;

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final sessions = await _fetchRecentSessions(elderlyId, yesterday);

      if (sessions.isEmpty) {
        print('No game sessions found for $userName in the last 24h. Skipping daily report.');
        return;
      }

      final todayScores = _calculateTodayScores(sessions);
      final historicalSummary = await _dataService.getCognitiveHealthFuture(elderlyId);
      final gamesDataSummary = _prepareGamesSummary(sessions);

      // Calculate baseline comparison
      final baselineScores = _extractBaselineScores(historicalSummary);
      final domainChanges = _calculateDomainChanges(todayScores, baselineScores);
      final overallAvg = _calculateOverallAverage(todayScores);
      final historicalAvg = (historicalSummary['overallScore'] as num?)?.toInt() ?? 0;
      final overallChangePercent = historicalAvg > 0
          ? ((overallAvg - historicalAvg) / historicalAvg * 100)
          : 0.0;

      final aiReport = await _getAIAnalysis(
        userName: userName,
        gamesSummary: gamesDataSummary,
        domainScores: historicalSummary,
        todayScores: todayScores,
        type: 'daily',
      );

      final sessionDetails = _buildSessionDetails(sessions);
      final contributions = _calculateContributions(sessions);

      final report = CognitiveReport(
        id: '',
        elderlyId: elderlyId,
        elderlyName: userName,
        date: DateTime.now(),
        type: 'daily',
        domainScores: todayScores,
        overallScore: overallAvg,
        analysis: aiReport['analysis'] ?? '',
        suggestions: List<String>.from(aiReport['suggestions'] ?? []),
        metadata: {
          'sessionCount': sessions.length,
          'gamesPlayed': sessions.map((s) => s['gameType']).toSet().toList(),
          'historicalAverage': historicalAvg,
          'sessionDetails': sessionDetails,
          'domainContributions': contributions['domainContributions'],
          'overallContributions': contributions['overallContributions'],
          'activeDomainCount': contributions['activeDomainCount'],
          'baselineScores': baselineScores,
          'domainChanges': domainChanges,
          'overallChangePercent': double.parse(overallChangePercent.toStringAsFixed(1)),
          'keyInsights': List<Map<String, dynamic>>.from(aiReport['key_insights'] ?? []),
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

  // ─── Daily Report with Status (used by Generate button) ─────────

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

      // Always look for existing daily report to update
      String? existingDailyDocId;
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

      final since = DateTime.now().subtract(const Duration(days: 1));
      final sessions = await _fetchRecentSessions(elderlyId, since);
      if (sessions.isEmpty) {
        return 'no_sessions';
      }

      final todayScores = _calculateTodayScores(sessions);
      final historicalSummary = await _dataService.getCognitiveHealthFuture(elderlyId);
      final gamesDataSummary = _prepareGamesSummary(sessions);

      // Baseline comparison
      final baselineScores = _extractBaselineScores(historicalSummary);
      final domainChanges = _calculateDomainChanges(todayScores, baselineScores);
      final overallAvg = _calculateOverallAverage(todayScores);
      final historicalAvg = (historicalSummary['overallScore'] as num?)?.toInt() ?? 0;
      final overallChangePercent = historicalAvg > 0
          ? ((overallAvg - historicalAvg) / historicalAvg * 100)
          : 0.0;

      final aiReport = await _getAIAnalysis(
        userName: userName,
        gamesSummary: gamesDataSummary,
        domainScores: historicalSummary,
        todayScores: todayScores,
        type: 'daily',
      );

      final sessionDetails = _buildSessionDetails(sessions);
      final contributions = _calculateContributions(sessions);

      final report = CognitiveReport(
        id: '',
        elderlyId: elderlyId,
        elderlyName: userName,
        date: DateTime.now(),
        type: 'daily',
        domainScores: todayScores,
        overallScore: overallAvg,
        analysis: aiReport['analysis'] ?? '',
        suggestions: List<String>.from(aiReport['suggestions'] ?? []),
        metadata: {
          'sessionCount': sessions.length,
          'gamesPlayed': sessions.map((s) => s['gameType']).toSet().toList(),
          'historicalAverage': historicalAvg,
          'sessionDetails': sessionDetails,
          'domainContributions': contributions['domainContributions'],
          'overallContributions': contributions['overallContributions'],
          'activeDomainCount': contributions['activeDomainCount'],
          'baselineScores': baselineScores,
          'domainChanges': domainChanges,
          'overallChangePercent': double.parse(overallChangePercent.toStringAsFixed(1)),
          'keyInsights': List<Map<String, dynamic>>.from(aiReport['key_insights'] ?? []),
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

      if (existingDailyDocId == null) {
        await _firestore.collection('cognitive_reports').add(reportMap);
      }

      // If today is Sunday, also generate a weekly combined report
      if (DateTime.now().weekday == DateTime.sunday) {
        await generateWeeklyCognitiveReport(elderlyId);
      }

      return existingDailyDocId != null ? 'updated' : 'generated';
    } catch (e) {
      print('Error generating daily cognitive report: $e');
      return 'error';
    }
  }

  // ─── Weekly Combined Report ─────────────────────────────────────

  Future<void> generateWeeklyCognitiveReport(String elderlyId, {DateTime? periodStart, DateTime? periodEnd}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(elderlyId).get();
      final caretakerId = userDoc.data()?['caretakerId'];
      final userName = userDoc.data()?['name'] ?? 'Elderly User';
      if (caretakerId == null) return;

      // Calculate the start and end of the current week (Monday to Sunday)
      final effectiveEnd = periodEnd ?? DateTime.now();
      final effectiveStart = periodStart ?? _getStartOfWeek(effectiveEnd);
      // We query up to the end of the week, or current time, whichever is needed
      final queryEnd = periodEnd ?? _getEndOfWeek(effectiveEnd).add(const Duration(minutes: 1));

      final allReportsSnapshot = await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveStart))
          .where('date', isLessThan: Timestamp.fromDate(queryEnd))
          .get();

      final dailyReports = allReportsSnapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['elderlyId'] == elderlyId && data['type'] == 'daily';
          })
          .map((doc) => doc.data())
          .toList();
          
      String? existingWeeklyDocId;
      final existingWeeklySnapshot = await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .where('elderlyId', isEqualTo: elderlyId)
          .where('type', isEqualTo: 'weekly')
          .orderBy('date', descending: true)
          .limit(10)
          .get();
          
      for (final doc in existingWeeklySnapshot.docs) {
          final data = doc.data();
          final ts = data['date'] as Timestamp?;
          if (ts != null && ts.toDate().year == effectiveEnd.year && ts.toDate().month == effectiveEnd.month && (ts.toDate().day - effectiveEnd.day).abs() <= 3) {
              existingWeeklyDocId = doc.id;
              break;
          }
      }

      if (dailyReports.isEmpty) {
        // Generate a placeholder report
        final placeholder = CognitiveReport(
          id: '',
          elderlyId: elderlyId,
          elderlyName: userName,
          date: _getEndOfWeek(effectiveEnd),
          type: 'weekly',
          domainScores: {},
          overallScore: 0,
          analysis: 'Not enough data available to generate a comprehensive weekly report. Please ensure daily cognitive games are played consistently over the week.',
          suggestions: ['Encourage playing at least one game session daily to unlock weekly insights.'],
          metadata: {
            'dailyReportsAnalyzed': 0,
            'periodStart': effectiveStart.toIso8601String(),
            'periodEnd': effectiveEnd.toIso8601String(),
            'keyInsights': [
              {
                'icon_type': 'neutral',
                'text': 'No daily reports found for this week. Consistent play is required to generate accurate trend analysis.'
              }
            ],
            'isPlaceholder': true,
          },
          createdAt: DateTime.now(),
        );

        final reportMap = placeholder.toMap();
        reportMap['caretakerId'] = caretakerId;
        
        if (existingWeeklyDocId != null) {
            await _firestore
                .collection('users')
                .doc(caretakerId)
                .collection('cognitive_reports')
                .doc(existingWeeklyDocId)
                .set(reportMap, SetOptions(merge: true));
        } else {
            await _firestore
                .collection('users')
                .doc(caretakerId)
                .collection('cognitive_reports')
                .add(reportMap);
        }

        print('✅ Placeholder weekly report updated/generated for $userName');
        return;
      }

      final dailyReportsForAi = _formatDailyReportsForAi(dailyReports);
      final weeklyTrendData = _buildWeeklyTrendData(dailyReports);

      // Calculate average domain scores across all dailies
      final avgDomainScores = _calculateAverageDomainScores(dailyReports);

      final aiReport = await _getAIAnalysis(
        userName: userName,
        dailyReports: dailyReportsForAi,
        weeklyTrendData: weeklyTrendData,
        type: 'weekly',
      );

      int avgScore = 0;
      if (dailyReports.isNotEmpty) {
        final num sum = dailyReports.fold<num>(
          0, (prev, element) => prev + ((element['overallScore'] as num?) ?? 0));
        avgScore = (sum / dailyReports.length).round();
      }

      // Collect included daily dates
      final includedDates = dailyReports.map((r) {
        final ts = r['date'] as Timestamp?;
        return ts?.toDate().toIso8601String() ?? '';
      }).where((d) => d.isNotEmpty).toList();

      final report = CognitiveReport(
        id: '',
        elderlyId: elderlyId,
        elderlyName: userName,
        date: _getEndOfWeek(effectiveEnd),
        type: 'weekly',
        domainScores: avgDomainScores,
        overallScore: avgScore,
        analysis: aiReport['analysis'] ?? '',
        suggestions: List<String>.from(aiReport['suggestions'] ?? []),
        metadata: {
          'dailyReportsAnalyzed': dailyReports.length,
          'periodStart': effectiveStart.toIso8601String(),
          'periodEnd': effectiveEnd.toIso8601String(),
          'includedDailyDates': includedDates,
          'keyInsights': List<Map<String, dynamic>>.from(aiReport['key_insights'] ?? []),
          if (periodStart != null) 'isBackfilled': true,
        },
        createdAt: effectiveEnd,
      );

      final reportMap = report.toMap();
      reportMap['caretakerId'] = caretakerId;

      if (existingWeeklyDocId != null) {
          await _firestore
              .collection('users')
              .doc(caretakerId)
              .collection('cognitive_reports')
              .doc(existingWeeklyDocId)
              .set(reportMap, SetOptions(merge: true));
      } else {
          await _firestore
              .collection('users')
              .doc(caretakerId)
              .collection('cognitive_reports')
              .add(reportMap);
      }

      print('✅ Weekly cognitive trend report updated/generated for $userName ($effectiveStart)');
    } catch (e) {
      print('❌ Error generating weekly cognitive report: $e');
    }
  }

  // ─── Monthly Report ─────────────────────────────────────────────

  Future<void> generateMonthlyCognitiveReport(String elderlyId, {int? month, int? year}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(elderlyId).get();
      final caretakerId = userDoc.data()?['caretakerId'];
      final userName = userDoc.data()?['name'] ?? 'Elderly User';
      if (caretakerId == null) return;

      final now = DateTime.now();
      final targetMonth = month ?? now.month;
      final targetYear = year ?? now.year;
      final monthStart = DateTime(targetYear, targetMonth, 1);
      final monthEnd = DateTime(targetMonth == 12 ? targetYear + 1 : targetYear, targetMonth == 12 ? 1 : targetMonth + 1, 1);

      final allReportsSnapshot = await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('date', isLessThan: Timestamp.fromDate(monthEnd))
          .get();

      final dailyReports = allReportsSnapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['elderlyId'] == elderlyId && data['type'] == 'daily';
          })
          .map((doc) => doc.data())
          .toList();

      if (dailyReports.isEmpty) {
        final placeholder = CognitiveReport(
          id: '',
          elderlyId: elderlyId,
          elderlyName: userName,
          date: monthEnd.subtract(const Duration(days: 1)),
          type: 'monthly',
          domainScores: {},
          overallScore: 0,
          analysis: 'Not enough data available to generate a comprehensive monthly report. Please ensure daily cognitive games are played consistently throughout the month.',
          suggestions: ['Set up a daily routine for cognitive exercises.'],
          metadata: {
            'dailyReportsAnalyzed': 0,
            'periodStart': monthStart.toIso8601String(),
            'periodEnd': monthEnd.toIso8601String(),
            'month': targetMonth,
            'year': targetYear,
            'keyInsights': [
              {
                'icon_type': 'neutral',
                'text': 'No daily reports found for this month. Consistent play is required to generate accurate trend analysis.'
              }
            ],
            'isPlaceholder': true,
          },
          createdAt: DateTime.now(),
        );

        final reportMap = placeholder.toMap();
        reportMap['caretakerId'] = caretakerId;
        await _firestore
            .collection('users')
            .doc(caretakerId)
            .collection('cognitive_reports')
            .add(reportMap);

        print('✅ Placeholder monthly report generated for $userName');
        return;
      }

      final dailyReportsForAi = _formatDailyReportsForAi(dailyReports);
      final avgDomainScores = _calculateAverageDomainScores(dailyReports);

      final aiReport = await _getAIAnalysis(
        userName: userName,
        dailyReports: dailyReportsForAi,
        type: 'monthly',
      );

      int avgScore = 0;
      final num sum = dailyReports.fold<num>(
        0, (prev, element) => prev + ((element['overallScore'] as num?) ?? 0));
      avgScore = (sum / dailyReports.length).round();

      final includedDates = dailyReports.map((r) {
        final ts = r['date'] as Timestamp?;
        return ts?.toDate().toIso8601String() ?? '';
      }).where((d) => d.isNotEmpty).toList();

      final report = CognitiveReport(
        id: '',
        elderlyId: elderlyId,
        elderlyName: userName,
        date: monthEnd.subtract(const Duration(days: 1)),
        type: 'monthly',
        domainScores: avgDomainScores,
        overallScore: avgScore,
        analysis: aiReport['analysis'] ?? '',
        suggestions: List<String>.from(aiReport['suggestions'] ?? []),
        metadata: {
          'dailyReportsAnalyzed': dailyReports.length,
          'periodStart': monthStart.toIso8601String(),
          'periodEnd': monthEnd.toIso8601String(),
          'month': targetMonth,
          'year': targetYear,
          'includedDailyDates': includedDates,
          'keyInsights': List<Map<String, dynamic>>.from(aiReport['key_insights'] ?? []),
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

      print('✅ Monthly report generated for $userName ($targetMonth/$targetYear)');
    } catch (e) {
      print('❌ Error generating monthly report: $e');
    }
  }

  // ─── Yearly Report ──────────────────────────────────────────────

  Future<void> generateYearlyCognitiveReport(String elderlyId, {int? year}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(elderlyId).get();
      final caretakerId = userDoc.data()?['caretakerId'];
      final userName = userDoc.data()?['name'] ?? 'Elderly User';
      if (caretakerId == null) return;

      final targetYear = year ?? DateTime.now().year;
      final yearStart = DateTime(targetYear, 1, 1);
      final yearEnd = DateTime(targetYear + 1, 1, 1);

      final allReportsSnapshot = await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart))
          .where('date', isLessThan: Timestamp.fromDate(yearEnd))
          .get();

      final dailyReports = allReportsSnapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['elderlyId'] == elderlyId && data['type'] == 'daily';
          })
          .map((doc) => doc.data())
          .toList();

      if (dailyReports.isEmpty) {
        final placeholder = CognitiveReport(
          id: '',
          elderlyId: elderlyId,
          elderlyName: userName,
          date: DateTime(targetYear, 12, 31),
          type: 'yearly',
          domainScores: {},
          overallScore: 0,
          analysis: 'Not enough data available to generate a comprehensive yearly report. Please ensure daily cognitive games are played consistently.',
          suggestions: ['Set a goal for regular cognitive engagement next year.'],
          metadata: {
            'dailyReportsAnalyzed': 0,
            'year': targetYear,
            'periodStart': yearStart.toIso8601String(),
            'periodEnd': yearEnd.toIso8601String(),
            'keyInsights': [
              {
                'icon_type': 'neutral',
                'text': 'No daily reports found for this year. Consistent play is required to generate accurate trend analysis.'
              }
            ],
            'isPlaceholder': true,
          },
          createdAt: DateTime.now(),
        );

        final reportMap = placeholder.toMap();
        reportMap['caretakerId'] = caretakerId;
        await _firestore
            .collection('users')
            .doc(caretakerId)
            .collection('cognitive_reports')
            .add(reportMap);

        print('✅ Placeholder yearly report generated for $userName');
        return;
      }

      final dailyReportsForAi = _formatDailyReportsForAi(dailyReports);
      final avgDomainScores = _calculateAverageDomainScores(dailyReports);

      final aiReport = await _getAIAnalysis(
        userName: userName,
        dailyReports: dailyReportsForAi,
        type: 'yearly',
      );

      int avgScore = 0;
      final num sum = dailyReports.fold<num>(
        0, (prev, element) => prev + ((element['overallScore'] as num?) ?? 0));
      avgScore = (sum / dailyReports.length).round();

      final report = CognitiveReport(
        id: '',
        elderlyId: elderlyId,
        elderlyName: userName,
        date: DateTime(targetYear, 12, 31),
        type: 'yearly',
        domainScores: avgDomainScores,
        overallScore: avgScore,
        analysis: aiReport['analysis'] ?? '',
        suggestions: List<String>.from(aiReport['suggestions'] ?? []),
        metadata: {
          'dailyReportsAnalyzed': dailyReports.length,
          'year': targetYear,
          'periodStart': yearStart.toIso8601String(),
          'periodEnd': yearEnd.toIso8601String(),
          'keyInsights': List<Map<String, dynamic>>.from(aiReport['key_insights'] ?? []),
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

      print('✅ Yearly report generated for $userName ($targetYear)');
    } catch (e) {
      print('❌ Error generating yearly report: $e');
    }
  }

  // ─── Helpers: Time Periods ─────────────────────────────────────────

  DateTime _getStartOfWeek(DateTime date) {
    int daysToSubtract = date.weekday - DateTime.monday;
    if (daysToSubtract < 0) {
      daysToSubtract = 6;
    }
    final monday = date.subtract(Duration(days: daysToSubtract));
    return DateTime(monday.year, monday.month, monday.day);
  }

  DateTime _getEndOfWeek(DateTime date) {
    final startOfWeek = _getStartOfWeek(date);
    return startOfWeek.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
  }

  // ─── Helpers: Baseline Comparison ───────────────────────────────

  Map<String, int> _extractBaselineScores(Map<String, dynamic> historicalSummary) {
    final Map<String, int> baseline = {};
    final domains = ['memory', 'attention', 'processingSpeed', 'executiveFunction', 'language'];
    for (final d in domains) {
      final val = historicalSummary[d];
      if (val is num) {
        baseline[d] = val.toInt();
      } else {
        baseline[d] = (historicalSummary['overallScore'] as num?)?.toInt() ?? 0;
      }
    }
    return baseline;
  }

  Map<String, double> _calculateDomainChanges(Map<String, int> todayScores, Map<String, int> baselineScores) {
    final Map<String, double> changes = {};
    for (final entry in todayScores.entries) {
      final baseline = baselineScores[entry.key] ?? 0;
      if (baseline > 0) {
        changes[entry.key] = double.parse(
          ((entry.value - baseline) / baseline * 100).toStringAsFixed(1),
        );
      } else {
        changes[entry.key] = 0.0;
      }
    }
    return changes;
  }

  Map<String, int> _calculateAverageDomainScores(List<Map<String, dynamic>> reports) {
    final domains = ['memory', 'attention', 'processingSpeed', 'executiveFunction', 'language'];
    final Map<String, List<int>> domainValues = {};
    for (final d in domains) {
      domainValues[d] = [];
    }

    for (final report in reports) {
      final scores = report['domainScores'] as Map<String, dynamic>? ?? {};
      for (final d in domains) {
        final val = (scores[d] as num?)?.toInt() ?? 0;
        if (val > 0) domainValues[d]!.add(val);
      }
    }

    final Map<String, int> result = {};
    for (final d in domains) {
      final list = domainValues[d]!;
      if (list.isNotEmpty) {
        result[d] = (list.reduce((a, b) => a + b) / list.length).round();
      } else {
        result[d] = 0;
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _buildSessionDetails(List<Map<String, dynamic>> sessions) {
    return sessions.map((s) {
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
  }

  // ─── Missing-report check helper ───────────────────────────────

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
            return;
          }
        }
      }

      await generateDailyCognitiveReport(elderlyId, caretakerIdOverride: caretakerId);
    } catch (e) {
      print('Error checking daily report: $e');
    }
  }

  // ─── Session Fetching ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchRecentSessions(String userId, DateTime since) async {
    final List<Map<String, dynamic>> all = [];
    final collections = ['colorTapGameSessions', 'flipCardGameSessions', 'game_sessions'];

    for (var col in collections) {
      if (col == 'game_sessions') {
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
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  String _normalizeGameType(dynamic raw) {
    final String gameType = raw?.toString() ?? 'Unknown';
    switch (gameType) {
      case 'city_atlas': return 'City Atlas';
      case 'event_ordering': return 'Event Ordering';
      case 'daily_routine_recall': return 'Routine Recall';
      case 'monument_recall': return 'Monument Recall';
      case 'Color Tap (Reaction)': return 'Color Tap';
      case 'Flip Card Match': return 'Flip Card';
      default: return gameType;
    }
  }

  // ─── Contributions ─────────────────────────────────────────────

  Map<String, dynamic> _calculateContributions(List<Map<String, dynamic>> sessions) {
    final Map<String, Map<String, double>> gameToDomain = {};
    final Map<String, double> domainTotals = {};

    for (final s in sessions) {
      final game = _normalizeGameType(s['gameType']);
      gameToDomain.putIfAbsent(game, () => {});

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

      final cognitive = s['cognitive_contributions'] as Map<String, dynamic>? ?? {};
      cognitive.forEach((key, value) {
        String domainKey = key;
        if (key == 'executive_function') domainKey = 'executiveFunction';
        if (domainKey == 'processing_speed') domainKey = 'processingSpeed';
        _addContribution(gameToDomain[game]!, domainKey, (value as num).toDouble());
      });
    }

    for (final entry in gameToDomain.entries) {
      for (final d in entry.value.entries) {
        domainTotals[d.key] = (domainTotals[d.key] ?? 0) + d.value;
      }
    }

    final activeDomains = domainTotals.entries.where((e) => e.value > 0).map((e) => e.key).toList();
    final int activeDomainCount = activeDomains.length;

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

  // ─── Games Summary ─────────────────────────────────────────────

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

  // ─── Score calculations ────────────────────────────────────────

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

  // ─── Weekly trend helpers ──────────────────────────────────────

  Map<String, dynamic> _buildWeeklyTrendData(List<Map<String, dynamic>> dailyReports) {
    final List<Map<String, dynamic>> trends = [];

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

  // ─── 10-minute & hourly reports ────────────────────────────────

  Future<void> generateTenMinuteCognitiveReport(String elderlyId) async {
    await _generateIntervalCognitiveReport(
      elderlyId: elderlyId,
      interval: const Duration(minutes: 10),
      reportType: 'ten_minute',
    );
  }

  Future<void> generateHourlyConsolidatedReport(String elderlyId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(elderlyId).get();
      if (!userDoc.exists) return;
      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'Elderly User';
      final caretakerId = userData['caretakerId'];
      if (caretakerId == null) return;

      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final allReportsSnap = await _firestore
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .where('date', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();

      final intervalReports = allReportsSnap.docs
          .where((doc) {
            final d = doc.data();
            return d['elderlyId'] == elderlyId && d['type'] == 'ten_minute';
          })
          .map((doc) => doc.data())
          .toList();

      if (intervalReports.isEmpty) return;

      final intervalReportsForAi = _formatDailyReportsForAi(intervalReports);

      final aiReport = await _getAIAnalysis(
        userName: userName,
        dailyReports: intervalReportsForAi,
        type: 'hourly',
      );

      int avgScore = 0;
      if (intervalReports.isNotEmpty) {
        final num sum = intervalReports.fold<num>(
          0, (prev, element) => prev + ((element['overallScore'] as num?) ?? 0));
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
      if (sessions.isEmpty) return;

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

      final sessionDetails = _buildSessionDetails(sessions);
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
    } catch (e) {
      print('Error generating interval report ($reportType): $e');
    }
  }

  // ─── AI Analysis (Groq) ────────────────────────────────────────

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
    final bool isMonthly = type == 'monthly';
    final bool isYearly = type == 'yearly';

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
        "suggestions": ["2-3 reachable, specific suggestions for tomorrow (e.g., 'Try memory games in the morning when alert') to improve scores."],
        "key_insights": [
          {"icon_type": "decline", "text": "When comparing today's performance to the historical baseline, it is clear that there are significant declines in Memory and Language, while Executive Function remains relatively stable. Gentle encouragement and rest can help."},
          {"icon_type": "neutral", "text": "Overall, today's performance suggests the elderly may be experiencing cognitive fatigue, particularly in memory and language domains. Encourage a short walk or light stretching to reset focus."},
          {"icon_type": "decline", "text": "For instance, the high accuracy in Color Tap suggests sharp attention, but the average reaction time is slightly slower than expected, indicating some level of fatigue. Gentle encouragement and rest can help. Suggest a balanced meal and good hydration."},
          {"icon_type": "tip", "text": "In contrast, the efficiency in Flip Card Match is lower than expected, suggesting difficulties with memory retrieval."},
          {"icon_type": "neutral", "text": "The cognitive domains targeted today include Memory, Executive Function, and Language."},
          {"icon_type": "neutral", "text": "The metrics from the various games indicate a mix of sharpness and fatigue. Try a calm music break and a few minutes of relaxation."},
          {"icon_type": "tip", "text": "Attention and Processing Speed were not adequately assessed today due to limited relevant game data."}
        ]
      }
      
      IMPORTANT: 
      - Each key_insight should have "icon_type" of "decline" (for declining trends), "improve" (for improving trends), "neutral" (for neutral observations), or "tip" (for tips/advice).
      - Generate 5-7 key insights that analyze the performance in detail.'''
      : isHourly
      ? '''You are a Clinical Analyst. Consolidate interval reports into an hourly snapshot.
      OUTPUT JSON FORMAT:
      {
        "analysis": "Concise hourly summary.",
        "suggestions": ["Actionable next-hour suggestion 1", "Actionable suggestion 2"],
        "key_insights": [{"icon_type": "neutral", "text": "..."}]
      }'''
      : isMonthly
      ? '''You are a Senior Clinical Psychologist. Analyze a full month of daily cognitive reports to provide a comprehensive monthly summary.
      
      ANALYSIS TASK:
      1. Identify monthly trends across all cognitive domains.
      2. Highlight the best and worst performing domains.
      3. Note any significant patterns (e.g., weekend vs weekday performance).
      4. Provide strategic caretaker directives for the next month.
      
      OUTPUT JSON FORMAT:
      {
        "analysis": "Comprehensive monthly analysis with trends and patterns.",
        "suggestions": ["Strategic caretaker directive 1", "Action plan for next month"],
        "key_insights": [{"icon_type": "decline|improve|neutral|tip", "text": "..."}]
      }'''
      : isYearly
      ? '''You are a Lead Neuropsychologist. Analyze a full year of daily cognitive reports to provide a comprehensive yearly summary.
      
      ANALYSIS TASK:
      1. Long-term cognitive health trajectory.
      2. Seasonal patterns and significant shifts.
      3. Overall progress assessment.
      4. Long-term care strategy recommendations.
      
      OUTPUT JSON FORMAT:
      {
        "analysis": "Comprehensive yearly analysis.",
        "suggestions": ["Long-term strategic directive 1", "Yearly care plan suggestion"],
        "key_insights": [{"icon_type": "decline|improve|neutral|tip", "text": "..."}]
      }'''
      : '''You are a Lead Clinical Psychologist and Senior Neuro-consultant. Compare daily reports to see the "Big Picture" and identify trends.
      
      ANALYSIS TASK:
      1. Trend Conclusion: Identify if domain scores and overall cognitive health scores are dipping, stable, or improving.
      2. Caretaker Directive: Provide professional advice for the next week.
      3. Overall Strategy: Long-term advice to improve overall cognitive health scores.

      OUTPUT JSON FORMAT:
      {
        "analysis": "Comprehensive trend analysis. Clearly state the trend conclusion (dipping vs improving) and the reasoning behind it.",
        "suggestions": ["Directive for caretaker", "Specific action plan for next week", "Overall strategy suggestion"],
        "key_insights": [{"icon_type": "decline|improve|neutral|tip", "text": "..."}]
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
      - Provide 5-7 key insights with icon_type classification.
      - Provide 2-3 actionable suggestions for domain score improvement.'''
      : isHourly
      ? '''Generate an Hourly Consolidated Report for $userName.
      Interval Reports (JSON):
      ${jsonEncode(dailyReports)}
      Task:
      - Summarize the last hour.
      - Highlight short-term changes.
      - Provide 2-3 next-hour suggestions.'''
      : isMonthly
      ? '''Generate a Monthly Summary Report for $userName.
      
      Daily Reports from this month (JSON):
      ${jsonEncode(dailyReports)}
      
      Task:
      - Analyze the full month of daily reports.
      - Identify monthly trends across all domains.
      - Provide strategic caretaker directives and care plan.
      - Include 5-7 key insights.'''
      : isYearly
      ? '''Generate a Yearly Summary Report for $userName.
      
      Daily Reports from this year (JSON):
      ${jsonEncode(dailyReports)}
      
      Task:
      - Analyze the full year of reports.
      - Identify long-term cognitive health trajectory.
      - Provide strategic yearly care plan.
      - Include 5-7 key insights.'''
      : '''Generate a Weekly Trend Conclusion Report for $userName.
      
      Past Days of Daily Reports (JSON):
      ${jsonEncode(dailyReports)}

      Overall Score Trend Data (JSON):
      ${jsonEncode(weeklyTrendData)}
      
      Task:
      - Compare daily reports to identify trends.
      - Conclude if scores are dipping or improving overall.
      - Provide specific caretaker directives.
      - Include 5-7 key insights.''';

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
        final parsed = jsonDecode(data['choices'][0]['message']['content']);
        // Ensure key_insights exists
        if (parsed['key_insights'] == null) {
          parsed['key_insights'] = [];
        }
        return parsed;
      }
    } catch (e) {
      print('AI Analysis Error: $e');
    }

    return {
      'analysis': 'An error occurred while generating the analysis. Please review the raw metrics.',
      'suggestions': ['Encourage the user to stay active and hydrated.', 'Continue regular cognitive sessions.'],
      'key_insights': [],
    };
  }
}
