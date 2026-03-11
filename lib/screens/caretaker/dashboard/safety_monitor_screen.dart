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

class _SafetyMonitorScreenState extends State<SafetyMonitorScreen> with WidgetsBindingObserver {
  final SOSService _sosService = SOSService();
  String elderlyUserId = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ✅ ADDED: Listen to app lifecycle
    _loadElderlyUserId();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ✅ ADDED: Remove listener
    super.dispose();
  }

  // ✅ ADDED: Reload elderly user ID when app resumes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed - reloading elderly user ID');
      _loadElderlyUserId();
    }
  }

  Future<void> _loadElderlyUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // ✅ ENHANCED: Try multiple keys and log what we find
      final uid = prefs.getString('elderly_user_uid') ??
          prefs.getString('elderly_user_id') ??
          prefs.getString('elderly_user_name') ??
          prefs.getString('elderlyUserId') ?? // ✅ ADDED: Additional fallback key
          '';

      print('🔍 Loaded elderly user ID: "$uid"');
      print('📦 Available SharedPreferences keys: ${prefs.getKeys()}');

      if (!mounted) return;
      setState(() {
        elderlyUserId = uid;
        _isLoading = false;
      });

      // ✅ ADDED: If empty, try to reload from Firestore
      if (uid.isEmpty) {
        print('⚠️ Elderly user ID is empty - attempting to reload from caretaker data');
        await _tryLoadFromCaretakerData(prefs);
      }
    } catch (e) {
      print('❌ Error loading elderly user ID: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ✅ ADDED: Try to reload elderly user ID from caretaker's Firestore data
  Future<void> _tryLoadFromCaretakerData(SharedPreferences prefs) async {
    try {
      final caretakerId = prefs.getString('caretaker_id') ?? 
                          prefs.getString('caretaker_user_id') ??
                          '';
      
      if (caretakerId.isEmpty) {
        print('⚠️ Caretaker ID also empty');
        return;
      }

      print('🔍 Looking up elderly user from caretaker: $caretakerId');

      // Try to find the linked elderly user from caretaker's data
      final caretakerDoc = await FirebaseFirestore.instance
          .collection('caretakers')
          .doc(caretakerId)
          .get();

      if (caretakerDoc.exists) {
        final linkedElderlyId = caretakerDoc.data()?['linkedElderlyUserId'];
        if (linkedElderlyId != null && linkedElderlyId.toString().isNotEmpty) {
          print('✅ Found linked elderly user: $linkedElderlyId');
          
          // Save it back to SharedPreferences
          await prefs.setString('elderly_user_uid', linkedElderlyId.toString());
          await prefs.setString('elderlyUserId', linkedElderlyId.toString());
          
          if (!mounted) return;
          setState(() {
            elderlyUserId = linkedElderlyId.toString();
          });
        }
      }
    } catch (e) {
      print('❌ Error loading from caretaker data: $e');
    }
  }

  Future<void> _acknowledgeSOS(String alertId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final caretakerId = prefs.getString('caretaker_id') ?? 
                          prefs.getString('caretaker_user_id') ?? 
                          'caretaker_unknown';
      
      await _sosService.acknowledgeSOS(alertId, caretakerId);

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
      final prefs = await SharedPreferences.getInstance();
      final caretakerId = prefs.getString('caretaker_id') ?? 
                          prefs.getString('caretaker_user_id') ?? 
                          'caretaker_unknown';
      
      await _sosService.resolveSOS(alertId, caretakerId);

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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No elderly user linked',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please link an elderly user first',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadElderlyUserId();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
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
        actions: [
          // ✅ ADDED: Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadElderlyUserId();
            },
          ),
        ],
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

  Widget _buildActiveAlertsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _sosService.getActiveSOSAlerts(elderlyUserId),
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
            child: Column(
              children: [
                Text(
                  'Error loading alerts: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _loadElderlyUserId();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

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

        final activeDocs = snapshot.data!.docs;

        return Column(
          children: activeDocs.map((doc) {
            return _buildAlertCard(doc);
          }).toList(),
        );
      },
    );
  }

  Widget _buildAlertCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final alertId = doc.id;
    final elderlyName = data['elderlyUserName'] ?? 'Unknown';
    final status = data['status'] ?? 'active';
    final triggeredAt = (data['triggeredAt'] as Timestamp?)?.toDate();
    final location = data['location'] as Map<String, dynamic>?;
    final isInsideSafeZone = data['isInsideSafeZone'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'acknowledged' ? Colors.orange : Colors.red,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (status == 'acknowledged' ? Colors.orange : Colors.red)
                .withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: status == 'acknowledged' ? Colors.orange : Colors.red,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Column(
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
                ],
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
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