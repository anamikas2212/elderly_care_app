import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PairingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generates a unique 6-digit pairing code for the elderly user.
  /// Saves it to `pairing_codes/{code}` with a 24-hour expiry.
  Future<String> generatePairingCode(String elderlyUid) async {
    // Check if a valid code already exists for this elderly user
    final existing = await _getExistingCode(elderlyUid);
    if (existing != null) return existing;

    // Generate a unique 6-digit code (with collision check)
    String code;
    int attempts = 0;
    do {
      code = _generateRandomCode();
      final doc = await _firestore.collection('pairing_codes').doc(code).get();
      if (!doc.exists) break;
      attempts++;
    } while (attempts < 10);

    if (attempts >= 10) {
      throw Exception('Failed to generate unique pairing code. Try again.');
    }

    // Save code with 30-day expiry so the elderly's code stays stable
    // across multiple sessions on the same device.
    final now = DateTime.now();
    await _firestore.collection('pairing_codes').doc(code).set({
      'elderly_uid': elderlyUid,
      'created_at': Timestamp.fromDate(now),
      'expires_at': Timestamp.fromDate(now.add(const Duration(days: 30))),
    });

    // Save code locally so the elderly user can always see it
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('care_code', code);

    return code;
  }

  /// Retrieves the existing pairing code for an elderly user.
  Future<String?> _getExistingCode(String elderlyUid) async {
    try {
      final snapshot = await _firestore
          .collection('pairing_codes')
          .where('elderly_uid', isEqualTo: elderlyUid)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final expiresAt = (doc['expires_at'] as Timestamp).toDate();

      // If expired, delete it and return null
      if (DateTime.now().isAfter(expiresAt)) {
        await doc.reference.delete();
        return null;
      }

      return doc.id; // The document ID is the 6-digit code
    } catch (_) {
      return null;
    }
  }

  /// Gets the care code from local storage (for display on elderly dashboard).
  Future<String?> getCareCodeLocally() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('care_code');
  }

  /// Regenerates a new pairing code (e.g., if the old one expired).
  Future<String> regenerateCode(String elderlyUid) async {
    // Delete any existing codes for this user
    final existing = await _firestore
        .collection('pairing_codes')
        .where('elderly_uid', isEqualTo: elderlyUid)
        .get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }

    // Clear local cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('care_code');

    // Generate new code
    return generatePairingCode(elderlyUid);
  }

  /// Redeems a 6-digit code: links the elderly user to the caretaker.
  /// Also updates the elderly user's profile with detailed information provided by the caretaker.
  /// Returns the elderly user's UID if successful.
  Future<String> redeemPairingCode({
    required String code,
    required String caretakerUid,
    required Map<String, dynamic> elderlyDetails,
  }) async {
    final doc = await _firestore.collection('pairing_codes').doc(code).get();

    if (!doc.exists) {
      throw Exception('Invalid code. Please check and try again.');
    }

    final data = doc.data()!;
    final expiresAt = (data['expires_at'] as Timestamp).toDate();

    if (DateTime.now().isAfter(expiresAt)) {
      await doc.reference.delete();
      throw Exception('This code has expired. Ask the elderly person to generate a new one.');
    }

    final elderlyUid = data['elderly_uid'] as String;

    // Add elderly UID to caretaker's linked_elderly array
    await _firestore.collection('users').doc(caretakerUid).update({
      'linked_elderly': FieldValue.arrayUnion([elderlyUid]),
    });

    // Update the elderly user's profile with all the detailed info
    final updatedDetails = {
      'caretakerId': caretakerUid,
      ...elderlyDetails,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('users').doc(elderlyUid).set(
          updatedDetails,
          SetOptions(merge: true),
        );

    // Also update the name-based doc if it exists (backward compatibility)
    try {
      final elderlyName = elderlyDetails['name'];
      if (elderlyName != null && elderlyName != elderlyUid) {
        final nameDoc = await _firestore.collection('users').doc(elderlyName).get();
        if (nameDoc.exists) {
          await _firestore.collection('users').doc(elderlyName).set(
                updatedDetails,
                SetOptions(merge: true),
              );
        }
      }
    } catch (_) {}

    // Delete the used code
    await doc.reference.delete();

    return elderlyUid;
  }

  /// Fetches the list of linked elderly UIDs for a caretaker.
  Future<List<Map<String, dynamic>>> getLinkedElderlyProfiles(
      String caretakerUid) async {
    final caretakerDoc =
        await _firestore.collection('users').doc(caretakerUid).get();

    if (!caretakerDoc.exists) return [];

    final linkedUids =
        List<String>.from(caretakerDoc.data()?['linked_elderly'] ?? []);
    // Deduplicate UIDs (in case same UID was added twice)
    final uniqueUids = linkedUids.toSet().toList();
    print('🔗 Linked elderly UIDs (${uniqueUids.length} unique of ${linkedUids.length} total): $uniqueUids');

    final profiles = <Map<String, dynamic>>[];
    for (final uid in uniqueUids) {
      try {
        final elderlyDoc =
            await _firestore.collection('users').doc(uid).get();
        if (elderlyDoc.exists) {
          final data = elderlyDoc.data()!;
          print('👤 UID $uid → name: ${data['name']}, age: ${data['age']}, gender: ${data['gender']}');
          profiles.add({
            'uid': uid,
            'name': data['name'] ?? 'Unknown',
            'age': data['age'] ?? '--',
            'gender': data['gender'] ?? '--',
          });
        }
      } catch (_) {
        // Skip if we can't fetch this elderly user's profile
      }
    }

    return profiles;
  }

  /// Looks up the elderly user's profile from a 6-digit care code WITHOUT
  /// consuming / redeeming it.  Returns null if the code is invalid or expired.
  Future<Map<String, dynamic>?> lookupElderlyByCode(String code) async {
    try {
      final doc =
          await _firestore.collection('pairing_codes').doc(code.trim()).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final expiresAt = (data['expires_at'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) return null;

      final elderlyUid = data['elderly_uid'] as String;
      final elderlyDoc =
          await _firestore.collection('users').doc(elderlyUid).get();
      if (!elderlyDoc.exists) return null;

      final profile = elderlyDoc.data()!;
      return {
        'uid':    elderlyUid,
        'name':   profile['name']   as String? ?? '',
        'age':    profile['age']?.toString()  ?? '',
        'gender': profile['gender'] as String? ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  /// Generates a random 6-digit numeric string.
  String _generateRandomCode() {
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    return code;
  }
}
