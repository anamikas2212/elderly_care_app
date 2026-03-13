import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/medicine_search_service.dart';
import 'dart:async';

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
  bool _isSearching = false;
  static const bool _debugMedSearch = true;
  String? _diagnosticBanner;

  // Controllers
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _doctorController = TextEditingController();
  final _noteController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  Timer? _nameDebounce;
  String _activeQuery = '';

  final _medicineSearchService = MedicineSearchService(_firestore);
  List<MedicineSuggestion> _nameSuggestions = [];
  MedicineSuggestion? _selectedMedicine;
  List<String> _dosageOptions = [];
  String? _selectedDosage;
  String? _medicineError;
  String? _dosageError;

  // Selected values
  List<TimeOfDay> _selectedTimes = [];
  String _selectedFrequency = 'Daily';
  String _selectedFoodTiming = 'Before Food';
  final List<String> _selectedSpecificDays = [];
  final List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<String> _frequencyOptions = ['Daily', 'Specific Days'];

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
      _doctorController.text = med['doctorName'] as String? ?? '';
      _noteController.text = _stripFoodTiming(med['note'] as String? ?? '');

      final daysData = med['days'];
      if (daysData is String) {
        if (daysData == 'Daily') {
          _selectedFrequency = 'Daily';
        } else {
          _selectedFrequency = 'Specific Days';
          _selectedSpecificDays.addAll(daysData.split(', '));
        }
      } else if (daysData is List) {
        _selectedFrequency = 'Specific Days';
        _selectedSpecificDays.addAll(daysData.map((e) => e.toString()));
      }

      _selectedFoodTiming = med['foodTiming'] as String? ?? 'Before Food';

      final timesData = med['times'];
      if (timesData is List) {
        for (var t in timesData) {
          final parsed = _parseTimeReturn(t.toString());
          if (parsed != null) _selectedTimes.add(parsed);
        }
      } else {
        final parsed = _parseTimeReturn(med['time'] as String? ?? '');
        if (parsed != null) _selectedTimes.add(parsed);
      }
    }

    _nameController.addListener(_onNameChanged);
    _nameFocusNode.addListener(_onNameFocusChange);

    // Pre-load suggestions/dosages when editing an existing medicine.
    if (med != null) {
      _loadExistingMatch();
    }

    _runMedicineDiagnostics();
  }

  /// Strip the food timing prefix that was stored in note (e.g. "After Food - ...")
  String _stripFoodTiming(String note) {
    for (final ft in _foodTimingOptions) {
      if (note.startsWith('$ft - ')) return note.substring(ft.length + 3);
      if (note == ft) return '';
    }
    return note;
  }

  TimeOfDay? _parseTimeReturn(String timeStr) {
    if (timeStr.isEmpty) return null;
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.isEmpty) return null;
      final hm = parts[0].split(':');
      if (hm.length < 2) return null;
      int hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);
      if (parts.length > 1) {
        if (parts[1].toUpperCase() == 'PM' && hour != 12) hour += 12;
        if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
      }
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _nameController.removeListener(_onNameChanged);
    _nameFocusNode.removeListener(_onNameFocusChange);
    _nameFocusNode.dispose();
    _nameController.dispose();
    _dosageController.dispose();
    _doctorController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final text = _nameController.text.trim();

    // If user edits after selection, clear selected medicine/dose.
    if (_selectedMedicine != null &&
        text.toLowerCase() != _selectedMedicine!.name.toLowerCase()) {
      setState(() {
        _selectedMedicine = null;
        _dosageOptions = [];
        _selectedDosage = null;
        _medicineError = null;
        _dosageError = null;
      });
    }

    if (text.length < 3) {
      setState(() {
        _nameSuggestions = [];
        _isSearching = false;
        _medicineError = null;
      });
      return;
    }

    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 600), () async {
      final query = _nameController.text.trim();
      _activeQuery = query;
      if (_debugMedSearch) {
        debugPrint('[med-search] query="$query"');
      }
      setState(() => _isSearching = true);
      try {
        // Efficient query using indexed lower-case prefix fields.
        final results = await _medicineSearchService.searchMedicines(query);
        if (!mounted || _activeQuery != query) return;
        if (_debugMedSearch) {
          debugPrint('[med-search] results=${results.length}');
          for (final r in results) {
            debugPrint('[med-search] -> ${r.name} | ${r.shortComposition1}');
          }
        }
        setState(() {
          _nameSuggestions = results;
          _isSearching = false;
        });
      } catch (e) {
        if (_debugMedSearch) {
          debugPrint('[med-search] error: $e');
        }
        if (!mounted) return;
        setState(() {
          _nameSuggestions = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _runMedicineDiagnostics() async {
    try {
      final snap = await _firestore.collection('medicines').limit(1).get();
      if (!mounted) return;
      if (snap.docs.isEmpty) {
        setState(() {
          _diagnosticBanner =
              'Diagnostic: medicines collection is empty in this Firebase project.';
        });
        return;
      }
      final data = snap.docs.first.data();
      final hasTokens = data.containsKey('search_tokens');
      final hasNameLc = data.containsKey('name_lc');
      final hasComp1Lc = data.containsKey('short_comp1_lc');
      if (!hasTokens || !hasNameLc || !hasComp1Lc) {
        setState(() {
          _diagnosticBanner =
              'Diagnostic: medicines docs missing search fields (search_tokens/name_lc). Run backfill.';
        });
        return;
      }
      setState(() => _diagnosticBanner = null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _diagnosticBanner =
            'Diagnostic: failed to read medicines collection. Check Firebase config and rules.';
      });
    }
  }

  Future<void> _onNameFocusChange() async {
    if (_nameFocusNode.hasFocus) return;
    // On blur, attempt exact-match validation so users can type full name
    // without selecting a suggestion.
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_debugMedSearch) {
      debugPrint('[med-search] blur validate="$name"');
    }
    final match = await _medicineSearchService.findExactMatch(name);
    if (!mounted) return;
    if (match == null) {
      if (_debugMedSearch) {
        debugPrint('[med-search] blur match NOT found');
      }
      setState(() {
        _selectedMedicine = null;
        _dosageOptions = [];
        _selectedDosage = null;
        _medicineError =
            'Medicine not recognized. Please select a valid medicine from the dataset.';
      });
      return;
    }

    final options = MedicineDosageExtractor.extractDosages(
      match.shortComposition1,
      match.shortComposition2,
    );
    if (_debugMedSearch) {
      debugPrint('[med-search] blur match found: ${match.name}');
      debugPrint('[med-search] dosages=${options.length}');
    }
    setState(() {
      _selectedMedicine = match;
      _dosageOptions = options;
      _medicineError = null;
    });
  }

  Future<void> _loadExistingMatch() async {
    final text = _nameController.text.trim();
    if (text.isEmpty) return;
    try {
      final match = await _medicineSearchService.findExactMatch(text);
      if (!mounted || match == null) return;
      final options = MedicineDosageExtractor.extractDosages(
        match.shortComposition1,
        match.shortComposition2,
      );
      setState(() {
        _selectedMedicine = match;
        _dosageOptions = options;
        final existingDose = _dosageController.text.trim().toLowerCase();
        _selectedDosage =
            _dosageOptions.contains(existingDose) ? existingDose : null;
        if (_selectedDosage != null) {
          _dosageController.text = _selectedDosage!;
        }
        _medicineError = null;
        _dosageError = null;
      });
    } catch (_) {}
  }

  void _selectSuggestion(MedicineSuggestion suggestion) {
    final options = MedicineDosageExtractor.extractDosages(
      suggestion.shortComposition1,
      suggestion.shortComposition2,
    );
    setState(() {
      _selectedMedicine = suggestion;
      _nameController.text = suggestion.name;
      _nameSuggestions = [];
      _dosageOptions = options;
      _selectedDosage = null;
      _dosageController.text = '';
      _medicineError = null;
      _dosageError = null;
    });
  }

  Future<bool> _ensureValidMedicine() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _medicineError =
            'Medicine not recognized. Please select a valid medicine from the dataset.';
      });
      return false;
    }

    if (_selectedMedicine != null) {
      return true;
    }

    // If user typed an exact medicine name/composition without selecting,
    // validate it directly against Firestore.
    final match = await _medicineSearchService.findExactMatch(name);
    if (match == null) {
      setState(() {
        _medicineError =
            'Medicine not recognized. Please select a valid medicine from the dataset.';
      });
      return false;
    }

    final options = MedicineDosageExtractor.extractDosages(
      match.shortComposition1,
      match.shortComposition2,
    );

    setState(() {
      _selectedMedicine = match;
      _dosageOptions = options;
      _medicineError = null;
    });

    return true;
  }

  bool _validateDosage() {
    final doseRaw = (_selectedDosage ?? _dosageController.text.trim());
    if (doseRaw.isEmpty || _selectedMedicine == null) {
      setState(() {
        _dosageError =
            'Dosage not recognized. Please enter a valid dosage for the selected medicine.';
      });
      return false;
    }

    // Match dosage against short_composition1/2 for the selected medicine.
    final dose = _normalizeDose(doseRaw);
    final comp1 = _normalizeComp(_selectedMedicine!.shortComposition1);
    final comp2 = _normalizeComp(_selectedMedicine!.shortComposition2);

    final matches =
        comp1.contains(dose) || (comp2.isNotEmpty && comp2.contains(dose));

    if (!matches) {
      setState(() {
        _dosageError =
            'Dosage not recognized. Please enter a valid dosage for the selected medicine.';
      });
      return false;
    }

    setState(() => _dosageError = null);
    return true;
  }

  String _normalizeDose(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  String _normalizeComp(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('(', '')
        .replaceAll(')', '');
  }

  // ─── Time picker ──────────────────────────────────────────────────────────
  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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
    if (picked != null) {
      setState(() {
        if (!_selectedTimes.contains(picked)) {
          _selectedTimes.add(picked);
          // Sort times
          _selectedTimes.sort((a, b) {
            if (a.hour != b.hour) return a.hour.compareTo(b.hour);
            return a.minute.compareTo(b.minute);
          });
        }
      });
    }
  }

  void _removeTime(int index) {
    setState(() {
      _selectedTimes.removeAt(index);
    });
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
    final medOk = await _ensureValidMedicine();
    if (!medOk) return;
    if (!_validateDosage()) return;
    if (_selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏰ Please add at least one time'),
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

    final formattedTimes = _selectedTimes.map((t) => _formatTime(t)).toList();

    final data = {
      'name': _nameController.text.trim(),
      'dose': (_selectedDosage ?? _dosageController.text.trim()),
      'doctorName': _doctorController.text.trim(),
      'time': formattedTimes.isNotEmpty ? formattedTimes.first : '', // Legacy
      'times': formattedTimes,
      'days': _selectedFrequency == 'Daily' ? 'Daily' : _selectedSpecificDays,
      'foodTiming': _selectedFoodTiming,
      'note': fullNote,
      'takenToday': false, // Kept for legacy compatibility
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
        if (widget.existingMedication != null &&
            widget.existingMedication!['createdAt'] != null) {
          data['createdAt'] = widget.existingMedication!['createdAt'];
        } else {
          data['createdAt'] =
              FieldValue.serverTimestamp(); // Fallback for old data
        }
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                focusNode: _nameFocusNode,
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
              if (_diagnosticBanner != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      _diagnosticBanner!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              if (_medicineError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _medicineError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              if (_medicineError == null &&
                  _nameController.text.trim().length >= 3 &&
                  _nameSuggestions.isEmpty &&
                  !_isSearching)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'No suggestions. We will validate the exact name on save or when you leave the field.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              if (_nameController.text.trim().length > 0 &&
                  _nameController.text.trim().length < 3)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Type at least 3 characters to see suggestions',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_nameSuggestions.isNotEmpty) _suggestionsDropdown(),

              const SizedBox(height: 24),

              // Dosage
              _sectionTitle('Dosage'),
              const SizedBox(height: 8),
              _dosageOptions.isNotEmpty
                  ? _dropdownContainer(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDosage,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.teal,
                      ),
                      decoration: const InputDecoration.collapsed(hintText: ''),
                      hint: const Text('Select dosage'),
                      items:
                          _dosageOptions
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedDosage = v;
                          _dosageController.text = v ?? '';
                          _dosageError = null;
                        });
                      },
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please select dosage'
                                  : null,
                    ),
                  )
                  : TextFormField(
                    controller: _dosageController,
                    decoration: _inputDeco(
                      hint:
                          _selectedMedicine == null
                              ? 'Select a medicine to see dosages'
                              : 'No dosages available',
                      icon: Icons.local_pharmacy,
                    ),
                    enabled: _selectedMedicine != null,
                    onChanged: (_) => setState(() => _dosageError = null),
                    validator:
                        (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Please enter dosage'
                                : null,
                  ),
              if (_dosageError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _dosageError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 24),

              // Doctor Name
              _sectionTitle('Doctor Name (Optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _doctorController,
                decoration: _inputDeco(
                  hint: 'e.g., Dr. Smith',
                  icon: Icons.person_outline,
                ),
              ),

              const SizedBox(height: 24),

              // Time
              _sectionTitle('Timings'),
              const SizedBox(height: 8),
              if (_selectedTimes.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedTimes.length,
                  itemBuilder: (context, index) {
                    final t = _selectedTimes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                              _formatTime(t),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _removeTime(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              InkWell(
                onTap: _addTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_alarm, color: Colors.teal),
                      const SizedBox(width: 12),
                      Text(
                        _selectedTimes.isEmpty
                            ? 'Add Time'
                            : 'Add Another Time',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.teal,
                          fontWeight: FontWeight.w600,
                        ),
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

              if (_selectedFrequency == 'Specific Days') ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                        'Monday',
                        'Tuesday',
                        'Wednesday',
                        'Thursday',
                        'Friday',
                        'Saturday',
                        'Sunday',
                      ].map((day) {
                        final isSelected = _selectedSpecificDays.contains(day);
                        return ChoiceChip(
                          label: Text(day.substring(0, 3)),
                          selected: isSelected,
                          selectedColor: Colors.teal.shade100,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSpecificDays.add(day);
                              } else {
                                _selectedSpecificDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                ),
              ],

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
  Widget _suggestionsDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _nameSuggestions.length,
        separatorBuilder:
            (_, __) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final s = _nameSuggestions[index];
          final subtitle =
              s.shortComposition1.isNotEmpty ? s.shortComposition1 : '';
          return ListTile(
            title: Text(s.name),
            subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
            onTap: () => _selectSuggestion(s),
          );
        },
      ),
    );
  }

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
