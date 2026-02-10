// lib/screens/elderly/medication/medication_list_screen.dart

import 'package:flutter/material.dart';
//import '../../../models/medication.dart';
import 'medication_history_screen.dart';
import 'AddMedicationScreen.dart';

enum UserRole { elderly, caretaker }

class MedicationListScreen extends StatefulWidget {
  final String userId;
  final UserRole role;

  const MedicationListScreen({
    Key? key,
    required this.userId,
    required this.role,
  }) : super(key: key);

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class Medication {
  final String id;
  final String name;
  final String dosage;
  final List<String> times;
  final List<String> days;
  final String notes;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.times,
    required this.days,
    required this.notes,
  });
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  // Sample medications - replace with Firebase data later
  List<Medication> medications = [
    Medication(
      id: '1',
      name: 'Aspirin',
      dosage: '100mg',
      times: ['08:00 AM', '08:00 PM'],
      days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      notes: 'Take with food',
    ),
    Medication(
      id: '2',
      name: 'Vitamin D',
      dosage: '1000 IU',
      times: ['09:00 AM'],
      days: ['Mon', 'Wed', 'Fri'],
      notes: 'Take after breakfast',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '💊 My Medications',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          medications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: medications.length,
                itemBuilder: (context, index) {
                  return _buildMedicationCard(medications[index]);
                },
              ),

      // ✅ FIX IS HERE
      floatingActionButton:
          widget.role == UserRole.caretaker
              ? FloatingActionButton.extended(
                onPressed: _navigateToAddMedication,
                backgroundColor: Colors.green.shade700,
                icon: const Icon(Icons.add, size: 32),
                label: const Text(
                  'Add Medicine',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              )
              : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 120,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'No medications added yet',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap the button below to add your first medication',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(Medication medication) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showMedicationDetails(medication),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with medicine name and icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.medication,
                      size: 32,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          medication.dosage,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.role == UserRole.caretaker)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          iconSize: 28,
                          color: Colors.blue.shade700,
                          onPressed: () => _editMedication(medication),
                          //tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          iconSize: 28,
                          color: Colors.red.shade700,
                          onPressed: () => _deleteMedication(medication),
                          //tooltip: 'Delete',
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Times
              _buildInfoRow(
                icon: Icons.access_time,
                label: 'Times:',
                value: medication.times.join(', '),
              ),
              const SizedBox(height: 12),

              // Days
              _buildInfoRow(
                icon: Icons.calendar_today,
                label: 'Days:',
                value: medication.days.join(', '),
              ),

              // Notes (if available)
              if (medication.notes != null && medication.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.note,
                  label: 'Notes:',
                  value: medication.notes!,
                ),

                if (widget.role == UserRole.elderly) ...[
                  const SizedBox(height: 16),
                  _buildElderlyActions(medication),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildElderlyActions(Medication medication) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _markAsTaken(medication),
            icon: const Icon(Icons.check),
            label: const Text('Taken'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _snoozeMedication(medication),
            icon: const Icon(Icons.snooze),
            label: const Text('Snooze'),
          ),
        ),
      ],
    );
  }

  void _markAsTaken(Medication medication) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${medication.name} marked as taken'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  void _snoozeMedication(Medication medication) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏰ ${medication.name} snoozed for 10 minutes'),
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Colors.green.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 18, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToAddMedication() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicationScreen(userId: widget.userId),
      ),
    );

    if (result != null && result is Medication) {
      setState(() {
        medications.add(result);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${result.name} added successfully!',
            style: const TextStyle(fontSize: 18),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _editMedication(Medication medication) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddMedicationScreen(
              userId: widget.userId,
              //medication: medication,
            ),
      ),
    );

    if (result != null && result is Medication) {
      setState(() {
        final index = medications.indexWhere((m) => m.id == result.id);
        if (index != -1) {
          medications[index] = result;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✏️ ${result.name} updated successfully!',
            style: const TextStyle(fontSize: 18),
          ),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _deleteMedication(Medication medication) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              '🗑️ Delete Medication',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to delete ${medication.name}?',
              style: const TextStyle(fontSize: 20),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(fontSize: 20)),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    medications.removeWhere((m) => m.id == medication.id);
                  });

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🗑️ ${medication.name} deleted',
                        style: const TextStyle(fontSize: 18),
                      ),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Text(
                  'Delete',
                  style: TextStyle(fontSize: 20, color: Colors.red.shade700),
                ),
              ),
            ],
          ),
    );
  }

  void _showMedicationDetails(Medication medication) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.medication, color: Colors.green.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    medication.name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('💊 Dosage:', medication.dosage),
                  const SizedBox(height: 12),
                  _buildDetailRow('⏰ Times:', medication.times.join('\n')),
                  const SizedBox(height: 12),
                  _buildDetailRow('📅 Days:', medication.days.join(', ')),
                  if (medication.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow('📝 Notes:', medication.notes),
                  ],
                ],
              ),
            ),
            actions: [
              // ✅ Always visible
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(fontSize: 20)),
              ),

              // ✅ Only caretaker can edit
              if (widget.role == UserRole.caretaker)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _editMedication(medication);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit', style: TextStyle(fontSize: 20)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18)),
      ],
    );
  }
}
