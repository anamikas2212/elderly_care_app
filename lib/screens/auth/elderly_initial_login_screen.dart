import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../elderly/home/elderly_dashboard.dart';
import '../../services/pairing_service.dart';

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

    // Sign in anonymously to get a FRESH Firebase UID for this elderly user.
    // Always sign out first to avoid reusing the caretaker's session or
    // a previous elderly user's anonymous session.
    String uid = '';
    final elderlyId = _nameController.text.trim();
    try {
      final existingUser = FirebaseAuth.instance.currentUser;
      if (existingUser != null) {
        await FirebaseAuth.instance.signOut();
      }
      final credential = await FirebaseAuth.instance.signInAnonymously();
      uid = credential.user?.uid ?? '';
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
    await prefs.setString('user_role', 'elderly');

    // Write elderly user document to Firestore so EnhancedMemoryService
    // can look up the caretakerId when sending notifications.
    try {
      final Map<String, dynamic> userData = {
        'name': elderlyId,
        'age': _ageController.text.trim(),
        'gender': _genderController.text.trim(),
        'role': 'elderly',
        'authUid': uid,
        'lastActive': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(elderlyId)
          .set(userData, SetOptions(merge: true));
      print('✅ Elderly user profile saved to Firestore');

      // Generate 6-digit pairing code for caretaker linking
      try {
        final code = await _pairingService.generatePairingCode(elderlyId);
        await prefs.setString('care_code', code);
        print('✅ Care Code generated and saved: $code');
      } catch (e) {
        print('⚠️ Could not generate pairing code: $e');
      }
    } catch (e) {
      print('⚠️ Could not save user profile to Firestore: $e');
    }

    // Navigate to dashboard AFTER code generation is complete
    await Future.delayed(const Duration(milliseconds: 500));
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
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
                  const SizedBox(height: 20),

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
                            ? const CircularProgressIndicator(color: Colors.white)
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
                                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 30),
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
}
*/
