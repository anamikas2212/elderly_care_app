import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

typedef NotificationTapHandler =
    Future<void> Function(NotificationNavigationRequest request);

class NotificationNavigationRequest {
  const NotificationNavigationRequest({
    required this.payload,
    required this.actionId,
  });

  final String payload;
  final String? actionId;

  bool get isMedicationReminder =>
      payload.contains('|') && !payload.startsWith('alert|');

  String? get userId {
    if (!isMedicationReminder) return null;
    final parts = payload.split('|');
    return parts.isNotEmpty ? parts[0] : null;
  }
}

class NotificationService {
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  NotificationTapHandler? _tapHandler;
  NotificationNavigationRequest? _launchRequest;
  bool _isInitialized = false;

  NotificationService._();

  Future<void> init() async {
    if (_isInitialized) return;
    tz.initializeTimeZones();
    try {
      final dynamic loc = await FlutterTimezone.getLocalTimezone();
      String locationName;
      if (loc is String) {
        locationName = loc;
      } else {
        // Handle TimezoneInfo object if returned
        locationName = loc.toString();
        if (locationName.contains('(')) {
          final start = locationName.indexOf('(') + 1;
          final end = locationName.indexOf(',');
          if (start > 0 && end > start) {
            locationName = locationName.substring(start, end).trim();
          }
        }
      }
      if (locationName == 'Asia/Calcutta') {
        locationName = 'Asia/Kolkata';
      }
      tz.setLocalLocation(tz.getLocation(locationName));
      debugPrint('NotificationService: Local timezone set to $locationName');
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      debugPrint(
        'NotificationService: Could not get local timezone, defaulting to Asia/Kolkata: $e',
      );
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: android);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationAction,
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackgroundHandler,
    );

    final androidImpl =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();

      // RENAMED TO V3 TO FORCE CHANNEL RESET
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'general_channel_v3',
          'General Notifications',
          importance: Importance.high,
          playSound: true,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'med_channel_v3',
          'Medication Reminders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    final launchDetails =
        await _notifications.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchResponse?.payload != null) {
      _launchRequest = NotificationNavigationRequest(
        payload: launchResponse!.payload!,
        actionId: launchResponse.actionId,
      );
    }
    _isInitialized = true;
  }

  void setTapHandler(NotificationTapHandler handler) {
    _tapHandler = handler;
  }

  Future<void> flushLaunchNotification() async {
    final request = _launchRequest;
    if (request == null || _tapHandler == null) return;
    _launchRequest = null;
    await _tapHandler!(request);
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
          'general_channel_v3',
          'General Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> showMedicationTest({
    required String userId,
    required String docId,
    required String name,
    String dose = '',
  }) async {
    final cleanDose = dose.trim();
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Time to take $name',
      cleanDose.isEmpty
          ? 'Tap to open My Pills.'
          : 'Dose: $cleanDose. Tap to open My Pills.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_channel_v3',
          'Medication Reminders',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: '$userId|$docId|0|0|$name',
    );
  }

  /// Cancels all scheduled and active notifications (used when resyncing meds).
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
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
    int snoozeCount = 0, // NEW: Track how many snoozes have happened
    DateTimeComponents? matchComponents,
    int? weekday, // 1=Mon .. 7=Sun
    tz.TZDateTime? scheduledDate,
  }) async {
    final tz.TZDateTime scheduled =
        scheduledDate ??
        (weekday != null
            ? _nextInstanceOfWeekday(weekday, hour, minute)
            : _nextInstance(hour, minute));
    final cleanDose = dose.trim();
    final notificationTitle = 'Time to take $name';
    final notificationBody =
        cleanDose.isEmpty
            ? 'Tap to open My Pills.'
            : 'Dose: $cleanDose. Tap to open My Pills.';

    await _notifications.zonedSchedule(
      id,
      notificationTitle,
      notificationBody,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'med_channel_v3',
          'Medication Reminders',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          fullScreenIntent:
              true, // Forces it to pop up even if screen is locked
          visibility: NotificationVisibility.public,
          ticker: 'Medication reminder',
          styleInformation: BigTextStyleInformation(notificationBody),
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
      payload:
          "$userId|$docId|$timeIndex|$snoozeCount|$name", // APPENDED SNOOZE COUNT & NAME
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: matchComponents,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    if (kDebugMode) {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint(
        'Medication notification scheduled: id=$id userId=$userId docId=$docId snoozes=$snoozeCount pending=${pending.length}',
      );
    }
  }

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> _onNotificationAction(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    if (_tapHandler != null) {
      await _tapHandler!(
        NotificationNavigationRequest(
          payload: payload,
          actionId: response.actionId,
        ),
      );
    }

    final parts = payload.split("|");
    if (parts.length < 2 || payload.startsWith('alert|')) return;
    final userId = parts[0];
    final docId = parts[1];
    final timeIndex = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    final currentSnoozes = parts.length > 3 ? int.tryParse(parts[3]) ?? 0 : 0;
    final medName = parts.length > 4 ? parts[4] : "Medication";

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
      if (currentSnoozes >= 2) {
        // If they already snoozed 5 times and haven't taken it:
        // Update Firestore to mark it explicitly not taken
        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await medRef.set({
          'missedDates': FieldValue.arrayUnion([
            dateStr,
            '${dateStr}_$timeIndex',
          ]),
        }, SetOptions(merge: true));

        // Notify them that it was auto-missed
        await showImmediate(
          title: "Medication Missed",
          body: "You snoozed $medName 2 times. It has been marked as missed.",
        );
        return; // Don't reschedule anymore
      }

      final now = DateTime.now().add(const Duration(minutes: 2));

      await scheduleMedication(
        id: ('${docId}_$timeIndex').hashCode.abs() % 100000,
        userId: userId,
        docId: docId,
        name: medName,
        dose: "", // We just need the name for the snooze string
        hour: now.hour,
        minute: now.minute,
        timeIndex: timeIndex,
        snoozeCount: currentSnoozes + 1, // INCREMENT SNOOZE
        scheduledDate: tz.TZDateTime.from(now, tz.local),
        matchComponents: null, // one-time snooze
      );
    }
  }
}

@pragma('vm:entry-point')
Future<void> notificationTapBackgroundHandler(
  NotificationResponse response,
) async {
  await NotificationService.instance._onNotificationAction(response);
}
