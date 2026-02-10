import 'package:flutter/material.dart';
import '../../../theme/caretaker_theme.dart';

class MedicationScreen extends StatelessWidget {
  const MedicationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        title: const Text('Medication', style: CaretakerTextStyles.header),
        backgroundColor: CaretakerColors.cardWhite,
        iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: CaretakerLayout.screenPadding,
        child: Column(
          children: [
            _buildProgressCard(),
            const SizedBox(height: 20),
            _buildMissedAlertCard(),
            const SizedBox(height: 20),
            _buildMedsList(),
            const SizedBox(height: 20),
            _buildWeeklyChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Today\'s Progress', style: CaretakerTextStyles.cardTitle),
              Text(
                '3 of 5 taken',
                style: TextStyle(
                  color: CaretakerColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: 0.6,
            backgroundColor: CaretakerColors.dividerGrey,
            color: CaretakerColors.primaryGreen,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }

  Widget _buildMissedAlertCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE), // Light Red
        borderRadius: CaretakerLayout.cardRadius,
        border: Border.all(color: CaretakerColors.errorRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: CaretakerColors.errorRed, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Missed Dose: Atorvastatin',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: CaretakerColors.errorRed,
                  ),
                ),
                Text(
                  'Overdue by 2 hours',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: CaretakerColors.errorRed,
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

  Widget _buildMedsList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Schedule',
            style: CaretakerTextStyles.sectionTitle,
          ),
          const SizedBox(height: 16),
          _buildMedItem('Aspirin 81mg', '8:00 AM', true, false),
          const Divider(),
          _buildMedItem('Vitamin D', '9:00 AM', true, false),
          const Divider(),
          _buildMedItem('Atorvastatin', '1:00 PM', false, true), // Missed
          const Divider(),
          _buildMedItem('Metformin', '6:00 PM', false, false),
        ],
      ),
    );
  }

  Widget _buildMedItem(String name, String time, bool taken, bool missed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            taken
                ? Icons.check_circle
                : (missed ? Icons.cancel : Icons.circle_outlined),
            color:
                taken
                    ? CaretakerColors.successGreen
                    : (missed ? CaretakerColors.errorRed : Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(time, style: CaretakerTextStyles.caption),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  taken
                      ? CaretakerColors.lightGreen
                      : (missed ? Colors.red.shade50 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              taken ? 'Taken' : (missed ? 'Overdue' : 'Upcoming'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color:
                    taken
                        ? CaretakerColors.successGreen
                        : (missed ? CaretakerColors.errorRed : Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Adherence',
            style: CaretakerTextStyles.sectionTitle,
          ),
          const SizedBox(height: 8),
          const Text(
            'Weekly Average: 87%',
            style: TextStyle(
              color: CaretakerColors.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar('Mon', 0.9),
              _buildBar('Tue', 1.0),
              _buildBar('Wed', 0.8),
              _buildBar('Thu', 0.85),
              _buildBar('Fri', 0.6, isLow: true), // Today
              _buildBar('Sat', 0.0, isEmpty: true),
              _buildBar('Sun', 0.0, isEmpty: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(
    String day,
    double heightPct, {
    bool isLow = false,
    bool isEmpty = false,
  }) {
    return Column(
      children: [
        Container(
          height: 100 * heightPct,
          width: 12,
          decoration: BoxDecoration(
            color:
                isEmpty
                    ? Colors.grey.shade200
                    : (isLow
                        ? CaretakerColors.warningAmber
                        : CaretakerColors.primaryGreen),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
