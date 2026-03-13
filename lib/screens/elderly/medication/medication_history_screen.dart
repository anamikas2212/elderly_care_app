import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

final _firestore = FirebaseFirestore.instance;

class MedicationHistoryScreen extends StatelessWidget {
  final String userId;

  const MedicationHistoryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '📋 Medication History',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),

      // ✅ FIX: StreamBuilder must be inside body
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(userId)
            .collection('medications')
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No medication history"));
          }

          final docs = snapshot.data!.docs
              .where((d) => (d.data() as Map)['lastTaken'] != null)
              .toList()
            ..sort((a, b) {
              final aTs = (a.data() as Map<String, dynamic>)['lastTaken'] as Timestamp?;
              final bTs = (b.data() as Map<String, dynamic>)['lastTaken'] as Timestamp?;
              final aMillis = aTs?.millisecondsSinceEpoch ?? 0;
              final bMillis = bTs?.millisecondsSinceEpoch ?? 0;
              return bMillis.compareTo(aMillis);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final med = docs[index].data() as Map<String, dynamic>;

              // ✅ Use your custom card
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildHistoryCard(med),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> med) {
    final name = med['name'] as String? ?? 'Unknown';
    final dosage = med['dose'] as String? ?? '';
    final doctor = med['doctorName'] as String? ?? 'Not specified';
    final time = med['time'] as String? ?? '';

    final lastTakenTs = med['lastTaken'] as Timestamp?;
    final lastTaken = lastTakenTs?.toDate();

    final dateStr = lastTaken != null
        ? DateFormat('EEE, dd MMM yyyy – hh:mm a').format(lastTaken)
        : 'Unknown';

    final daysRaw = med['days'];
    final days = daysRaw is List
        ? daysRaw.map((e) => e.toString()).join(', ')
        : (daysRaw as String? ?? '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.green.shade100, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade700,
                size: 28,
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (dosage.isNotEmpty)
                    Text(
                      dosage,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 8),
                  _historyRow(Icons.local_hospital, 'Doctor', doctor),
                  if (time.isNotEmpty)
                    _historyRow(Icons.access_time, 'Scheduled', time),
                  if (days.isNotEmpty)
                    _historyRow(Icons.calendar_today, 'Days', days),
                  const SizedBox(height: 4),
                  _historyRow(Icons.done_all, 'Taken at', dateStr,
                      color: Colors.green.shade700),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: color ?? Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
