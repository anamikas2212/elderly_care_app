import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../elderly/home/elderly_dashboard.dart';
import '../../services/pairing_service.dart';
import '../../services/medication_notification_service.dart';
import 'package:flutter/services.dart';

class ElderlyInitialLoginScreen extends StatefulWidget {
  const ElderlyInitialLoginScreen({super.key});

  @override
  State<ElderlyInitialLoginScreen> createState() =>
      _ElderlyInitialLoginScreenState();
}

class _ElderlyInitialLoginScreenState extends State<ElderlyInitialLoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final PairingService _pairingService = PairingService();
  bool _isAnimating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    super.dispose();
  }

  void _login() async {
    final ageStr = _ageController.text.trim();
    final intAge = int.tryParse(ageStr) ?? 0;

    if (_nameController.text.trim().isEmpty ||
        ageStr.isEmpty ||
        _genderController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields (Name, Age, Gender)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (intAge < 18 || intAge > 130) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elderly user must be between 18 and 130 years old.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isAnimating = true);

    // ── Stable UID ──────────────────────────────────────────────────────────
    // IMPORTANT: For returning users we NEVER call signInAnonymously() again.
    // Every call to signInAnonymously() creates a brand-new Firebase UID which
    // breaks the pairing code link and caretaker association.
    // We only create one anonymous session — on the very first app launch on
    // this device — and then permanently store that UID locally.
    final prefs = await SharedPreferences.getInstance();
    String uid = prefs.getString('elderly_user_uid') ?? '';

    if (uid.isEmpty) {
      // ── First-time login on this device ──────────────────────────────────
      try {
        if (FirebaseAuth.instance.currentUser != null) {
          await FirebaseAuth.instance.signOut();
        }
        final credential = await FirebaseAuth.instance.signInAnonymously();
        uid = credential.user?.uid ?? '';
      } catch (e) {
        uid = _nameController.text.trim(); // offline fallback
      }
      if (uid.isNotEmpty) {
        await prefs.setString('elderly_user_uid', uid);
        await prefs.setString('elderly_user_id', uid);
      }
    }
    // ── Returning user: DO NOT call signInAnonymously() again ────────────────
    // Just use the stored uid as-is. Firebase Auth session may or may not be
    // active — that's fine; Firestore writes work regardless.
    // ────────────────────────────────────────────────────────────────────────

    // Persist latest profile info locally.
    await prefs.setString('elderly_user_uid', uid);
    await prefs.setString('elderly_user_id', uid);
    await prefs.setString('elderly_user_name', _nameController.text.trim());
    await prefs.setString('elderly_user_age', _ageController.text.trim());
    await prefs.setString('elderly_user_gender', _genderController.text.trim());
    await prefs.setString('user_role', 'elderly');

    await MedicationNotificationService.instance.start(uid);

    // Update Firestore profile (merge so we never clobber caretakerId which
    // is set exclusively by PairingService.redeemPairingCode).
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'age': _ageController.text.trim(),
        'gender': _genderController.text.trim(),
        'role': 'elderly',
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ Elderly profile saved/updated (uid: $uid)');

      // Reuse the locally-saved care code if it exists.  Only call
      // generatePairingCode when there's no code yet — this is what ensures
      // the code is created exactly once and never regenerated.
      final existingCode = prefs.getString('care_code') ?? '';
      if (existingCode.isNotEmpty) {
        print('✅ Reusing existing Care Code: $existingCode');
      } else {
        try {
          final code = await _pairingService.generatePairingCode(uid);
          await prefs.setString('care_code', code);
          print('✅ Care Code generated: $code');
        } catch (e) {
          print('⚠️ Could not generate pairing code: $e');
        }
      }
    } catch (e) {
      print('⚠️ Could not save profile to Firestore: $e');
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  ElderlyDashboard(currentUserId: _nameController.text.trim()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.purple.shade50],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, size: 28),
                      color: Colors.purple.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Logo ──────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.elderly_rounded,
                      size: 80,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Heading ───────────────────────────────────────────────
                  Text(
                    'Welcome!',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please tell us a little about yourself.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Form fields ───────────────────────────────────────────
                  _buildInput(
                    controller: _nameController,
                    hint: 'Your Name',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInput(
                    controller: _ageController,
                    hint: 'Age (e.g. 78)',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 3,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value:
                            _genderController.text.isEmpty
                                ? 'Female'
                                : _genderController.text,
                        isExpanded: true,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.black87,
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.purple.shade400,
                        ),
                        items:
                            ['Female', 'Male', 'Others'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Center(
                                  child: Text(
                                    value,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              );
                            }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() => _genderController.text = newValue);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Care Code info card ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.purple.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.link_rounded,
                          color: Colors.purple.shade400,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'After logging in, share your 6-digit Care Code '
                            'with your caretaker so they can link to your account.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.purple.shade800,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Login button ──────────────────────────────────────────
                  GestureDetector(
                    onTap: _isAnimating ? null : _login,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _isAnimating ? 70 : 250,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade400,
                            Colors.blue.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          _isAnimating ? 50 : 35,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.shade300,
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child:
                            _isAnimating
                                ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                                : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text(
                                      'Let\'s Go',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ],
                                ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        style: const TextStyle(fontSize: 20),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          counterText: '',
          hintStyle: const TextStyle(color: Colors.black26),
        ),
      ),
    );
  }
}

