import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  NotificationService._();

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: android);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationAction,
    );
  }

  Future<void> scheduleMedication({
    required int id,
    required String userId,
    required String docId,
    required String name,
    required String dose,
    required int hour,
    required int minute,
  }) async {
    await _notifications.zonedSchedule(
      id,
      "Medication Reminder",
      "Take $name ($dose)",
      _nextInstance(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'med_channel',
          'Medication Reminders',
          importance: Importance.max,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(
              'TAKEN',
              'Taken',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'SNOOZE',
              'Snooze',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
      payload: "$userId|$docId",
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);

    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  Future<void> _onNotificationAction(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    final parts = payload.split("|");
    final userId = parts[0];
    final docId = parts[1];

    final medRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('medications')
        .doc(docId);

    if (response.actionId == "TAKEN") {
      await medRef.update({
        'lastTaken': Timestamp.now(),
        'takenToday': true
      });
    }

    if (response.actionId == "SNOOZE") {
      final now = DateTime.now().add(const Duration(minutes: 10));

      await scheduleMedication(
        id: docId.hashCode,
        userId: userId,
        docId: docId,
        name: "Medication",
        dose: "",
        hour: now.hour,
        minute: now.minute,
      );
    }
  }
}