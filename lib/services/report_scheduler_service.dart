import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/services/enhanced_memory_service.dart';
import 'package:elderly_care_app/services/cognitive_report_service.dart';

class ReportSchedulerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _weeklyReportTimer;
  Timer? _dailyReportTimer;
  Timer? _monthlyReportTimer;

  // Initialize the scheduler
  void initializeScheduler(String groqApiKey) {
    _runCatchUp(groqApiKey);
    _scheduleWeeklyReports(groqApiKey);
    _scheduleDailyReports(groqApiKey);
    _scheduleMonthlyReports(groqApiKey);
  }

  // ─── Daily Reports ──────────────────────────────────────────────

  void _scheduleDailyReports(String groqApiKey) {
    final now = DateTime.now();
    final nextRun = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    final timeUntilNextRun = nextRun.difference(now);

    print('📅 Next daily cognitive report scheduled for: $nextRun');

    Future.delayed(timeUntilNextRun, () {
      _runDailyReports(groqApiKey, skipIfExists: true);
      _dailyReportTimer = Timer.periodic(
        const Duration(days: 1),
        (_) => _runDailyReports(groqApiKey, skipIfExists: true),
      );
    });
  }

  // ─── Weekly Reports (every Sunday) ──────────────────────────────

  void _scheduleWeeklyReports(String groqApiKey) {
    final now = DateTime.now();
    final daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
    final nextSunday = DateTime(
      now.year,
      now.month,
      now.day + (daysUntilSunday == 0 ? 7 : daysUntilSunday),
      0, 0, 0,
    );

    final timeUntilNextRun = nextSunday.difference(now);
    print('📅 Next weekly report scheduled for: $nextSunday');

    Future.delayed(timeUntilNextRun, () {
      _runWeeklyReports(groqApiKey, skipIfExists: true);
      _weeklyReportTimer = Timer.periodic(
        const Duration(days: 7),
        (_) => _runWeeklyReports(groqApiKey, skipIfExists: true),
      );
    });
  }

  // ─── Monthly Reports (1st of each month) ────────────────────────

  void _scheduleMonthlyReports(String groqApiKey) {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1, 1, 0, 0);
    final timeUntilNextRun = nextMonth.difference(now);

    print('📅 Next monthly report scheduled for: $nextMonth');

    Future.delayed(timeUntilNextRun, () {
      _runMonthlyReports(groqApiKey);
      _monthlyReportTimer = Timer.periodic(
        const Duration(days: 28), // approximate; will self-correct
        (_) => _runMonthlyReports(groqApiKey),
      );
    });
  }

  // ─── Catch-up on app start ──────────────────────────────────────

  Future<void> _runCatchUp(String groqApiKey) async {
    await _runDailyReports(groqApiKey, skipIfExists: true);
    await _runHistoricalBackfill(groqApiKey);
  }

  // ─── Historical backfill ────────────────────────────────────────

  Future<void> _runHistoricalBackfill(String groqApiKey) async {
    const weeksToCheck = 8;
    print('🔄 Running historical weekly report backfill (last $weeksToCheck weeks)...');

    try {
      final memoryService = EnhancedMemoryService(groqApiKey: groqApiKey);
      final cognitiveService = CognitiveReportService(groqApiKey: groqApiKey);

      final usersSnapshot = await _firestore
          .collection('users')
          .where('caretakerId', isNull: false)
          .get();

      for (var userDoc in usersSnapshot.docs) {
        final caretakerId = userDoc.data()['caretakerId'] as String?;
        if (caretakerId == null) continue;

        for (int w = weeksToCheck; w >= 1; w--) {
          final now = DateTime.now();
          final currentWeekStart = _startOfWeekSunday(now);
          final weekStart = currentWeekStart.subtract(Duration(days: 7 * w));
          final weekEnd = weekStart.add(const Duration(days: 7));

          final exists = await _hasReportSince(
            caretakerId: caretakerId,
            elderlyId: userDoc.id,
            type: 'weekly',
            since: weekStart,
            before: weekEnd,
          );
          if (exists) continue;

          try {
            await memoryService.generateWeeklySentimentReportForPeriod(
              elderlyId: userDoc.id,
              periodStart: weekStart,
              periodEnd: weekEnd,
            );
            await cognitiveService.generateWeeklyCognitiveReport(
              userDoc.id,
              periodStart: weekStart,
              periodEnd: weekEnd,
            );
            print('✅ Backfilled report for ${userDoc.id} week of ${weekStart.toIso8601String()}');
          } catch (e) {
            print('❌ Backfill failed for ${userDoc.id} week $weekStart: $e');
          }
        }
      }
      print('✅ Historical backfill complete.');
    } catch (e) {
      print('❌ Error in historical backfill: $e');
    }
  }

  // ─── Run daily reports ──────────────────────────────────────────

  Future<void> _runDailyReports(
    String groqApiKey, {
    required bool skipIfExists,
  }) async {
    print('Running daily cognitive reports...');
    final cognitiveService = CognitiveReportService(groqApiKey: groqApiKey);
    final todayStart = _startOfDay(DateTime.now());

    final usersSnapshot = await _firestore
        .collection('users')
        .where('caretakerId', isNull: false)
        .get();

    for (var userDoc in usersSnapshot.docs) {
      try {
        final caretakerId = userDoc.data()['caretakerId'] as String?;
        if (caretakerId == null) continue;
        if (skipIfExists) {
          final exists = await _hasReportSince(
            caretakerId: caretakerId,
            elderlyId: userDoc.id,
            type: 'daily',
            since: todayStart,
          );
          if (exists) continue;
        }
        await cognitiveService.generateDailyCognitiveReport(userDoc.id);
      } catch (e) {
        print('❌ Daily report failed for ${userDoc.id}: $e');
      }
    }
  }

  // ─── Run weekly reports ─────────────────────────────────────────

  Future<void> _runWeeklyReports(
    String groqApiKey, {
    required bool skipIfExists,
  }) async {
    print('Running weekly reports...');

    try {
      final memoryService = EnhancedMemoryService(groqApiKey: groqApiKey);
      final cognitiveService = CognitiveReportService(groqApiKey: groqApiKey);
      final weekStart = _startOfWeekSunday(DateTime.now());

      final usersSnapshot = await _firestore
          .collection('users')
          .where('caretakerId', isNull: false)
          .get();

      for (var userDoc in usersSnapshot.docs) {
        try {
          final caretakerId = userDoc.data()['caretakerId'] as String?;
          if (caretakerId == null) continue;
          if (skipIfExists) {
            final exists = await _hasReportSince(
              caretakerId: caretakerId,
              elderlyId: userDoc.id,
              type: 'weekly',
              since: weekStart,
            );
            if (exists) continue;
          }
          await memoryService.generateWeeklySentimentReport(elderlyId: userDoc.id);
          await cognitiveService.generateWeeklyCognitiveReport(userDoc.id);
          print('✅ Weekly reports generated for user: ${userDoc.id}');
        } catch (e) {
          print('❌ Error generating weekly report for ${userDoc.id}: $e');
        }
      }
    } catch (e) {
      print('Error running weekly reports: $e');
    }
  }

  // ─── Run monthly reports ────────────────────────────────────────

  Future<void> _runMonthlyReports(String groqApiKey) async {
    print('Running monthly reports...');

    try {
      final cognitiveService = CognitiveReportService(groqApiKey: groqApiKey);
      final now = DateTime.now();
      // Generate for previous month
      final prevMonth = now.month == 1 ? 12 : now.month - 1;
      final prevYear = now.month == 1 ? now.year - 1 : now.year;

      final usersSnapshot = await _firestore
          .collection('users')
          .where('caretakerId', isNull: false)
          .get();

      for (var userDoc in usersSnapshot.docs) {
        try {
          await cognitiveService.generateMonthlyCognitiveReport(
            userDoc.id,
            month: prevMonth,
            year: prevYear,
          );
          print('✅ Monthly report generated for ${userDoc.id} ($prevMonth/$prevYear)');
        } catch (e) {
          print('❌ Monthly report failed for ${userDoc.id}: $e');
        }
      }
    } catch (e) {
      print('Error running monthly reports: $e');
    }
  }

  // ─── Manually trigger reports ───────────────────────────────────

  Future<void> triggerManualReport(String elderlyId, String groqApiKey) async {
    try {
      print('🔄 Manually triggering reports for: $elderlyId');
      final memoryService = EnhancedMemoryService(groqApiKey: groqApiKey);
      final cognitiveService = CognitiveReportService(groqApiKey: groqApiKey);

      await memoryService.generateWeeklySentimentReport(elderlyId: elderlyId);
      await cognitiveService.generateDailyCognitiveReport(elderlyId);
      await cognitiveService.generateWeeklyCognitiveReport(elderlyId);

      print('✅ Manual reports generated successfully');
    } catch (e) {
      print('❌ Error generating manual report: $e');
      rethrow;
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────

  Future<bool> _hasReportSince({
    required String caretakerId,
    required String elderlyId,
    required String type,
    required DateTime since,
    DateTime? before,
  }) async {
    var query = _firestore
        .collection('users')
        .doc(caretakerId)
        .collection('cognitive_reports')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since));

    if (before != null) {
      query = query.where('date', isLessThan: Timestamp.fromDate(before));
    }

    final snapshot = await query.limit(50).get();
    return snapshot.docs.any((doc) {
      final data = doc.data();
      return data['elderlyId'] == elderlyId && data['type'] == type;
    });
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _startOfWeekSunday(DateTime date) {
    final daysSinceSunday = date.weekday % 7;
    final sunday = date.subtract(Duration(days: daysSinceSunday));
    return DateTime(sunday.year, sunday.month, sunday.day);
  }

  void dispose() {
    _weeklyReportTimer?.cancel();
    _dailyReportTimer?.cancel();
    _monthlyReportTimer?.cancel();
    print('Report scheduler stopped');
  }
}
