import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final _firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

class AddMedicationScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? existingMedication; // null = add mode
  final String? existingDocId; // Firestore doc ID when editing

  const AddMedicationScreen({
    Key? key,
    required this.userId,
    this.existingMedication,
    this.existingDocId,
  }) : super(key: key);

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _noteController = TextEditingController();

  // Selected values
  TimeOfDay? _selectedTime;
  String _selectedFrequency = 'Daily';
  String _selectedFoodTiming = 'Before Food';

  final List<String> _frequencyOptions = [
    'Daily',
    'Every Other Day',
    'Mon, Wed, Fri',
    'Tue, Thu, Sat',
    'Weekdays',
    'Weekends',
    'Custom',
  ];

  final List<String> _foodTimingOptions = [
    'Before Food',
    'After Food',
    'With Food',
    'Empty Stomach',
    'No Restriction',
  ];

  // ─── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final med = widget.existingMedication;
    if (med != null) {
      _nameController.text = med['name'] as String? ?? '';
      _dosageController.text = med['dose'] as String? ?? '';
      _noteController.text = _stripFoodTiming(med['note'] as String? ?? '');
      _selectedFrequency = med['days'] as String? ?? 'Daily';
      _selectedFoodTiming = med['foodTiming'] as String? ?? 'Before Food';
      _parseTime(med['time'] as String? ?? '');
    }
  }

  /// Strip the food timing prefix that was stored in note (e.g. "After Food - ...")
  String _stripFoodTiming(String note) {
    for (final ft in _foodTimingOptions) {
      if (note.startsWith('$ft - ')) return note.substring(ft.length + 3);
      if (note == ft) return '';
    }
    return note;
  }

  void _parseTime(String timeStr) {
    if (timeStr.isEmpty) return;
    try {
      final parts = timeStr.split(' ');
      final hm = parts[0].split(':');
      int hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);
      if (parts.length > 1) {
        if (parts[1].toUpperCase() == 'PM' && hour != 12) hour += 12;
        if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
      }
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ─── Time picker ──────────────────────────────────────────────────────────
  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder:
          (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Colors.teal,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  // ─── Save to Firestore ────────────────────────────────────────────────────
  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏰ Please select a time'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final noteText = _noteController.text.trim();
    final fullNote =
        noteText.isEmpty
            ? _selectedFoodTiming
            : '$_selectedFoodTiming - $noteText';

    final data = {
      'name': _nameController.text.trim(),
      'dose': _dosageController.text.trim(),
      'time': _formatTime(_selectedTime!),
      'days': _selectedFrequency,
      'foodTiming': _selectedFoodTiming,
      'note': fullNote,
      'takenToday': false,
      'status': 'upcoming',
      'userId': widget.userId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final medCollection = _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('medications');

      if (widget.existingDocId != null) {
        // ── Edit mode ──
        await medCollection.doc(widget.existingDocId).update(data);
      } else {
        // ── Add mode ──
        data['createdAt'] = FieldValue.serverTimestamp();
        await medCollection.add(data);
      }

      if (!mounted) return;
      Navigator.pop(context, true); // true = success signal
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving medication: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingMedication != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Medicine' : 'Add Medicine',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          _isSaving
              ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
              : TextButton(
                onPressed: _saveMedication,
                child: Text(
                  isEditing ? 'Update' : 'Save',
                  style: const TextStyle(
                    color: Colors.teal,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medicine Name
              _sectionTitle('Medicine Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: _inputDeco(
                  hint: 'e.g., Aspirin, Paracetamol',
                  icon: Icons.medication,
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Please enter medicine name'
                            : null,
              ),

              const SizedBox(height: 24),

              // Dosage
              _sectionTitle('Dosage'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dosageController,
                decoration: _inputDeco(
                  hint: 'e.g., 500mg, 1 tablet',
                  icon: Icons.local_pharmacy,
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Please enter dosage'
                            : null,
              ),

              const SizedBox(height: 24),

              // Time
              _sectionTitle('Time'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.teal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedTime != null
                              ? _formatTime(_selectedTime!)
                              : 'Select time',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                _selectedTime != null
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Frequency
              _sectionTitle('Frequency'),
              const SizedBox(height: 8),
              _dropdownContainer(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFrequency,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                    items:
                        _frequencyOptions
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                      color: Colors.teal,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(v),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedFrequency = v);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Food Timing
              _sectionTitle('Food Timing'),
              const SizedBox(height: 8),
              _dropdownContainer(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFoodTiming,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                    items:
                        _foodTimingOptions
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Row(
                                  children: [
                                    Icon(
                                      _foodIcon(v),
                                      size: 18,
                                      color: Colors.teal,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(v),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedFoodTiming = v);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Notes
              _sectionTitle('Additional Notes (Optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: _inputDeco(
                  hint: 'e.g., Take with water, avoid dairy',
                  icon: Icons.note_alt_outlined,
                  multiline: true,
                ),
              ),

              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveMedication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child:
                      _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isEditing ? Icons.check : Icons.add,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isEditing ? 'Update Medicine' : 'Add Medicine',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
  );

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    bool multiline = false,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon:
          multiline
              ? Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: Icon(icon, color: Colors.teal),
              )
              : Icon(icon, color: Colors.teal),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.teal, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _dropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: child,
    );
  }

  IconData _foodIcon(String v) {
    switch (v) {
      case 'Before Food':
        return Icons.restaurant_menu;
      case 'After Food':
        return Icons.restaurant;
      case 'With Food':
        return Icons.dining;
      case 'Empty Stomach':
        return Icons.no_meals;
      default:
        return Icons.check_circle_outline;
    }
  }
}
