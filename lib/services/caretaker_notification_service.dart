import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class CaretakerNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Initialize notification service for caretaker
  Future<void> initializeForCaretaker(String caretakerId) async {
    try {
      if (kIsWeb) return;
      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Notification permission granted');

        // Get FCM token
        String? token = await _messaging.getToken();
        if (token != null) {
          // Save token to caretaker's profile
          await _firestore.collection('users').doc(caretakerId).set({
            'fcmToken': token,
            'notificationsEnabled': true,
          }, SetOptions(merge: true));

          print('✅ FCM Token saved: $token');
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          _firestore.collection('users').doc(caretakerId).update({
            'fcmToken': newToken,
          });
        });
      } else {
        print('❌ Notification permission denied');
      }
    } catch (e) {
      print('Error initializing notifications: $e');
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

  // Mark buddy notification as read
  Future<void> markBuddyNotificationAsRead(String elderlyId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(elderlyId)
        .collection('buddy_notifications')
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

  // Mark buddy notification as resolved
  Future<void> markBuddyNotificationAsResolved(String elderlyId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(elderlyId)
        .collection('buddy_notifications')
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

  // Get weekly reports for a specific elderly user
  Stream<QuerySnapshot> getWeeklyReportsStream(
    String caretakerId,
    String elderlyId,
  ) {
    return _firestore
        .collection('users')
        .doc(elderlyId)
        .collection('buddy_weekly_reports')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();
  }

  // Get notifications for a specific elderly user (for the enhanced buddy screen)
  Stream<QuerySnapshot> getNotificationsForElderlyStream(String elderlyId) {
    return _firestore
        .collection('users')
        .doc(elderlyId)
        .collection('buddy_notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // Mark buddy weekly report as read
  Future<void> markBuddyReportAsRead(String elderlyId, String reportId) async {
    await _firestore
        .collection('users')
        .doc(elderlyId)
        .collection('buddy_weekly_reports')
        .doc(reportId)
        .update({'isRead': true});
  }

  // Delete buddy weekly report
  Future<void> deleteBuddyReport(String elderlyId, String reportId) async {
    await _firestore
        .collection('users')
        .doc(elderlyId)
        .collection('buddy_weekly_reports')
        .doc(reportId)
        .delete();
  }

  // Delete notification
  Future<void> deleteNotification(
    String caretakerId,
    String notificationId,
  ) async {
    await _firestore
        .collection('users')
        .doc(caretakerId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteBuddyNotification(String elderlyId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(elderlyId)
        .collection('buddy_notifications')
        .doc(notificationId)
        .delete();
  }

  // Clear all read notifications
  Future<void> clearReadNotifications(String caretakerId) async {
    final snapshot =
        await _firestore
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
    final snapshot =
        await _firestore
            .collection('users')
            .doc(caretakerId)
            .collection('notifications')
            .get();

    int urgent = 0;
    int moderate = 0;
    int info = 0;

    for (var doc in snapshot.docs) {
      final severity = doc.data()['severity'];
      if (severity == 'urgent')
        urgent++;
      else if (severity == 'moderate')
        moderate++;
      else
        info++;
    }

    return {
      'urgent': urgent,
      'moderate': moderate,
      'info': info,
      'total': snapshot.docs.length,
    };
  }
}
