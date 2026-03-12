import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/caretaker_theme.dart';

class SafetyReportsScreen extends StatelessWidget {
  final String elderlyUserId;

  const SafetyReportsScreen({super.key, required this.elderlyUserId});

  Future<_ReportData> _loadReportData() async {
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));
    final yearStart = now.subtract(const Duration(days: 365));

    final safeZoneWeek = await FirebaseFirestore.instance
        .collection('safezone_logs')
        .doc(elderlyUserId)
        .collection('logs')
        .where('triggeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .orderBy('triggeredAt', descending: true)
        .get();

    final safeZoneYear = await FirebaseFirestore.instance
        .collection('safezone_logs')
        .doc(elderlyUserId)
        .collection('logs')
        .where('triggeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart))
        .orderBy('triggeredAt', descending: true)
        .get();

    final sosWeek = await FirebaseFirestore.instance
        .collection('sos_logs')
        .doc(elderlyUserId)
        .collection('logs')
        .where('triggeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .orderBy('triggeredAt', descending: true)
        .get();

    final sosYear = await FirebaseFirestore.instance
        .collection('sos_logs')
        .doc(elderlyUserId)
        .collection('logs')
        .where('triggeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart))
        .orderBy('triggeredAt', descending: true)
        .get();

    final exitsByDay = <String, int>{};
    for (final doc in safeZoneWeek.docs) {
      final ts = doc.data()['triggeredAt'] as Timestamp?;
      if (ts == null) continue;
      final dt = ts.toDate();
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      exitsByDay[key] = (exitsByDay[key] ?? 0) + 1;
    }

    int sosTriggeredWeek = 0;
    int sosFalseAlarmWeek = 0;
    for (final doc in sosWeek.docs) {
      final action = doc.data()['action'] as String? ?? '';
      if (action == 'triggered') sosTriggeredWeek++;
      if (action == 'false_alarm') sosFalseAlarmWeek++;
    }

    int sosTriggeredYear = 0;
    int sosFalseAlarmYear = 0;
    for (final doc in sosYear.docs) {
      final action = doc.data()['action'] as String? ?? '';
      if (action == 'triggered') sosTriggeredYear++;
      if (action == 'false_alarm') sosFalseAlarmYear++;
    }

    return _ReportData(
      safeZoneExitsWeek: safeZoneWeek.docs.length,
      safeZoneExitsYear: safeZoneYear.docs.length,
      safeZoneExitsByDay: exitsByDay,
      sosTriggeredWeek: sosTriggeredWeek,
      sosTriggeredYear: sosTriggeredYear,
      sosFalseAlarmWeek: sosFalseAlarmWeek,
      sosFalseAlarmYear: sosFalseAlarmYear,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        backgroundColor: CaretakerColors.background,
        elevation: 0,
        title: const Text(
          'Safety Reports',
          style: TextStyle(color: CaretakerColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
      ),
      body: FutureBuilder<_ReportData>(
        future: _loadReportData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Failed to load reports: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly Report (Last 7 Days)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CaretakerColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildReportCard(
                  title: 'Safe Zone Exits',
                  value: '${data.safeZoneExitsWeek}',
                  subtitle: 'Number of times exited the safe zone',
                ),
                const SizedBox(height: 8),
                _buildReportCard(
                  title: 'SOS Triggered',
                  value: '${data.sosTriggeredWeek}',
                  subtitle: 'Number of SOS trigger events',
                ),
                const SizedBox(height: 8),
                _buildReportCard(
                  title: 'SOS False Alarms',
                  value: '${data.sosFalseAlarmWeek}',
                  subtitle: 'Number of false alarm logs',
                ),
                if (data.safeZoneExitsByDay.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Daily Safe Zone Exits',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...data.safeZoneExitsByDay.entries.map(
                    (e) => Text('${e.key}: ${e.value}'),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Yearly Report (Last 12 Months)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CaretakerColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildReportCard(
                  title: 'Safe Zone Exits',
                  value: '${data.safeZoneExitsYear}',
                  subtitle: 'Total exits in last 12 months',
                ),
                const SizedBox(height: 8),
                _buildReportCard(
                  title: 'SOS Triggered',
                  value: '${data.sosTriggeredYear}',
                  subtitle: 'Total SOS trigger events in last 12 months',
                ),
                const SizedBox(height: 8),
                _buildReportCard(
                  title: 'SOS False Alarms',
                  value: '${data.sosFalseAlarmYear}',
                  subtitle: 'Total false alarm logs in last 12 months',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ReportData {
  final int safeZoneExitsWeek;
  final int safeZoneExitsYear;
  final Map<String, int> safeZoneExitsByDay;
  final int sosTriggeredWeek;
  final int sosTriggeredYear;
  final int sosFalseAlarmWeek;
  final int sosFalseAlarmYear;

  _ReportData({
    required this.safeZoneExitsWeek,
    required this.safeZoneExitsYear,
    required this.safeZoneExitsByDay,
    required this.sosTriggeredWeek,
    required this.sosTriggeredYear,
    required this.sosFalseAlarmWeek,
    required this.sosFalseAlarmYear,
  });
}
