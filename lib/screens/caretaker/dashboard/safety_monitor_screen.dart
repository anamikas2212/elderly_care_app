
import 'package:flutter/material.dart';
import '../../../theme/caretaker_theme.dart';

class SafetyMonitorScreen extends StatelessWidget {
  const SafetyMonitorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        title: const Text('Safety Monitor', style: CaretakerTextStyles.header),
        backgroundColor: CaretakerColors.cardWhite,
        iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: CaretakerLayout.screenPadding,
        child: Column(
          children: [
            _buildSosPanel(),
            const SizedBox(height: 20),
            _buildStatusCard(),
            const SizedBox(height: 20),
            _buildSosLogsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSosPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: CaretakerColors.errorRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: CaretakerColors.errorRed.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.phone_in_talk, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'Emergency Call',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: CaretakerColors.errorRed),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap above to immediately call emergency contacts',
            style: CaretakerTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.lightGreen,
        borderRadius: CaretakerLayout.cardRadius,
        border: Border.all(color: CaretakerColors.primaryGreen.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.check_circle, color: CaretakerColors.successGreen, size: 30),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All Clear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: CaretakerColors.primaryGreen)),
                  Text('No active alerts', style: TextStyle(color: CaretakerColors.primaryGreen)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: CaretakerColors.successGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Safe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSosLogsList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SOS Logs', style: CaretakerTextStyles.sectionTitle),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          // Removed Fall Detected as requested
          _buildLogItem('Manual SOS', 'Oct 24, 10:30 AM', 'Resolved', Colors.orange),
          const Divider(height: 24),
          _buildLogItem('False Alarm', 'Oct 20, 2:00 PM', 'Resolved', Colors.grey),
        ],
      ),
    );
  }

  Widget _buildLogItem(String title, String time, String status, Color iconColor) {
    return Row(
      children: [
        Icon(Icons.history, color: iconColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(time, style: CaretakerTextStyles.caption),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: CaretakerColors.dividerGrey,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            status,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CaretakerColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
