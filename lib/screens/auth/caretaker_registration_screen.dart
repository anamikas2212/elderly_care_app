import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../caretaker/patient_selection_screen.dart';
import 'package:flutter/services.dart';

class CaretakerRegistrationScreen extends StatefulWidget {
  const CaretakerRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<CaretakerRegistrationScreen> createState() =>
      _CaretakerRegistrationScreenState();
}

class _CaretakerRegistrationScreenState
    extends State<CaretakerRegistrationScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Female';
  final _occupationController = TextEditingController();
  final _roleController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final age = _ageController.text.trim();
    final occupation = _occupationController.text.trim();
    final role = _roleController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    final intAge = int.tryParse(age) ?? 0;

    if (name.isEmpty ||
        age.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        role.isEmpty) {
      _showError('Please fill in all required fields.');
      return;
    }

    // Stricter Email Validation
    final emailRegex = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address (e.g., name@gmail.com).');
      return;
    }

    if (intAge < 18 || intAge > 130) {
      _showError('Caretaker must be between 18 and 130 years old.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.registerCaretaker(
        name: name,
        age: age,
        gender: _selectedGender,
        occupation: occupation,
        email: email,
        password: password,
        familyRole: role,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PatientSelectionScreen()),
        (route) => false,
      );
    } catch (e) {
      print('❌ Caregiver registration error: $e');
      String msg = 'Registration failed. Please try again.';
      if (e.toString().contains('email-already-in-use')) {
        msg = 'This email is already registered. Try logging in.';
      } else if (e.toString().contains('invalid-email')) {
        msg = 'Invalid email format.';
      } else if (e.toString().contains('weak-password')) {
        msg = 'Password is too weak. Use at least 6 characters.';
      } else if (e.toString().contains('operation-not-allowed')) {
        msg =
            'Email/Password sign-in is not enabled. Please enable it in Firebase Console.';
      }
      _showError('$msg\n\nDebug: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, size: 28),
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Icon(
                    Icons.person_add_rounded,
                    size: 60,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Register as a Caregiver',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 30),

                  _buildTextField(
                    controller: _nameController,
                    hint: 'Full Name *',
                    icon: Icons.person_outline,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildTextField(
                          controller: _ageController,
                          hint: 'Age *',
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 3,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(flex: 2, child: _buildDropdown()),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _roleController,
                    hint: 'Family Role (e.g. Son, Nurse) *',
                    icon: Icons.family_restroom,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _occupationController,
                    hint: 'Occupation (Optional)',
                    icon: Icons.work_outline,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _emailController,
                    hint: 'Email Address *',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _passwordController,
                    hint: 'Password *',
                    icon: Icons.lock_outline,
                    obscure: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _confirmPasswordController,
                    hint: 'Confirm Password *',
                    icon: Icons.lock_outline,
                    obscure: _obscureConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed:
                          () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: Colors.blue.shade400),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue.shade400),
          items:
              ['Female', 'Male', 'Others'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: const TextStyle(fontSize: 16)),
                );
              }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() => _selectedGender = newValue);
            }
          },
        ),
      ),
    );
  }
}
