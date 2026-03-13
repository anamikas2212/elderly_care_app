import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/pairing_service.dart';
import 'dashboard/caretaker_dashboard.dart';
import '../auth/login_screen.dart';
import 'package:flutter/services.dart';

class PatientSelectionScreen extends StatefulWidget {
  const PatientSelectionScreen({Key? key}) : super(key: key);

  @override
  State<PatientSelectionScreen> createState() => _PatientSelectionScreenState();
}

class _PatientSelectionScreenState extends State<PatientSelectionScreen> {
  final _pairingService = PairingService();
  final _authService = AuthService();
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      // Try Firebase Auth first, fall back to SharedPreferences
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        final prefs = await SharedPreferences.getInstance();
        uid = prefs.getString('caretaker_uid');
      }
      print('👩‍⚕️ Loading Elderly for Caregiver UID: $uid');
      if (uid == null || uid.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final profiles = await _pairingService.getLinkedElderlyProfiles(uid);
      if (mounted)
        setState(() {
          _patients = profiles;
          _isLoading = false;
        });
    } catch (e) {
      print('❌ Error loading Elderly: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddPatientDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddPatientBottomSheet(onSuccess: _loadPatients),
    );
  }

  void _navigateToDashboard(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaretakerDashboard(elderlyUserId: patient['uid']),
      ),
    );
  }

  Future<void> _removePatient(Map<String, dynamic> patient) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Remove Elderly?'),
            content: Text(
              'Remove "${patient['name']}" (UID: ${patient['uid']}) from your linked Elderly?\n\nYou can re-add them with a new Care Code.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          final prefs = await SharedPreferences.getInstance();
          final savedUid = prefs.getString('caretaker_uid');
          if (savedUid == null) return;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(savedUid)
              .update({
                'linked_elderly': FieldValue.arrayRemove([patient['uid']]),
              });
        } else {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'linked_elderly': FieldValue.arrayRemove([patient['uid']]),
          });
        }
        _loadPatients(); // Refresh
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${patient['name']} removed.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'My Linked Elderly',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _patients.isEmpty
              ? _buildEmptyState()
              : _buildPatientList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPatientDialog,
        backgroundColor: Colors.blue.shade600,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Add Elderly',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 80,
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'No Elderly Linked',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the "+ Add Elderly" button below and enter the 6-digit Care Code from your elderly person\'s app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientList() {
    return RefreshIndicator(
      onRefresh: _loadPatients,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _patients.length,
        itemBuilder: (context, index) {
          final patient = _patients[index];
          return _buildPatientCard(patient);
        },
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final name = patient['name'] ?? 'Unknown';
    final age = patient['age'] ?? '--';
    final gender = patient['gender'] ?? '--';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToDashboard(patient),
        onLongPress: () => _removePatient(patient),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Age: $age  •  $gender',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red.shade400,
                    onPressed: () => _removePatient(patient),
                    tooltip: 'Remove Elderly',
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.blue.shade400,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddPatientBottomSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const AddPatientBottomSheet({Key? key, required this.onSuccess})
    : super(key: key);

  @override
  State<AddPatientBottomSheet> createState() => _AddPatientBottomSheetState();
}

class _AddPatientBottomSheetState extends State<AddPatientBottomSheet> {
  final _pairingService = PairingService();
  bool _isLoading = false;
  bool _isFetchingProfile = false; // spinner while looking up the code
  bool _profileFetched = false; // true = name/age/gender locked from Firestore

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Male';
  final _occupationController = TextEditingController();
  final _medicalConditionController = TextEditingController();
  final _phoneController = TextEditingController();

