import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageDoctorsScreen extends StatelessWidget {
  const ManageDoctorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Doctors'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('doctors').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No doctors available."));
          }

          return ListView(
            padding: EdgeInsets.all(12),
            children: snapshot.data!.docs.map((doc) {
              var doctorData = doc.data() as Map<String, dynamic>;
              String doctorId = doc.id;
              String uid = doctorData['uid'] ?? ''; // Fetch UID
              String status = doctorData['status'] ?? 'active'; // Default to active

              bool isActive = status == "active";

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
                child: ListTile(
                  leading: Icon(Icons.person, color: Colors.blue),
                  title: Text(doctorData['email'] ?? 'No Email'),
                  subtitle: Text("Status: ${isActive ? 'Active' : 'Inactive'}"),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? Colors.red : Colors.green,
                    ),
                    onPressed: () => _toggleDoctorStatus(doctorId, uid, isActive, context),
                    child: Text(isActive ? "Deactivate" : "Activate"),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _toggleDoctorStatus(String doctorId, String uid, bool isActive, BuildContext context) async {
    String newStatus = isActive ? "inactive" : "active";

    // Update status in 'doctors' collection
    await FirebaseFirestore.instance.collection('doctors').doc(doctorId).update({
      'status': newStatus,
    });

    // Update status in 'users' collection using UID
    if (uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': newStatus,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Doctor ${newStatus == 'active' ? 'activated' : 'deactivated'} successfully.")),
    );
  }
}
