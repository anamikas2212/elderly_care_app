import 'package:flutter/material.dart';
import '../../../theme/caretaker_theme.dart';
import '../../elderly/medication/AddMedicationScreen.dart';

class EnhancedMedicationScreen extends StatefulWidget {
  final String? userId;

  const EnhancedMedicationScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<EnhancedMedicationScreen> createState() =>
      _EnhancedMedicationScreenState();
}

class _EnhancedMedicationScreenState extends State<EnhancedMedicationScreen> {
  // Mock Data - Replace with your actual data source
  List<Map<String, dynamic>> medicines = [
    {
      'name': 'Aspirin',
      'dose': '81mg',
      'time': '8:00 AM',
      'days': 'Daily',
      'taken': true,
      'status': 'taken',
    },
    {
      'name': 'Vitamin D',
      'dose': '1000mg',
      'time': '9:00 AM',
      'days': 'Daily',
      'taken': true,
      'status': 'taken',
    },
    {
      'name': 'Atorvastatin',
      'dose': '20mg',
      'time': '1:00 PM',
      'days': 'Daily',
      'taken': false,
      'status': 'overdue',
    },
    {
      'name': 'Metformin',
      'dose': '500mg',
      'time': '6:00 PM',
      'days': 'Daily',
      'taken': false,
      'status': 'upcoming',
    },
  ];

  int get takenCount => medicines.where((m) => m['taken'] == true).length;
  int get totalCount => medicines.length;
  double get adherencePercentage => 87.0; // Calculate from weekly data

  void _addMedicine() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                AddMedicationScreen(userId: widget.userId ?? 'Unknown'),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        medicines.add({...result, 'taken': false, 'status': 'upcoming'});
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${result['name']} added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _editMedicine(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                AddMedicationScreen(userId: widget.userId ?? 'Unknown'),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        medicines[index] = {
          ...result,
          'taken': medicines[index]['taken'],
          'status': medicines[index]['status'],
        };
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✏️ ${result['name']} updated!'),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _deleteMedicine(int index) {
    final medName = medicines[index]['name'];

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
              onPressed: () {
                setState(() {
                  medicines.removeAt(index);
                });
                Navigator.pop(dialogContext);
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

  void _toggleMedicationTaken(int index) {
    setState(() {
      medicines[index]['taken'] = !medicines[index]['taken'];
      medicines[index]['status'] =
          medicines[index]['taken'] ? 'taken' : 'upcoming';
    });
  }

  @override
  Widget build(BuildContext context) {
    final overdueMed = medicines.firstWhere(
      (m) => m['status'] == 'overdue',
      orElse: () => {},
    );

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
          // Add Medicine Button in AppBar
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Today's Progress
              _buildProgressSection(),

              const SizedBox(height: 24),

              // Missed Dose Alert (if any)
              if (overdueMed.isNotEmpty) _buildMissedDoseAlert(overdueMed),

              if (overdueMed.isNotEmpty) const SizedBox(height: 24),

              // Today's Schedule
              _buildScheduleSection(),

              const SizedBox(height: 32),

              // Weekly Adherence
              _buildWeeklyAdherence(),
            ],
          ),
        ),
      ),
      // Floating Action Button for Quick Add
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

  Widget _buildProgressSection() {
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
              '$takenCount of $totalCount taken',
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
            value: takenCount / totalCount,
            minHeight: 12,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade400),
          ),
        ),
      ],
    );
  }

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
                  'Overdue by 2 hours',
                  style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Handle remind action
            },
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

  Widget _buildScheduleSection() {
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
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: medicines.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildMedicationCard(index);
          },
        ),
      ],
    );
  }

  Widget _buildMedicationCard(int index) {
    final med = medicines[index];
    final bool isTaken = med['taken'] == true;
    final bool isOverdue = med['status'] == 'overdue';
    final bool isUpcoming = med['status'] == 'upcoming';

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

    return GestureDetector(
      onLongPress: () {
        // Show edit/delete options on long press
        _showMedicationOptions(index);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleMedicationTaken(index),
              child: statusIcon,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${med['name']} ${med['dose']}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      decoration: isTaken ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    med['time'],
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  if ((med['doctorName'] as String? ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Prescribed by: ${med['doctorName']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.teal.shade700,
                          fontWeight: FontWeight.w500,
                        ),
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
                  onPressed: () => _editMedicine(index),
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
                  onPressed: () => _deleteMedicine(index),
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
      ),
    );
  }

  void _showMedicationOptions(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
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
                medicines[index]['name'],
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
                  Navigator.pop(context);
                  _editMedicine(index);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red.shade700),
                title: const Text('Delete Medicine'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMedicine(index);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

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
          'Weekly Average: --',
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