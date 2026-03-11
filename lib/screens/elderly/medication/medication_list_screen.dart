import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'medication_history_screen.dart';
import 'AddMedicationScreen.dart';

final _firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

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

class _MedicationListScreenState extends State<MedicationListScreen> {
  // ─── Dismiss an alert ────────────────────────────────────────────────────
  Future<void> _dismissAlert(String alertId) async {
    try {
      await _firestore.collection('alerts').doc(alertId).update({
        'isActive': false,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert dismissed'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error dismissing alert: $e');
    }
  }

  // ─── Mark medication as taken ────────────────────────────────────────────
  Future<void> _markAsTaken(String docId, String name) async {
    try {
      final now = DateTime.now();
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('medications')
          .doc(docId)
          .update({'lastTaken': Timestamp.fromDate(now), 'takenToday': true});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $name marked as taken'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Error marking as taken: $e');
    }
  }

  // ─── Snooze ──────────────────────────────────────────────────────────────
  void _snoozeMedication(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏰ $name snoozed for 10 minutes'),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Delete medication ───────────────────────────────────────────────────
  void _deleteMedication(String docId, String name) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              '🗑️ Delete Medication',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to delete $name?',
              style: const TextStyle(fontSize: 18),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontSize: 18)),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _firestore
                      .collection('users')
                      .doc(widget.userId)
                      .collection('medications')
                      .doc(docId)
                      .delete();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🗑️ $name deleted'),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Text(
                  'Delete',
                  style: TextStyle(fontSize: 18, color: Colors.red.shade700),
                ),
              ),
            ],
          ),
    );
  }

  // ─── Navigate to add / edit ───────────────────────────────────────────────
  Future<void> _navigateToAdd({
    Map<String, dynamic>? existing,
    String? docId,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AddMedicationScreen(
              userId: widget.userId,
              existingMedication: existing,
              existingDocId: docId,
            ),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? '✅ Medication added successfully!'
                : '✏️ Medication updated successfully!',
          ),
          backgroundColor:
              existing == null ? Colors.green.shade700 : Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── Build UI ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '💊 My Medications',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Medication list ──────────────────────────────────────────────
          Expanded(child: _buildMedicationList()),
        ],
      ),
      floatingActionButton:
          widget.role == UserRole.caretaker
              ? FloatingActionButton.extended(
                onPressed: () => _navigateToAdd(),
                backgroundColor: Colors.green.shade700,
                icon: const Icon(Icons.add, size: 28),
                label: const Text(
                  'Add Medicine',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              )
              : null,
    );
  }

  // ─── Alert banner ─────────────────────────────────────────────────────────
  Widget _buildAlertBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('alerts')
              .where('userId', isEqualTo: widget.userId)
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          color: Colors.grey.shade100,
          child: Column(
            children:
                snapshot.data!.docs.map((doc) {
                  final alert = doc.data() as Map<String, dynamic>;
                  final type = alert['type'] as String? ?? 'warning';
                  final alertColor = _alertColor(type);
                  final alertBg = _alertBgColor(type);
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: alertBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: alertColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(_alertIcon(type), color: alertColor, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert['title'] as String? ?? 'Alert',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: alertColor,
                                    fontSize: 18,
                                  ),
                                ),
                                if ((alert['message'] as String? ?? '')
                                    .isNotEmpty)
                                  Text(
                                    alert['message'] as String,
                                    style: TextStyle(
                                      color: alertColor.withOpacity(0.8),
                                      fontSize: 15,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: alertColor,
                              size: 24,
                            ),
                            onPressed: () => _dismissAlert(doc.id),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  // ─── Medication list (real-time Firestore) ────────────────────────────────
  Widget _buildMedicationList() {
    return StreamBuilder<QuerySnapshot>(
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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final med = doc.data() as Map<String, dynamic>;
            return _buildMedicationCard(doc.id, med);
          },
        );
      },
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────
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
              fontSize: 22,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.role == UserRole.caretaker)
            Text(
              'Tap the button below to add a medication',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  // ─── Medication card ──────────────────────────────────────────────────────
  Widget _buildMedicationCard(String docId, Map<String, dynamic> med) {
    final name = med['name'] is String ? med['name'] as String : '';
    final dosage = med['dose'] is String ? med['dose'] as String : '';
    final time = med['time'] is String
        ? med['time'] as String
        : (med['time'] is List ? (med['time'] as List).join(', ') : '');
    final days = med['days'] is String
        ? med['days'] as String
        : (med['days'] is List ? (med['days'] as List).join(', ') : '');
    final note = med['note'] is String
        ? med['note'] as String
        : (med['note'] is List ? (med['note'] as List).join(', ') : '');
    final takenToday = med['takenToday'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        takenToday
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medication,
                    size: 30,
                    color:
                        takenToday
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        dosage,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        takenToday
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    takenToday ? '✅ Taken' : '⏰ Pending',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color:
                          takenToday
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                    ),
                  ),
                ),
                // Edit / Delete (caretaker only)
                if (widget.role == UserRole.caretaker) ...[
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue.shade700),
                    onPressed:
                        () => _navigateToAdd(existing: med, docId: docId),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red.shade700),
                    onPressed: () => _deleteMedication(docId, name),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            _infoRow(Icons.access_time, 'Time:', time),
            const SizedBox(height: 8),
            _infoRow(Icons.calendar_today, 'Days:', days),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.note, 'Note:', note),
            ],
            // Elderly actions
            if (widget.role == UserRole.elderly) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          takenToday ? null : () => _markAsTaken(docId, name),
                      icon: const Icon(Icons.check, size: 22),
                      label: const Text(
                        'Taken',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _snoozeMedication(name),
                      icon: const Icon(Icons.snooze, size: 22),
                      label: const Text(
                        'Snooze',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.green.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.black87),
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

  // ─── Alert helpers ────────────────────────────────────────────────────────
  IconData _alertIcon(String type) {
    switch (type.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _alertColor(String type) {
    switch (type.toLowerCase()) {
      case 'critical':
        return Colors.red.shade700;
      case 'info':
        return Colors.blue.shade700;
      default:
        return const Color(0xFF5D4037);
    }
  }

  Color _alertBgColor(String type) {
    switch (type.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFFEBEE);
      case 'info':
        return const Color(0xFFE3F2FD);
      default:
        return const Color(0xFFFFF4E5);
    }
  }
}