  // Emergency Contact
  final _emgNameController = TextEditingController();
  final _emgRelationController = TextEditingController();
  final _emgAgeController = TextEditingController();
  final _emgOccupationController = TextEditingController();
  final _emgPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Trigger lookup as soon as 6 digits have been entered
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    for (final c in [
      _codeController,
      _nameController,
      _ageController,
      _occupationController,
      _medicalConditionController,
      _phoneController,
      _emgNameController,
      _emgRelationController,
      _emgAgeController,
      _emgOccupationController,
      _emgPhoneController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Code autofetch logic ─────────────────────────────────────────────────

  void _onCodeChanged() {
    final code = _codeController.text.trim();
    if (code.length == 6) {
      _fetchProfileForCode(code);
    } else if (_profileFetched) {
      // User edited the code — clear the pre-filled data
      setState(() {
        _profileFetched = false;
        _nameController.clear();
        _ageController.clear();
        _selectedGender = 'Male';
      });
    }
  }

  Future<void> _fetchProfileForCode(String code) async {
    if (_isFetchingProfile) return;
    setState(() => _isFetchingProfile = true);

    try {
      final profile = await _pairingService.lookupElderlyByCode(code);
      if (!mounted) return;

      if (profile != null) {
        final name = profile['name'] as String? ?? '';
        final age = profile['age'] as String? ?? '';
        final gender = profile['gender'] as String? ?? '';

        setState(() {
          _nameController.text = name;
          _ageController.text = age;
          if (['Male', 'Female', 'Other'].contains(gender)) {
            _selectedGender = gender;
          } else if (gender.toLowerCase().startsWith('m')) {
            _selectedGender = 'Male';
          } else if (gender.toLowerCase().startsWith('f')) {
            _selectedGender = 'Female';
          } else if (gender.isNotEmpty) {
            _selectedGender = 'Other';
          }
          _profileFetched = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Profile found: $name'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() => _profileFetched = false);
      }
    } catch (_) {
      if (mounted) setState(() => _profileFetched = false);
    } finally {
      if (mounted) setState(() => _isFetchingProfile = false);
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showSnack('Please enter a valid 6-digit code.', isError: true);
      return;
    }

    final ageStr = _ageController.text.trim();
    final intAge = int.tryParse(ageStr) ?? 0;

    if (intAge < 18 || intAge > 130) {
      _showSnack('Elderly patient must be between 18 and 130 years old.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final caretakerUid = FirebaseAuth.instance.currentUser?.uid;
      if (caretakerUid == null) throw Exception('Not logged in.');

      final elderlyDetails = {
        'name': _nameController.text.trim(),
        'age': _ageController.text.trim(),
        'gender': _selectedGender,
        'occupation': _occupationController.text.trim(),
        'medicalCondition': _medicalConditionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'emergencyContact': {
          'name': _emgNameController.text.trim(),
          'relation': _emgRelationController.text.trim(),
          'age': _emgAgeController.text.trim(),
          'occupation': _emgOccupationController.text.trim(),
          'phone': _emgPhoneController.text.trim(),
        },
      };

      await _pairingService.redeemPairingCode(
        code: code,
        caretakerUid: caretakerUid,
        elderlyDetails: elderlyDetails,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      _showSnack('Elderly linked successfully!');
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      ),
    );
  }

  // ── Builders ─────────────────────────────────────────────────────────────

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    bool isNumber = false,
    bool required = false,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        readOnly: readOnly,
        keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) return 'Required';
          if (isNumber && v != null && v.trim().isNotEmpty) {
            if (!RegExp(r'^(\+91[\-\s]?)?[0]?[6-9]\d{9}$').hasMatch(v.trim())) {
              return 'Invalid Indian phone number';
            }
          }
          return null;
        },
        style: TextStyle(
          color: readOnly ? Colors.grey.shade700 : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          filled: true,
          fillColor: readOnly ? Colors.green.shade50 : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                readOnly
                    ? BorderSide(color: Colors.green.shade300, width: 1.2)
                    : BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                readOnly
                    ? BorderSide(color: Colors.green.shade300, width: 1.2)
                    : BorderSide.none,
          ),
          suffixIcon:
              readOnly
                  ? Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: Colors.green.shade400,
                  )
                  : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Add Elderly Patient',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 30),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Care Code ──────────────────────────────────────────
                    const Text(
                      'Care Code',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            letterSpacing: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: '000000',
                            counterText: '',
                            filled: true,
                            fillColor: Colors.blue.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.blue.shade200,
                              ),
                            ),
                          ),
                          validator:
                              (v) =>
                                  v!.trim().length != 6
                                      ? 'Enter the 6-digit code'
                                      : null,
                        ),
                        if (_isFetchingProfile)
                          Positioned(
                            right: 16,
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blue.shade500,
                              ),
                            ),
                          ),
                        if (_profileFetched)
                          Positioned(
                            right: 16,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green.shade500,
                              size: 24,
                            ),
                          ),
                      ],
                    ),

                    // Hint text beneath code field
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 16),
                      child:
                          _profileFetched
                              ? Row(
                                children: [
                                  Icon(
                                    Icons.auto_fix_high,
                                    size: 14,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Name, age & gender auto-filled from the elderly\'s profile',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              )
                              : Text(
                                'Enter code to auto-fill patient info',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                    ),

                    // ── Patient Profile ────────────────────────────────────
                    const Text(
                      'Patient Profile',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildField(
                      _nameController,
                      'Full Name',
                      required: true,
                      readOnly: _profileFetched,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z\s]'),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            _ageController,
                            'Age',
                            required: true,
                            readOnly: _profileFetched,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            maxLength: 3,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color:
                                  _profileFetched
                                      ? Colors.green.shade50
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  _profileFetched
                                      ? Border.all(
                                        color: Colors.green.shade300,
                                        width: 1.2,
                                      )
                                      : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedGender,
                                      isExpanded: true,
                                      // Lock the dropdown when profile is fetched
                                      onChanged:
                                          _profileFetched
                                              ? null
                                              : (v) => setState(
                                                () => _selectedGender = v!,
                                              ),
                                      items:
                                          ['Male', 'Female', 'Other']
                                              .map(
                                                (s) => DropdownMenuItem(
                                                  value: s,
                                                  child: Text(s),
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  ),
                                ),
                                if (_profileFetched)
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 16,
                                    color: Colors.green.shade400,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    _buildField(
                      _occupationController,
                      'Occupation (Optional)',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z\s]'),
                        ),
                      ],
                    ),
                    _buildField(
                      _medicalConditionController,
                      'Medical Condition(s)',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z\s]'),
                        ),
                      ],
                    ),
                    _buildField(
                      _phoneController,
                      'Phone Number',
                      isNumber: true,
                      required: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                      ],
                    ), // ── Emergency Contact ──────────────────────────────────
                    const SizedBox(height: 12),
                    const Text(
                      'Emergency Contact',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      _emgNameController,
                      'Name',
                      required: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z\s]'),
                        ),
                      ],
                    ),
                    _buildField(
                      _emgRelationController,
                      'Relation to Patient',
                      required: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z\s]'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            _emgAgeController,
                            'Age',
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            maxLength: 3,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            _emgOccupationController,
                            'Occupation',
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z\s]'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _buildField(
                      _emgPhoneController,
                      'Phone Number',
                      isNumber: true,
                      required: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // ── Submit Button ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      (_isLoading || _isFetchingProfile) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            'Link & Save Patient',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
