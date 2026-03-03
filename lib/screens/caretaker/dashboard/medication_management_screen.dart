import 'package:flutter/material.dart';
import '../../../theme/caretaker_theme.dart';
import '../../elderly/medication/AddMedicationScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final _firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

class MedicationManagementScreen extends StatefulWidget {
  final String? userId;

  const MedicationManagementScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<MedicationManagementScreen> createState() =>
      _MedicationManagementScreenState();
}

class _MedicationManagementScreenState
    extends State<MedicationManagementScreen> {
  // ─── Computed values from Firestore docs ────────────────────────────────
  int _takenCount(List<QueryDocumentSnapshot> docs) =>
      docs.where((d) => (d['takenToday'] as bool? ?? false)).length;

  double get _adherencePercentage => 87.0; // replace with real weekly calc

  // ─── Add medicine ────────────────────────────────────────────────────────
  void _addMedicine() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen(userId: widget.userId ?? 'Unknown'),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Medicine added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── Edit medicine ───────────────────────────────────────────────────────
  void _editMedicine(String docId, Map<String, dynamic> med) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AddMedicationScreen(
              userId: widget.userId ?? 'Unknown',
              existingMedication: med,
              existingDocId: docId,
            ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✏️ ${med['name']} updated!'),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── Delete medicine ─────────────────────────────────────────────────────
  void _deleteMedicine(String docId, String medName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red.shade700, size: 32),
              const SizedBox(width: 12),
              const Text('Delete Medicine'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete $medName?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _firestore
                    .collection('users')
                    .doc(widget.userId)
                    .collection('medications')
                    .doc(docId)
                    .delete();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🗑️ $medName deleted'),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Toggle taken ────────────────────────────────────────────────────────
  Future<void> _toggleTaken(String docId, bool currentValue) async {
    await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('medications')
        .doc(docId)
        .update({
          'takenToday': !currentValue,
          'status': !currentValue ? 'taken' : 'upcoming',
        });
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.userId == null || widget.userId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Medication'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: Text('No user linked.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Medication',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.teal,
              size: 28,
            ),
            onPressed: _addMedicine,
            tooltip: 'Add Medicine',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _firestore
                .collection('users')
                .doc(widget.userId)
                .collection('medications')
                .orderBy('time', descending: false)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Progress ──────────────────────────────────────────
                  _buildProgressSection(docs),

                  const SizedBox(height: 24),

                  // ── Missed dose alert ─────────────────────────────────
                  Builder(
                    builder: (_) {
                      final overdue =
                          docs.where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            return (data['status'] as String? ?? '') ==
                                'overdue';
                          }).toList();
                      if (overdue.isEmpty) return const SizedBox.shrink();
                      final med = overdue.first.data() as Map<String, dynamic>;
                      return Column(
                        children: [
                          _buildMissedDoseAlert(med),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),

                  // ── Today's schedule ──────────────────────────────────
                  _buildScheduleSection(docs),

                  const SizedBox(height: 32),

                  // ── Weekly adherence ──────────────────────────────────
                  _buildWeeklyAdherence(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMedicine,
        backgroundColor: Colors.teal,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Medicine',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─── Progress section ─────────────────────────────────────────────────────
  Widget _buildProgressSection(List<QueryDocumentSnapshot> docs) {
    final taken = _takenCount(docs);
    final total = docs.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Today\'s Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              total == 0 ? 'No medicines' : '$taken of $total taken',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.teal.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : taken / total,
            minHeight: 12,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade400),
          ),
        ),
      ],
    );
  }

  // ─── Missed dose alert ────────────────────────────────────────────────────
  Widget _buildMissedDoseAlert(Map<String, dynamic> med) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.red.shade700,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missed Dose: ${med['name']}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scheduled at ${med['time'] ?? ''}',
                  style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Remind', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Schedule section ─────────────────────────────────────────────────────
  Widget _buildScheduleSection(List<QueryDocumentSnapshot> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Schedule',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        if (docs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.medication_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No medications added yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "+ Add Medicine" to get started',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final med = doc.data() as Map<String, dynamic>;
              return _buildMedicationCard(doc.id, med);
            },
          ),
      ],
    );
  }

  // ─── Medication card ──────────────────────────────────────────────────────
  Widget _buildMedicationCard(String docId, Map<String, dynamic> med) {
    final isTaken = med['takenToday'] as bool? ?? false;
    final status = med['status'] as String? ?? 'upcoming';
    final isOverdue = status == 'overdue';

    Color statusColor = Colors.grey;
    Color bgColor = Colors.grey.shade50;
    Widget statusIcon = const Icon(
      Icons.radio_button_unchecked,
      color: Colors.grey,
    );
    String statusText = 'Upcoming';

    if (isTaken) {
      statusColor = Colors.green;
      bgColor = Colors.green.shade50;
      statusIcon = Icon(Icons.check_circle, color: Colors.green.shade700);
      statusText = 'Taken';
    } else if (isOverdue) {
      statusColor = Colors.red;
      bgColor = Colors.red.shade50;
      statusIcon = Icon(Icons.cancel, color: Colors.red.shade700);
      statusText = 'Overdue';
    }

    final note = med['note'] as String? ?? '';

    return GestureDetector(
      onLongPress: () => _showMedicationOptions(docId, med),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Toggle taken on tap
                GestureDetector(
                  onTap: () => _toggleTaken(docId, isTaken),
                  child: statusIcon,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${med['name'] ?? ''} ${med['dose'] ?? ''}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          decoration:
                              isTaken ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        med['time'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      onPressed: () => _editMedicine(docId, med),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      onPressed:
                          () => _deleteMedicine(docId, med['name'] ?? ''),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete',
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Food timing note
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 48),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 14,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          note,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Long press options ───────────────────────────────────────────────────
  void _showMedicationOptions(String docId, Map<String, dynamic> med) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                med['name'] ?? '',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.edit, color: Colors.blue.shade700),
                title: const Text('Edit Medicine'),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMedicine(docId, med);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red.shade700),
                title: const Text('Delete Medicine'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMedicine(docId, med['name'] ?? '');
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // ─── Weekly adherence ─────────────────────────────────────────────────────
  Widget _buildWeeklyAdherence() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekly Adherence',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Weekly Average: ${_adherencePercentage.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.teal.shade700,
          ),
        ),
      ],
    );
  }
}
