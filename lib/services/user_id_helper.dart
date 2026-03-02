import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper to get the current elderly user's UID for Firestore.
/// Tries FirebaseAuth.currentUser first (preferred), then falls back
/// to the UID stored in SharedPreferences by ElderlyInitialLoginScreen.
///
/// This handles the case where the Firebase Auth session has been lost
/// (e.g., after a hot-restart on Windows) but the UID was already
/// persisted locally in SharedPreferences.
class UserIdHelper {
  /// Returns the userId to use for Firestore operations, or null if none found.
  static Future<String?> getCurrentUserId() async {
    // 1. Prefer the live Firebase Auth user
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) return authUser.uid;

    // 2. Fall back to the UID saved in SharedPreferences during login
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('elderly_user_uid') ??
          prefs.getString('elderly_user_id');
      if (uid != null && uid.isNotEmpty) {
        // Attempt to re-sign-in anonymously so future Firebase calls work
        try {
          final cred = await FirebaseAuth.instance.signInAnonymously();
          // Note: this creates a NEW anonymous user if the old one is gone.
          // For production, use persistent auth. For now, save the new UID.
          if (cred.user != null) {
            final newUid = cred.user!.uid;
            // If the new UID differs, update prefs so the dashboard stays in sync
            if (newUid != uid) {
              final p = await SharedPreferences.getInstance();
              await p.setString('elderly_user_uid', newUid);
              await p.setString('elderly_user_id', newUid);
              return newUid;
            }
          }
        } catch (_) {}
        return uid;
      }
    } catch (_) {}

    return null;
  }

  /// Synchronous check — only checks FirebaseAuth (no IO).
  /// Use this only when you can't await.
  static String? getCurrentUserIdSync() {
    return FirebaseAuth.instance.currentUser?.uid;
  }
}
