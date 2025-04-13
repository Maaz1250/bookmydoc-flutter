import 'package:flutter/material.dart';

class AssignRolesScreen extends StatelessWidget {
  const AssignRolesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Roles'),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: Text(
          "Assign Roles Page",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
