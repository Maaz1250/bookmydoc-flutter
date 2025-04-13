import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StatisticsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Detailed Statistics"),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatCard("Total Doctors", "doctors", Icons.local_hospital, Colors.blue),
            _buildStatCard("Total Patients", "patients", Icons.people, Colors.green),
            _buildStatCard("Total Staff", "staff", Icons.work, Colors.purple),
            _buildStatCard("Total Appointments", "appointments", Icons.calendar_today, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String collection, IconData icon, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Card(
          margin: EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          child: ListTile(
            leading: Icon(icon, size: 40, color: color),
            title: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            trailing: Text("$count", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ),
        );
      },
    );
  }
}
