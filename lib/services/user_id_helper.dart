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
    // 1. Prefer the persisted UID used as the Firestore document id.
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid =
          prefs.getString('elderly_user_id') ??
          prefs.getString('elderly_user_uid');
      if (uid != null && uid.isNotEmpty) return uid;
      final name = prefs.getString('elderly_user_name');
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}

    // 2. Fall back to the live Firebase Auth user (if any)
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) return authUser.uid;

    return null;
  }

  /// Synchronous check — only checks FirebaseAuth (no IO).
  /// Use this only when you can't await.
  static String? getCurrentUserIdSync() {
    return FirebaseAuth.instance.currentUser?.uid;
  }
}
