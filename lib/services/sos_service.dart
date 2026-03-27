//lib/services/sos_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class SOSService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Trigger an SOS alert for the elderly user
  Future<void> triggerSOS({
    required String elderlyUserId,
    required String elderlyUserName,
    Position? currentLocation,
    required bool isInsideSafeZone, // NEW: Pass safe zone status
  }) async {
    try {
      // Create SOS alert document
      final sosRef = await _firestore.collection('sos_alerts').add({
        'elderlyUserId': elderlyUserId,
        'elderlyUserName': elderlyUserName,
        'status': 'active', // active, acknowledged, resolved
        'triggeredAt': FieldValue.serverTimestamp(),
        'acknowledgedAt': null,
        'resolvedAt': null,
        'location': currentLocation != null
            ? {
                'latitude': currentLocation.latitude,
                'longitude': currentLocation.longitude,
                'accuracy': currentLocation.accuracy,
              }
            : null,
        'isActive': true,
        'isInsideSafeZone': isInsideSafeZone ?? false, // ✅ ADDED // Store location status
        'alertType': 'sos', // sos or false_alarm
      });

      // Create SOS log entry
      await _firestore
          .collection('sos_logs')
          .doc(elderlyUserId)
          .collection('logs')
          .add({
        'alertId': sosRef.id,
        'action': 'triggered',
        'triggeredAt': FieldValue.serverTimestamp(),
        'location': currentLocation != null
            ? {
                'latitude': currentLocation.latitude,
                'longitude': currentLocation.longitude,
              }
            : null,
        'isInsideSafeZone': isInsideSafeZone ?? false, // ✅ ADDED
      });

      // Update elderly user status
      await _firestore.collection('elderly_users').doc(elderlyUserId).set({
        'sosActive': true,
        'lastSOSAt': FieldValue.serverTimestamp(),
        'isInsideSafeZone': isInsideSafeZone ?? false, // ✅ ADDED
      }, SetOptions(merge: true));

      print('✅ SOS Alert triggered: ${sosRef.id}');
    } catch (e) {
      print('❌ Error triggering SOS: $e');
      rethrow;
    }
  }

  /// Trigger false alarm
  Future<void> triggerFalseAlarm({
    required String elderlyUserId,
    required String elderlyUserName,
  }) async {
    try {
      // Create false alarm log entry
      await _firestore
          .collection('sos_logs')
          .doc(elderlyUserId)
          .collection('logs')
          .add({
        'alertId': null,
        'action': 'false_alarm',
        'triggeredAt': FieldValue.serverTimestamp(),
        'message': 'False alarm - cancelled by user',
      });

      print('False alarm logged');
    } catch (e) {
      print('Error logging false alarm: $e');
      rethrow;
    }
  }

  /// Acknowledge SOS alert (caretaker action)
  Future<void> acknowledgeSOS(String alertId, String caretakerId) async {
    try {
      print('🔍 Acknowledging SOS with caretaker ID: "$caretakerId"'); // ✅ DEBUG

      await 
      _firestore.collection('sos_alerts').doc(alertId).update({
        'status': 'acknowledged',
        'acknowledgedAt': FieldValue.serverTimestamp(),
        'acknowledgedBy': caretakerId,
      });

      // Log the acknowledgment
      final alertDoc =
          await _firestore.collection('sos_alerts').doc(alertId).get();
      final elderlyUserId = alertDoc.data()?['elderlyUserId'];

      if (elderlyUserId != null) {
        await _firestore
            .collection('sos_logs')
            .doc(elderlyUserId)
            .collection('logs')
            .add({
          'alertId': alertId,
          'action': 'acknowledged',
          'acknowledgedAt': FieldValue.serverTimestamp(),
          'acknowledgedBy': caretakerId,
        });
      }

      print('✅ SOS Alert acknowledged: $alertId by $caretakerId');
    } catch (e) {
      print('❌ Error acknowledging SOS: $e');
      rethrow;
    }
  }

  /// Resolve SOS alert (caretaker action)
  Future<void> resolveSOS(String alertId, String caretakerId) async {
    try {
      print('🔍 Resolving SOS with caretaker ID: "$caretakerId"'); // ✅ DEBUG

      await _firestore.collection('sos_alerts').doc(alertId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': caretakerId,
        'isActive': false,
      });

      // Log the resolution
      final alertDoc =
          await _firestore.collection('sos_alerts').doc(alertId).get();
      final elderlyUserId = alertDoc.data()?['elderlyUserId'];

      if (elderlyUserId != null) {
        await _firestore
            .collection('sos_logs')
            .doc(elderlyUserId)
            .collection('logs')
            .add({
          'alertId': alertId,
          'action': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': caretakerId,
        });

        // Update elderly user status
        await _firestore.collection('elderly_users').doc(elderlyUserId).update({
          'sosActive': false,
        });
      }

      print('✅ SOS Alert resolved: $alertId');
    } catch (e) {
      print('❌ Error resolving SOS: $e');
      rethrow;
    }
  }

  /// Get active SOS alerts for an elderly user
  Stream<QuerySnapshot> getActiveSOSAlerts(String elderlyUserId) {
    return _firestore
        .collection('sos_alerts')
        .where('elderlyUserId', isEqualTo: elderlyUserId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      // Create a new snapshot-like object or just sort the docs in the stream map
      // But we need to return QuerySnapshot. Actually, we can just return the stream
      // and sort it where it's consumed, or use a map to transform it.
      // However, most consumers expect a QuerySnapshot.
      // Firestore doesn't provide a way to create a QuerySnapshot easily in memory.
      // So we will just remove the orderBy and let the UI sort it if possible,
      // OR we just keep it simple and hope the UI handles multiple alerts (rare).
      return snapshot; 
    });
  }

  /// Get all SOS logs for an elderly user
  Stream<QuerySnapshot> getSOSLogs(String elderlyUserId) {
    return _firestore
        .collection('sos_logs')
        .doc(elderlyUserId)
        .collection('logs')
        .orderBy('triggeredAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Check if elderly user has active SOS
  Future<bool> hasActiveSOS(String elderlyUserId) async {
    try {
      final snapshot = await _firestore
          .collection('sos_alerts')
          .where('elderlyUserId', isEqualTo: elderlyUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking active SOS: $e');
      return false;
    }
  }

  /// Get current location status (inside/outside safe zone)
  Future<Map<String, dynamic>> getLocationStatus(String elderlyUserId) async {
    try {
      // Get safe zone data
      final safeZoneDoc =
          await _firestore.collection('safe_zones').doc(elderlyUserId).get();

      if (!safeZoneDoc.exists) {
        return {'status': 'unknown', 'isHome': false, 'distance': 0.0,
        'position': null, // ✅ ADDED: Return null position
        };
      }

      final safeZoneData = safeZoneDoc.data()!;
      final homeLatitude = safeZoneData['homeLatitude'] as double?;
      final homeLongitude = safeZoneData['homeLongitude'] as double?;
      final radius = (safeZoneData['radius'] as num?)?.toDouble() ?? 1000.0;

      if (homeLatitude == null || homeLongitude == null) {
        return {'status': 'unknown', 'isHome': false, 'distance': 0.0, 'position': null,};
      }

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Calculate distance
      final distance = Geolocator.distanceBetween(
        homeLatitude,
        homeLongitude,
        position.latitude,
        position.longitude,
      );

      final isHome = distance <= radius;

      return {
        'status': isHome ? 'home' : 'away',
        'isHome': isHome,
        'distance': distance,
        'radius': radius,
        'position': position,
      };
    } catch (e) {
      print('Error getting location status: $e');
      return {'status': 'unknown', 'isHome': false, 'distance': 0.0, 'position': null,};
    }
  }

  /// Get safe zone status from Firestore (for caretaker dashboard)
  Stream<bool> getSafeZoneStatus(String elderlyUserId) {
    return _firestore
        .collection('elderly_users')
        .doc(elderlyUserId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data();
      return data?['isInsideSafeZone'] as bool? ?? false;
    });
  }  
}