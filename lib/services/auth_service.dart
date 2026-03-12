import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // ── Elderly Auth (Anonymous) ──────────────────────────────────────────────

  /// Signs in anonymously and creates/updates elderly profile in Firestore.
  Future<String> registerElderly({
    required String name,
    required String age,
    required String gender,
  }) async {
    // Reuse existing anonymous session if available
    User? user = _auth.currentUser;
    if (user == null) {
      final credential = await _auth.signInAnonymously();
      user = credential.user;
    }
    final uid = user!.uid;
    final elderlyId = name.trim();

    // Save profile to Firestore
    await _firestore.collection('users').doc(elderlyId).set({
      'name': name,
      'age': age,
      'gender': gender,
      'role': 'elderly',
      'authUid': uid,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Save locally for auto-login
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('elderly_user_uid', elderlyId);
    await prefs.setString('elderly_user_id', elderlyId);
    await prefs.setString('elderly_user_name', elderlyId);
    await prefs.setString('elderly_user_age', age);
    await prefs.setString('elderly_user_gender', gender);
    await prefs.setString('user_role', 'elderly');

    return elderlyId;
  }

  /// Checks if an elderly user is already logged in locally.
  Future<String?> getElderlyUidIfLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    if (role != 'elderly') return null;
    return prefs.getString('elderly_user_name') ??
        prefs.getString('elderly_user_id') ??
        prefs.getString('elderly_user_uid');
  }

  // ── Caretaker Auth (Email/Password) ───────────────────────────────────────

  /// Registers a new caretaker with email and password.
  Future<String> registerCaretaker({
    required String name,
    required String age,
    required String gender,
    required String occupation,
    required String email,
    required String password,
    required String familyRole,
    }) async {
    // Sign out any existing anonymous session first
    if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
      await _auth.signOut();
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    // Save profile to Firestore
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'age': age,
      'gender': gender,
      'occupation': occupation,
      'email': email,
      'familyRole': familyRole,
      'role': 'caretaker',
      'linked_elderly': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Save role locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', 'caretaker');
    await prefs.setString('caretaker_uid', uid);

    return uid;
  }

  /// Signs in an existing caretaker.
  Future<String> loginCaretaker({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    // If user logged in via email/password, they are a caretaker.
    // Create or fix the Firestore profile if it's missing or has wrong role.
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data()?['role'] != 'caretaker') {
      await _firestore.collection('users').doc(uid).set({
        'role': 'caretaker',
        'email': email,
        'linked_elderly': doc.exists ? (doc.data()?['linked_elderly'] ?? []) : [],
      }, SetOptions(merge: true));
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', 'caretaker');
    await prefs.setString('caretaker_uid', uid);

    return uid;
  }

  /// Checks if a caretaker is already logged in.
  Future<bool> isCaretakerLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString('user_role');
    final savedUid = prefs.getString('caretaker_uid');

    // If SharedPreferences says caretaker, verify with Firebase Auth
    if (savedRole == 'caretaker' && savedUid != null && savedUid.isNotEmpty) {
      // Wait briefly for Firebase to restore session
      try {
        final user = await _auth.authStateChanges().first.timeout(
          const Duration(seconds: 3),
          onTimeout: () => _auth.currentUser,
        );
        // If Firebase confirms a non-anonymous user, we're good
        if (user != null && !user.isAnonymous) return true;
        // Even if Firebase hasn't restored yet, trust SharedPreferences
        return true;
      } catch (_) {
        return true; // Trust SharedPreferences
      }
    }
    return false;
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await prefs.remove('caretaker_uid');
    await prefs.remove('elderly_user_uid');
    await prefs.remove('elderly_user_id');
    await prefs.remove('elderly_user_name');
    await prefs.remove('elderly_user_age');
    await prefs.remove('elderly_user_gender');
    await prefs.remove('care_code');
  }

  Future<void> signOutElderly() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
