/*import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ReportSchedulerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Initialize notification service for caretaker
  Future<void> initializeForCaretaker(String caretakerId) async {
    try {
      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        //print('âœ… Notification permission granted');

        // Get FCM token
        String? token = await _messaging.getToken();
        if (token != null) {
          // Save token to caretaker's profile
          await _firestore.collection('users').doc(caretakerId).set({
            'fcmToken': token,
            'notificationsEnabled': true,
          }, SetOptions(merge: true));

          //print('âœ… FCM Token saved: $token');
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          _firestore.collection('users').doc(caretakerId).update({
            'fcmToken': newToken,
          });
        });
      } else {
        //print('âŒ Notification permission denied');
      }
    } catch (e) {
      //print('Error initializing notifications: $e');
    }
  }

  // Listen to caretaker's notifications in real-time
  Stream<QuerySnapshot> getNotificationsStream(String caretakerId) {
    return _firestore
        .collection('users')
        .doc(caretakerId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // Get unread notification count
  Stream<int> getUnreadNotificationCount(String caretakerId) {
    return _firestore
        .collection('users')
        .doc(caretakerId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  Future<void> markAsRead(String caretakerId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(caretakerId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Mark notification as resolved
  Future<void> markAsResolved(String caretakerId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(caretakerId)
        .collection('notifications')
        .doc(notificationId)
        .update({
      'isResolved': true,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get buddy activity log
  Stream<QuerySnapshot> getBuddyActivityStream(String elderlyId) {
    return _firestore
        .collection('users')
        .doc(elderlyId)
        .collection('buddy_activities')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots();
  }

  // Get weekly reports
  Stream<QuerySnapshot> getWeeklyReportsStream(String caretakerId) {
    return _firestore
        .collection('users')
        .doc(caretakerId)
        .collection('weekly_reports')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();
  }

  // Mark weekly report as read
  Future<void> markReportAsRead(String caretakerId, String reportId) async {
    await _firestore
        .collection('users')
        .doc(caretakerId)
        .collection('weekly_reports')
        .doc(reportId)
        .update({'isRead': true});
  }

  // Delete notification
  Future<void> deleteNotification(String caretakerId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(caretakerId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  // Clear all read notifications
  Future<void> clearReadNotifications(String caretakerId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(caretakerId)
        .collection('notifications')
        .where('isRead', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Get notification statistics
  Future<Map<String, int>> getNotificationStats(String caretakerId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(caretakerId)
        .collection('notifications')
        .get();

    int urgent = 0;
    int moderate = 0;
    int info = 0;

    for (var doc in snapshot.docs) {
      final severity = doc.data()['severity'];
      if (severity == 'urgent') urgent++;
      else if (severity == 'moderate') moderate++;
      else info++;
    }

    return {
      'urgent': urgent,
      'moderate': moderate,
      'info': info,
      'total': snapshot.docs.length,
    };
  }
}*/

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/services/enhanced_memory_service.dart';
import 'package:elderly_care_app/services/cognitive_report_service.dart';

class ReportSchedulerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _weeklyReportTimer;
  Timer? _dailyReportTimer;

  // Initialize the scheduler
  void initializeScheduler(String groqApiKey) {
    // Catch up immediately on app start (last 24h daily + Sunday weekly)
    _runCatchUp(groqApiKey);

    // Run weekly reports every Sunday at midnight
    _scheduleWeeklyReports(groqApiKey);
    // Run daily reports every night at midnight
    _scheduleDailyReports(groqApiKey);
  }

  // Schedule daily cognitive reports
  void _scheduleDailyReports(String groqApiKey) {
    final now = DateTime.now();
    final nextRun = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    final timeUntilNextRun = nextRun.difference(now);

    print('ðŸ“… Next daily cognitive report scheduled for: $nextRun');

    Future.delayed(timeUntilNextRun, () {
      _runDailyReports(groqApiKey, skipIfExists: true);
      _dailyReportTimer = Timer.periodic(
        const Duration(days: 1),
        (_) => _runDailyReports(groqApiKey, skipIfExists: true),
      );
    });
  }

  // Schedule weekly reports
  void _scheduleWeeklyReports(String groqApiKey) {
    // Calculate time until next Sunday midnight
    final now = DateTime.now();
    final daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
    final nextSunday = DateTime(
      now.year,
      now.month,
      now.day + (daysUntilSunday == 0 ? 7 : daysUntilSunday),
      0, // midnight
      0,
      0,
    );

    final timeUntilNextRun = nextSunday.difference(now);

    print('ðŸ“… Next weekly report scheduled for: $nextSunday');

    // Schedule first run
    Future.delayed(timeUntilNextRun, () {
      _runWeeklyReports(groqApiKey, skipIfExists: true);

      // Schedule recurring runs every 7 days
      _weeklyReportTimer = Timer.periodic(
        const Duration(days: 7),
        (_) => _runWeeklyReports(groqApiKey, skipIfExists: true),
      );
    });
  }

  Future<void> _runCatchUp(String groqApiKey) async {
    await _runDailyReports(groqApiKey, skipIfExists: true);
    if (DateTime.now().weekday == DateTime.sunday) {
      await _runWeeklyReports(groqApiKey, skipIfExists: true);
    }
  }

  // Run daily reports for all elderly users
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
        print('âŒ Daily report failed for ${userDoc.id}: $e');
      }
    }
  }

  // Run weekly reports for all elderly users
  Future<void> _runWeeklyReports(
    String groqApiKey, {
    required bool skipIfExists,
  }) async {
    print('Running weekly reports...');

    try {
      final memoryService = EnhancedMemoryService(groqApiKey: groqApiKey);
      final cognitiveService = CognitiveReportService(groqApiKey: groqApiKey);
      final weekStart = _startOfWeekSunday(DateTime.now());

      // Get all elderly users (users with a caretakerId field)
      final usersSnapshot =
          await _firestore
              .collection('users')
              .where('caretakerId', isNull: false)
              .get();

      int successCount = 0;
      int errorCount = 0;

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
          // Sentiment report
          await memoryService.generateWeeklySentimentReport(
            elderlyId: userDoc.id,
          );
          
          // Cognitive report
          await cognitiveService.generateWeeklyCognitiveReport(userDoc.id);
          
          successCount++;
          print('âœ… Reports generated for user: ${userDoc.id}');
        } catch (e) {
          errorCount++;
          print('âŒ Error generating report for ${userDoc.id}: $e');
        }
      }

      print('Weekly reports complete: $successCount succeeded, $errorCount failed');
    } catch (e) {
      print('Error running weekly reports: $e');
    }
  }

  // Manually trigger reports for a specific user (for testing)
  Future<void> triggerManualReport(String elderlyId, String groqApiKey) async {
    try {
      print('ðŸ”„ Manually triggering reports for: $elderlyId');
      final memoryService = EnhancedMemoryService(groqApiKey: groqApiKey);
      final cognitiveService = CognitiveReportService(groqApiKey: groqApiKey);
      
      await memoryService.generateWeeklySentimentReport(elderlyId: elderlyId);
      await cognitiveService.generateDailyCognitiveReport(elderlyId);
      await cognitiveService.generateWeeklyCognitiveReport(elderlyId);
      
      print('âœ… manual reports generated successfully');
    } catch (e) {
      print('âŒ Error generating manual report: $e');
      rethrow;
    }
  }

  Future<bool> _hasReportSince({
    required String caretakerId,
    required String elderlyId,
    required String type,
    required DateTime since,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(elderlyId)
        .collection('cognitive_reports')
        .where('type', isEqualTo: type)
        .get();

    if (snapshot.docs.isEmpty) return false;
    
    DateTime? latestDate;
    for (var doc in snapshot.docs) {
      final ts = doc.data()['date'] as Timestamp?;
      if (ts != null) {
        if (latestDate == null || ts.toDate().isAfter(latestDate)) {
           latestDate = ts.toDate();
        }
      }
    }
    if (latestDate == null) return false;
    return !latestDate.isBefore(since);
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _startOfWeekSunday(DateTime date) {
    final daysSinceSunday = date.weekday % 7; // Sunday=0, Monday=1, ...
    final sunday = date.subtract(Duration(days: daysSinceSunday));
    return DateTime(sunday.year, sunday.month, sunday.day);
  }

  // Cancel scheduled reports (call this when disposing)
  void dispose() {
    _weeklyReportTimer?.cancel();
    _dailyReportTimer?.cancel();
    print('Report scheduler stopped');
  }
}

