import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

/// Keeps elderly device medication reminders in sync with caretaker changes.
class MedicationNotificationService {
  MedicationNotificationService._();
  static final MedicationNotificationService instance =
      MedicationNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _medsSub;

  Future<void> start(String userId) async {
    await stop();
    await NotificationService.instance.init();
    await NotificationService.instance.cancelAll();
    await _scheduleAll(userId);
    _medsSub = _firestore
        .collection('users')
        .doc(userId)
        .collection('medications')
        .snapshots()
        .listen((snapshot) async {
          await NotificationService.instance.cancelAll();
          await _scheduleFromDocs(userId, snapshot.docs);
        }, onError: (Object error) {
          debugPrint('MedicationNotificationService stream error: $error');
        });
  }

  Future<void> stop() async {
    await _medsSub?.cancel();
    _medsSub = null;
  }

  Future<void> _scheduleAll(String userId) async {
    final snap =
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('medications')
            .get();
    await _scheduleFromDocs(userId, snap.docs);
  }

  Future<void> _scheduleFromDocs(
    String userId,
    List<QueryDocumentSnapshot> docs,
  ) async {
    for (final doc in docs) {
      await _scheduleNotification(
        userId,
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
    }
  }

  Future<void> _scheduleNotification(
    String userId,
    String docId,
    Map<String, dynamic> med,
  ) async {
    final daysStr = _safeStringOrList(med['days']).toLowerCase();
    final times = med['times'] as List<dynamic>?;
    if (times != null && times.isNotEmpty) {
      for (var i = 0; i < times.length; i++) {
        await _scheduleSingle(
          userId,
          docId,
          med,
          times[i].toString(),
          i,
          daysStr,
        );
      }
    } else {
      await _scheduleSingle(
        userId,
        docId,
        med,
        _safeString(med['time']),
        0,
        daysStr,
      );
    }
  }

  Future<void> _scheduleSingle(
    String userId,
    String docId,
    Map<String, dynamic> med,
    String timeStr,
    int timeIndex,
    String daysStr,
  ) async {
    final t = _parse12hTime(timeStr);
    if (t == null) return;

    final name = _safeString(med['name']);
    final dose = _safeString(med['dose']);

    if (daysStr.isEmpty || daysStr.contains('daily')) {
      final notifId = '${docId}_${timeIndex}_daily'.hashCode.abs() % 100000;
      await NotificationService.instance.scheduleMedication(
        id: notifId,
        userId: userId,
        docId: docId,
        name: name,
        dose: dose,
        hour: t.hour,
        minute: t.minute,
        timeIndex: timeIndex,
        matchComponents: DateTimeComponents.time,
      );
      return;
    }

    final weekdays = _parseDaysToWeekdays(daysStr);
    for (final wd in weekdays) {
      final notifId = '${docId}_${timeIndex}_$wd'.hashCode.abs() % 100000;
      await NotificationService.instance.scheduleMedication(
        id: notifId,
        userId: userId,
        docId: docId,
        name: name,
        dose: dose,
        hour: t.hour,
        minute: t.minute,
        timeIndex: timeIndex,
        weekday: wd,
        matchComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  TimeOfDay? _parse12hTime(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.isEmpty) return null;
      final hm = parts[0].split(':');
      if (hm.length < 2) return null;
      int hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);
      if (parts.length > 1) {
        if (parts[1].toUpperCase() == 'PM' && hour != 12) hour += 12;
        if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
      }
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  List<int> _parseDaysToWeekdays(String daysStr) {
    final days = daysStr
        .split(',')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty);
    final map = {
      'mon': DateTime.monday,
      'tue': DateTime.tuesday,
      'wed': DateTime.wednesday,
      'thu': DateTime.thursday,
      'fri': DateTime.friday,
      'sat': DateTime.saturday,
      'sun': DateTime.sunday,
    };
    return days
        .map((d) => map[d.substring(0, 3).toLowerCase()])
        .whereType<int>()
        .toList();
  }

  String _safeString(dynamic v) => v?.toString() ?? '';

  String _safeStringOrList(dynamic v) {
    if (v == null) return '';
    if (v is List) return v.join(', ');
    return v.toString();
  }
}
