// lib/screens/caretaker/dashboard/safety_monitor_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/sos_service.dart';
import '../../../theme/caretaker_theme.dart';

class SafetyMonitorScreen extends StatefulWidget {
  const SafetyMonitorScreen({super.key});

  @override
  State<SafetyMonitorScreen> createState() => _SafetyMonitorScreenState();
}

class _SafetyMonitorScreenState extends State<SafetyMonitorScreen> {
  final SOSService _sosService = SOSService();
  String elderlyUserId = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadElderlyUserId();
  }

  Future<void> _loadElderlyUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('elderly_user_uid') ??
          prefs.getString('elderly_user_id') ??
          prefs.getString('elderly_user_name') ??
          '';

      if (!mounted) return;
      setState(() {
        elderlyUserId = uid;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acknowledgeSOS(String alertId) async {
    try {
      await _sosService.acknowledgeSOS(alertId, 'caretaker_id');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS alert acknowledged'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resolveSOS(String alertId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve SOS Alert'),
        content: const Text('Are you sure the emergency has been resolved?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Resolve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _sosService.resolveSOS(alertId, 'caretaker_id');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS alert resolved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (elderlyUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Safety Monitor')),
        body: const Center(
          child: Text('No elderly user linked'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        backgroundColor: CaretakerColors.background,
        elevation: 0,
        title: const Text(
          'Safety Monitor',
          style: TextStyle(color: CaretakerColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active SOS Alerts
            const Text(
              'Active Alerts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CaretakerColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildActiveAlertsSection(),
            const SizedBox(height: 24),

            // SOS Logs
            const Text(
              'SOS History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CaretakerColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildSOSLogsSection(),
          ],
        ),
      ),
    );
  }

  // FIXED: Active Alerts - No more blinking!
  Widget _buildActiveAlertsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _sosService.getActiveSOSAlerts(elderlyUserId),
      builder: (context, snapshot) {
        // Show loading ONLY on first load
        if (snapshot.connectionState == ConnectionState.waiting && 
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Handle errors gracefully
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Error loading alerts: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        // No active alerts
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                Icon(Icons.check_circle, size: 48, color: Colors.green),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'All Clear',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'No active emergencies',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Cache the docs to prevent flickering
        final activeDocs = snapshot.data!.docs;

        // Display active alerts
        return Column(
          children: activeDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final alertId = doc.id;
            return _buildAlertCard(alertId, data);
          }).toList(),
        );
      },
    );
  }

  // FIXED: Extract alert card to prevent rebuilds
  Widget _buildAlertCard(String alertId, Map<String, dynamic> data) {
    final elderlyName = data['elderlyUserName'] ?? 'Unknown';
    final status = data['status'] ?? 'active';
    final triggeredAt = (data['triggeredAt'] as Timestamp?)?.toDate();
    final location = data['location'] as Map<String, dynamic>?;
    final isInsideSafeZone = data['isInsideSafeZone'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 32, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EMERGENCY ALERT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      elderlyName,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status == 'acknowledged' ? Colors.orange : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (triggeredAt != null)
            Text(
              'Triggered: ${_formatDateTime(triggeredAt)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          const SizedBox(height: 4),
          Text(
            'Location: ${isInsideSafeZone ? "Home" : "Away from Home"}',
            style: TextStyle(
              color: isInsideSafeZone ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (location != null) ...[
            const SizedBox(height: 4),
            Text(
              'GPS: ${location['latitude']?.toStringAsFixed(4)}, ${location['longitude']?.toStringAsFixed(4)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (status == 'active')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acknowledgeSOS(alertId),
                    icon: const Icon(Icons.check),
                    label: const Text('Acknowledge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
              if (status == 'active') const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _resolveSOS(alertId),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Resolve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSOSLogsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _sosService.getSOSLogs(elderlyUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && 
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Error loading history: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('No SOS history'),
            ),
          );
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final action = data['action'] ?? 'unknown';
            final timestamp = data['triggeredAt'] as Timestamp?;
            final location = data['location'] as Map<String, dynamic>?;

            IconData icon;
            Color color;
            String actionText;

            switch (action) {
              case 'triggered':
                icon = Icons.warning;
                color = Colors.red;
                actionText = 'SOS Triggered';
                break;
              case 'acknowledged':
                icon = Icons.check;
                color = Colors.orange;
                actionText = 'Acknowledged';
                break;
              case 'resolved':
                icon = Icons.check_circle;
                color = Colors.green;
                actionText = 'Resolved';
                break;
              case 'false_alarm':
                icon = Icons.cancel;
                color = Colors.grey;
                actionText = 'False Alarm';
                break;
              default:
                icon = Icons.info;
                color = Colors.grey;
                actionText = action;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (timestamp != null)
                          Text(
                            _formatDateTime(timestamp.toDate()),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        if (location != null)
                          Text(
                            'Lat: ${location['latitude']?.toStringAsFixed(4)}, Lng: ${location['longitude']?.toStringAsFixed(4)}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}