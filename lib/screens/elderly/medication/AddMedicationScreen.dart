import 'package:flutter/material.dart';

class AddMedicationScreen extends StatelessWidget {
  final String userId;

  const AddMedicationScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Medication"),
      ),
      body: Center(
        child: Text("User ID: $userId"),
      ),
    );
  }
}