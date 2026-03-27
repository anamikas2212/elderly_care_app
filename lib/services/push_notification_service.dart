import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'notification_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initForUser({required String userId}) async {
    if (kIsWeb) return;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _firestore.collection('users').doc(userId).set({
            'fcmToken': token,
            'notificationsEnabled': true,
          }, SetOptions(merge: true));
        }

        _messaging.onTokenRefresh.listen((newToken) {
          _firestore.collection('users').doc(userId).set({
            'fcmToken': newToken,
            'notificationsEnabled': true,
          }, SetOptions(merge: true));
        });
      }
    } catch (_) {}
  }

  void initializeForegroundHandlers() {
    if (kIsWeb) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (_shouldSuppressForegroundAlert(message)) {
        return;
      }

      final title =
          message.notification?.title ?? message.data['title'] ?? 'Alert';
      final body =
          message.notification?.body ?? message.data['message'] ?? '';

      if (title.isNotEmpty || body.isNotEmpty) {
        NotificationService.instance.showImmediate(
          title: title,
          body: body,
          payload: message.data['payload'],
        );
      }
    });
  }

  bool _shouldSuppressForegroundAlert(RemoteMessage message) {
    final type = (message.data['type'] ?? '').toString().toLowerCase();
    final title =
        (message.notification?.title ?? message.data['title'] ?? '')
            .toString()
            .toLowerCase();
    final body =
        (message.notification?.body ?? message.data['message'] ?? '')
            .toString()
            .toLowerCase();
    final combined = '$type $title $body';

    return type == 'alert' &&
        (combined.contains('medication') ||
            combined.contains('pill') ||
            combined.contains('overdue') ||
            combined.contains('missed dose'));
  }
}
