import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'register_patient.dart'; // Import only patient registration

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register as Patient"),
        backgroundColor: Colors.blue,
      ),
      body: FadeInUp(
        duration: const Duration(milliseconds: 1200),
        child: const RegisterPatient(), // Show only the patient registration
      ),
    );
  }
}
