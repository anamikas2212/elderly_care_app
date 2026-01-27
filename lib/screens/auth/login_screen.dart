// FILE LOCATION: lib/screens/auth/login_screen.dart
// ✅ COMPLETE FIXED VERSION - Replace your entire file with this

import 'package:flutter/material.dart';
import '../elderly/home/elderly_dashboard.dart';
import '../caretaker/dashboard/caretaker_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? selectedRole;

  void selectRole(String role) {
    setState(() {
      selectedRole = role;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (role == 'elderly') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ElderlyDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CaretakerDashboard()),
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade100, Colors.purple.shade100],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withAlpha(77),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite,
                      size: 80,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Title
                  const Text(
                    'Unified Geriatric Care',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Who are you?',
                    style: TextStyle(fontSize: 24, color: Colors.black54),
                  ),
                  const SizedBox(height: 50),

                  // Elderly Button
                  GestureDetector(
                    onTap: () => selectRole('elderly'),
                    child: AnimatedScale(
                      scale: selectedRole == 'elderly' ? 0.95 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withAlpha(102),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 30,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.elderly, size: 50, color: Colors.white),
                            SizedBox(width: 20),
                            Text(
                              'I am Elderly',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Caretaker Button
                  GestureDetector(
                    onTap: () => selectRole('caretaker'),
                    child: AnimatedScale(
                      scale: selectedRole == 'caretaker' ? 0.95 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withAlpha(102),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 30,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.people, size: 50, color: Colors.white),
                            SizedBox(width: 20),
                            Text(
                              'I am Caretaker',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
      // ✅ ADD TEST BUTTON HERE - Floating action button for testing the game
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/color-tap',
            arguments: {'difficulty': 1, 'userId': 'test_user'},
          );
        },
        icon: const Icon(Icons.gamepad),
        label: const Text('Test Game'),
        backgroundColor: Colors.purple,
      ),
    );
  }
}
