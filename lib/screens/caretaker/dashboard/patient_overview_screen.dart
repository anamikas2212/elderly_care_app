import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/caretaker_theme.dart';

/// A full-screen view that shows a comprehensive overview of the elderly
/// patient — basic info, medical history, allergies, emergency contacts and
/// notes.  Every section can be edited in-place and saved back to Firestore.
class PatientOverviewScreen extends StatefulWidget {
  final String elderlyUid;   // Firebase UID (for Firestore writes)
  final String elderlyId;    // Name-based ID used for game data queries
  final String elderlyName;

  const PatientOverviewScreen({
    Key? key,
    required this.elderlyUid,
    required this.elderlyId,
    required this.elderlyName,
  }) : super(key: key);

  @override
  State<PatientOverviewScreen> createState() => _PatientOverviewScreenState();
}

class _PatientOverviewScreenState extends State<PatientOverviewScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = true;

  // ── Controllers ─────────────────────────────────────────────────────────────
  final _nameCtrl        = TextEditingController();
  final _ageCtrl         = TextEditingController();
  final _genderCtrl      = TextEditingController();
  final _bloodGroupCtrl  = TextEditingController();
  final _heightCtrl      = TextEditingController();
  final _weightCtrl      = TextEditingController();
  final _conditionsCtrl  = TextEditingController();
  final _allergiesCtrl   = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _surgeryCtrl     = TextEditingController();
  final _familyHistCtrl  = TextEditingController();
  final _emergNameCtrl   = TextEditingController();
  final _emergPhoneCtrl  = TextEditingController();
  final _emergRelCtrl    = TextEditingController();
  final _notesCtrl       = TextEditingController();
  final _locationCtrl    = TextEditingController();
  final _occupationCtrl  = TextEditingController();

  // Raw Firestore map for fields we don't explicitly edit
  Map<String, dynamic> _rawData = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _ageCtrl, _genderCtrl, _bloodGroupCtrl, _heightCtrl,
      _weightCtrl, _conditionsCtrl, _allergiesCtrl, _medicationsCtrl,
      _surgeryCtrl, _familyHistCtrl, _emergNameCtrl, _emergPhoneCtrl,
      _emergRelCtrl, _notesCtrl, _locationCtrl, _occupationCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Data Loading ─────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> data = {};

      // Try uid-based doc first
      if (widget.elderlyUid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.elderlyUid)
            .get();
        if (doc.exists) data = doc.data()!;
      }

      // Merge in name-based doc if available (backward compat)
      if (widget.elderlyId.isNotEmpty &&
          widget.elderlyId != widget.elderlyUid &&
          widget.elderlyId.isNotEmpty) {
        try {
          final nameDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.elderlyId)
              .get();
          if (nameDoc.exists) {
            // Name-based doc values fill gaps only
            for (final e in nameDoc.data()!.entries) {
              if (!data.containsKey(e.key) || data[e.key] == null) {
                data[e.key] = e.value;
              }
            }
          }
        } catch (_) {}
      }

      _rawData = data;
      _populateControllers(data);
    } catch (e) {
      // If load fails, just show empty editable form
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateControllers(Map<String, dynamic> d) {
    _nameCtrl.text        = d['name']        as String? ?? widget.elderlyName;
    _ageCtrl.text         = d['age']?.toString() ?? '';
    _genderCtrl.text      = d['gender']      as String? ?? '';
    _bloodGroupCtrl.text  = d['bloodGroup']  as String? ?? '';
    _heightCtrl.text      = d['height']      as String? ?? '';
    _weightCtrl.text      = d['weight']      as String? ?? '';
    _conditionsCtrl.text  = d['conditions']  as String? ?? '';
    _allergiesCtrl.text   = d['allergies']   as String? ?? '';
    _medicationsCtrl.text = d['currentMedications'] as String? ?? '';
    _surgeryCtrl.text     = d['surgicalHistory']    as String? ?? '';
    _familyHistCtrl.text  = d['familyHistory']      as String? ?? '';
    _emergNameCtrl.text   = d['emergencyContactName']  as String? ?? '';
    _emergPhoneCtrl.text  = d['emergencyContactPhone'] as String? ?? '';
    _emergRelCtrl.text    = d['emergencyContactRel']   as String? ?? '';
    _notesCtrl.text       = d['notes']     as String? ?? '';
    _locationCtrl.text    = d['location']  as String? ?? '';
    _occupationCtrl.text  = d['occupation'] as String? ?? '';
  }

  // ── Saving ───────────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final updates = {
        'name':                   _nameCtrl.text.trim(),
        'age':                    _ageCtrl.text.trim(),
        'gender':                 _genderCtrl.text.trim(),
        'bloodGroup':             _bloodGroupCtrl.text.trim(),
        'height':                 _heightCtrl.text.trim(),
        'weight':                 _weightCtrl.text.trim(),
        'conditions':             _conditionsCtrl.text.trim(),
        'allergies':              _allergiesCtrl.text.trim(),
        'currentMedications':     _medicationsCtrl.text.trim(),
        'surgicalHistory':        _surgeryCtrl.text.trim(),
        'familyHistory':          _familyHistCtrl.text.trim(),
        'emergencyContactName':   _emergNameCtrl.text.trim(),
        'emergencyContactPhone':  _emergPhoneCtrl.text.trim(),
        'emergencyContactRel':    _emergRelCtrl.text.trim(),
        'notes':                  _notesCtrl.text.trim(),
        'location':               _locationCtrl.text.trim(),
        'occupation':             _occupationCtrl.text.trim(),
        'updatedAt':              FieldValue.serverTimestamp(),
      };

      // Write to UID-based doc
      if (widget.elderlyUid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.elderlyUid)
            .set(updates, SetOptions(merge: true));
      }

      // Also sync name-based doc (backward compat)
      if (widget.elderlyId.isNotEmpty &&
          widget.elderlyId != widget.elderlyUid) {
        try {
          final nameDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.elderlyId)
              .get();
          if (nameDoc.exists) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.elderlyId)
                .set(updates, SetOptions(merge: true));
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully ✓'),
            backgroundColor: CaretakerColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: CaretakerColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        backgroundColor: CaretakerColors.cardWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
        title: const Text('Patient Overview', style: CaretakerTextStyles.header),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_isEditing)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          _populateControllers(_rawData);
                          setState(() => _isEditing = false);
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: CaretakerColors.errorRed),
                        ),
                      ),
                      TextButton(
                        onPressed: _saveProfile,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: CaretakerColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
          else
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: CaretakerColors.primaryGreen),
              tooltip: 'Edit profile',
              onPressed: () => setState(() => _isEditing = true),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeroCard(),
                const SizedBox(height: 16),
                _buildSection(
                  icon: Icons.person_outline,
                  color: CaretakerColors.primaryGreen,
                  title: 'Basic Information',
                  children: [
                    _buildField('Full Name', _nameCtrl, icon: Icons.badge_outlined),
                    _buildField('Age', _ageCtrl, keyboardType: TextInputType.number, icon: Icons.cake_outlined),
                    _buildField('Gender', _genderCtrl, icon: Icons.wc_outlined),
                    _buildField('Location / Address', _locationCtrl, icon: Icons.home_outlined),
                    _buildField('Occupation / Former Occupation', _occupationCtrl, icon: Icons.work_outline),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  icon: Icons.monitor_heart_outlined,
                  color: Colors.red.shade400,
                  title: 'Medical History',
                  children: [
                    _buildField('Blood Group', _bloodGroupCtrl, icon: Icons.bloodtype_outlined),
                    _buildField('Height (cm)', _heightCtrl, keyboardType: TextInputType.number, icon: Icons.height),
                    _buildField('Weight (kg)', _weightCtrl, keyboardType: TextInputType.number, icon: Icons.monitor_weight_outlined),
                    _buildField('Known Conditions / Diagnoses', _conditionsCtrl, maxLines: 3, icon: Icons.medical_information_outlined),
                    _buildField('Allergies', _allergiesCtrl, maxLines: 3, icon: Icons.warning_amber_outlined),
                    _buildField('Current Medications', _medicationsCtrl, maxLines: 4, icon: Icons.medication_outlined),
                    _buildField('Surgical History', _surgeryCtrl, maxLines: 3, icon: Icons.local_hospital_outlined),
                    _buildField('Family Medical History', _familyHistCtrl, maxLines: 3, icon: Icons.people_outline),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  icon: Icons.phone_in_talk_outlined,
                  color: Colors.orange.shade600,
                  title: 'Emergency Contact',
                  children: [
                    _buildField('Contact Name', _emergNameCtrl, icon: Icons.person_pin_outlined),
                    _buildField('Phone Number', _emergPhoneCtrl, keyboardType: TextInputType.phone, icon: Icons.phone_outlined),
                    _buildField('Relationship', _emergRelCtrl, icon: Icons.family_restroom),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  icon: Icons.notes_outlined,
                  color: Colors.blueGrey,
                  title: 'Additional Notes',
                  children: [
                    _buildField('Notes (care instructions, preferences, etc.)',
                        _notesCtrl, maxLines: 5, icon: Icons.note_outlined),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // ── Hero Card ────────────────────────────────────────────────────────────────

  Widget _buildHeroCard() {
    final name = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : widget.elderlyName;
    final age  = _ageCtrl.text.isNotEmpty ? _ageCtrl.text : '--';
    final gender = _genderCtrl.text.isNotEmpty ? _genderCtrl.text : '--';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CaretakerColors.primaryGreen, Color(0xFF2DBE91)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CaretakerColors.primaryGreen.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Age $age  •  $gender',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                if (_bloodGroupCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.bloodtype, size: 14, color: Colors.white.withOpacity(0.9)),
                      const SizedBox(width: 4),
                      Text(
                        _bloodGroupCtrl.text,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                if (!_isEditing)
                  GestureDetector(
                    onTap: () => setState(() => _isEditing = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Builder ──────────────────────────────────────────────────────────

  Widget _buildSection({
    required IconData icon,
    required Color color,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: CaretakerTextStyles.cardTitle),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 8),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Field Builder ────────────────────────────────────────────────────────────

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    IconData? icon,
  }) {
    final value = ctrl.text;
    final isEmpty = value.isEmpty;

    if (!_isEditing) {
      // Read-only display
      if (isEmpty) return const SizedBox.shrink(); // Hide empty fields in view mode
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.grey.shade500),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: CaretakerColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Edit mode
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: CaretakerColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.grey.shade500) : null,
          filled: true,
          fillColor: CaretakerColors.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: CaretakerColors.primaryGreen,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
