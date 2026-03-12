import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';

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

    final androidImpl =
        _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'general_channel',
          'General Notifications',
          importance: Importance.high,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'med_channel',
          'Medication Reminders',
          importance: Importance.max,
        ),
      );
    }
  }

  Future<void> showImmediate({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general_channel',
          'General Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
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
    int timeIndex = 0,
    DateTimeComponents? matchComponents,
    int? weekday, // 1=Mon .. 7=Sun
    tz.TZDateTime? scheduledDate,
  }) async {
    final tz.TZDateTime scheduled = scheduledDate ??
        (weekday != null
            ? _nextInstanceOfWeekday(weekday, hour, minute)
            : _nextInstance(hour, minute));

    await _notifications.zonedSchedule(
      id,
      "Medication Reminder",
      "Take $name ($dose)",
      scheduled,
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
      payload: "$userId|$docId|$timeIndex",
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: matchComponents,
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

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
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
    final timeIndex = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

    final medRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('medications')
        .doc(docId);

    if (response.actionId == "TAKEN") {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await medRef.update({
        'lastTaken': Timestamp.now(),
        'takenToday': true,
        'takenDates': FieldValue.arrayUnion([dateStr, '${dateStr}_$timeIndex']),
      });
    }

    if (response.actionId == "SNOOZE") {
      final now = DateTime.now().add(const Duration(minutes: 10));

      await scheduleMedication(
        id: ('${docId}_$timeIndex').hashCode.abs() % 100000,
        userId: userId,
        docId: docId,
        name: "Medication",
        dose: "",
        hour: now.hour,
        minute: now.minute,
        timeIndex: timeIndex,
        scheduledDate: tz.TZDateTime.from(now, tz.local),
        matchComponents: null, // one-time snooze
      );
    }
  }
}
