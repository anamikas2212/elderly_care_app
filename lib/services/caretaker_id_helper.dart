import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper to get current caretaker UID.
/// Prefers FirebaseAuth.currentUser, falls back to SharedPreferences.
class CaretakerIdHelper {
  static Future<String?> getCurrentCaretakerId() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) return authUser.uid;

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('caretaker_uid');
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {}

    return null;
  }

  static String? getCurrentCaretakerIdSync() {
    return FirebaseAuth.instance.currentUser?.uid;
  }
}
