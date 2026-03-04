
import 'package:flutter/material.dart';
import '../../../theme/caretaker_theme.dart';

class MedicationManagementScreen extends StatefulWidget {
  const MedicationManagementScreen({Key? key}) : super(key: key);

  @override
  State<MedicationManagementScreen> createState() => _MedicationManagementScreenState();
}

class _MedicationManagementScreenState extends State<MedicationManagementScreen> {
  // Mock Data
  List<Map<String, dynamic>> medicines = [
    {'name': 'Aspirin', 'dose': '81mg', 'time': '8:00 AM', 'days': 'Daily'},
    {'name': 'Vitamin D', 'dose': '1000IU', 'time': '9:00 AM', 'days': 'Daily'},
    {'name': 'Atorvastatin', 'dose': '20mg', 'time': '9:00 PM', 'days': 'Mon, Wed, Fri'},
  ];

  void _addMedicine() {
    // Determine context before async gap
    final currentContext = context;
    
    showDialog(
      context: currentContext,
      builder: (BuildContext dialogContext) {
        String name = '';
        String dose = '';
        String time = '';

        return AlertDialog(
          title: const Text('Add New Medicine'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Medicine Name'),
                onChanged: (value) => name = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Dosage (e.g., 500mg)'),
                onChanged: (value) => dose = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Time (e.g., 8:00 AM)'),
                onChanged: (value) => time = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (name.isNotEmpty && dose.isNotEmpty) {
                  setState(() {
                    medicines.add({
                      'name': name,
                      'dose': dose,
                      'time': time.isNotEmpty ? time : 'TBD',
                      'days': 'Daily'
                    });
                  });
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    const SnackBar(content: Text('Medicine Added Successfully')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: CaretakerColors.primaryGreen),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        title: const Text('Manage Medicines', style: CaretakerTextStyles.header),
        backgroundColor: CaretakerColors.cardWhite,
        iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: CaretakerLayout.screenPadding,
        itemCount: medicines.length,
        itemBuilder: (context, index) {
          final med = medicines[index];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CaretakerColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medication, color: CaretakerColors.primaryGreen),
              ),
              title: Text(med['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${med['dose']} • ${med['time']} • ${med['days']}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey),
                onPressed: () {
                   // Edit logic would go here
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit feature coming soon')),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMedicine,
        backgroundColor: CaretakerColors.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Medicine', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