/*import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../elderly/home/elderly_dashboard.dart';


class ElderlyInitialLoginScreen extends StatefulWidget {
  const ElderlyInitialLoginScreen({super.key});

  @override
  State<ElderlyInitialLoginScreen> createState() => _ElderlyInitialLoginScreenState();
}

class _ElderlyInitialLoginScreenState extends State<ElderlyInitialLoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  bool _isAnimating = false;

  void _login() async {
    if (_nameController.text.trim().isEmpty || 
        _ageController.text.trim().isEmpty || 
        _genderController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields (Name, Age, Gender)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isAnimating = true;
    });

    // Sign in anonymously (auth), but use name as the app-level UID
    String uid = '';
    final elderlyId = _nameController.text.trim();
    try {
      final existingUser = FirebaseAuth.instance.currentUser;
      if (existingUser != null) {
        uid = existingUser.uid;
      } else {
        final credential = await FirebaseAuth.instance.signInAnonymously();
        uid = credential.user?.uid ?? '';
      }
    } catch (e) {
      // Firebase not available — fall back to name-based ID
      uid = elderlyId;
    }

    // Save details locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('elderly_user_uid', elderlyId);
    await prefs.setString('elderly_user_id', elderlyId);
    await prefs.setString('elderly_user_name', elderlyId);
    await prefs.setString('elderly_user_age', _ageController.text.trim());
    await prefs.setString('elderly_user_gender', _genderController.text.trim());
    await MedicationNotificationService.instance.start(elderlyId);

    // Simulate a brief loading/welcome delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ElderlyDashboard(
              currentUserId: _nameController.text.trim(),
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.purple.shade50],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon / Logo
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.elderly_rounded,
                      size: 80,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Welcome Text
                  Text(
                    'Welcome!',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please tell us your name\nso we can save your progress.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Name Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 20),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Your Name',
                        hintStyle: TextStyle(color: Colors.black26),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Age Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 20),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Age (e.g. 78)',
                        hintStyle: TextStyle(color: Colors.black26),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Gender Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: TextField(
                      controller: _genderController,
                      style: const TextStyle(fontSize: 20),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Gender (e.g. Female)',
                        hintStyle: TextStyle(color: Colors.black26),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Login Button
                  GestureDetector(
                    onTap: _login,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _isAnimating ? 70 : 250,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade400, Colors.blue.shade400],
                        ),
                        borderRadius: BorderRadius.circular(_isAnimating ? 50 : 35),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.shade300,
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isAnimating
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    "Let's Go",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 20),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black26),
        ),
      ),
    );
  }
}
*/
