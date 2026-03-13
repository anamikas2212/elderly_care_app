import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class SafetyAlertListenerService {
  StreamSubscription<QuerySnapshot>? _sosSub;
  StreamSubscription<QuerySnapshot>? _safeZoneSub;

  Future<void> start(String elderlyId) async {
    await stop();

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final sosKey = 'last_sos_alert_ts_$elderlyId';
    final safeKey = 'last_safezone_alert_ts_$elderlyId';

    final lastSosMillis = prefs.getInt(sosKey) ?? now.millisecondsSinceEpoch;
    final lastSafeMillis = prefs.getInt(safeKey) ?? now.millisecondsSinceEpoch;

    final lastSosTime = DateTime.fromMillisecondsSinceEpoch(lastSosMillis);
    final lastSafeTime = DateTime.fromMillisecondsSinceEpoch(lastSafeMillis);

    _sosSub = FirebaseFirestore.instance
        .collection('sos_alerts')
        .where('elderlyUserId', isEqualTo: elderlyId)
        .snapshots()
        .listen((snapshot) async {
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final tsA = a.data()['triggeredAt'] as Timestamp?;
        final tsB = b.data()['triggeredAt'] as Timestamp?;
        if (tsA == null) return 1;
        if (tsB == null) return -1;
        return tsB.compareTo(tsA);
      });
      DateTime newest = lastSosTime;
      for (final doc in docs) {
        final data = doc.data();
        final ts = data['triggeredAt'] as Timestamp?;
        if (ts == null) continue;
        final dt = ts.toDate();
        if (dt.isAfter(lastSosTime)) {
          final name = data['elderlyUserName'] ?? elderlyId;
          NotificationService.instance.showImmediate(
            title: 'Emergency Alert',
            body: 'SOS from $name. Immediate action required.',
          );
          if (dt.isAfter(newest)) newest = dt;
        }
      }
      await prefs.setInt(sosKey, newest.millisecondsSinceEpoch);
    });

    _safeZoneSub = FirebaseFirestore.instance
        .collection('safezone_logs')
        .doc(elderlyId)
        .collection('logs')
        .snapshots()
        .listen((snapshot) async {
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final tsA = a.data()['triggeredAt'] as Timestamp?;
        final tsB = b.data()['triggeredAt'] as Timestamp?;
        if (tsA == null) return 1;
        if (tsB == null) return -1;
        return tsB.compareTo(tsA);
      });
      DateTime newest = lastSafeTime;
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final action = data['action'] as String? ?? '';
        if (action != 'outside_safezone') continue;
        final ts = data['triggeredAt'] as Timestamp?;
        if (ts == null) continue;
        final dt = ts.toDate();
        if (dt.isAfter(lastSafeTime)) {
          NotificationService.instance.showImmediate(
            title: 'Safe Zone Alert',
            body: 'Elderly has stepped out of the safe zone.',
          );
          if (dt.isAfter(newest)) newest = dt;
        }
      }
      await prefs.setInt(safeKey, newest.millisecondsSinceEpoch);
    });
  }

  Future<void> stop() async {
    await _sosSub?.cancel();
    await _safeZoneSub?.cancel();
    _sosSub = null;
    _safeZoneSub = null;
  }
}
