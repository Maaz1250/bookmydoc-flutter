import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagePatientsScreen extends StatefulWidget {
  const ManagePatientsScreen({super.key});

  @override
  State<ManagePatientsScreen> createState() => _ManagePatientsScreenState();
}

class _ManagePatientsScreenState extends State<ManagePatientsScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Patients'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by name or email",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .orderBy('fullname') // 👈 Order by name in ascending order
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No patients available."));
                }

                final filteredPatients = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(searchQuery) || email.contains(searchQuery);
                }).toList();

                if (filteredPatients.isEmpty) {
                  return Center(child: Text("No matching patients found."));
                }

                return ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: filteredPatients.length,
                  itemBuilder: (context, index) {
                    final doc = filteredPatients[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final String name = data['fullname'] ?? 'Unknown';
                    final String email = data['email'] ?? 'No Email';
                    final String contact = data['contactNumber'] ?? 'No Contact';
                    final String address = data['address'] ?? 'No Address';
                    final String status = data['status'] ?? 'active';
                    final String imageUrl = data['profileImage'] ?? ''; // Fetch the image URL

                    // Default image if no imageUrl is provided
                    final String defaultImageUrl = 'assets/default_profile.png';

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundImage: imageUrl.isNotEmpty
                                      ? NetworkImage(imageUrl) // Show patient's image if available
                                      : AssetImage(defaultImageUrl) as ImageProvider, // Default image if no image URL
                                ),
                                SizedBox(width: 8),
                                Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status == 'active' ? Colors.green : Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            _buildDetailRow(Icons.email, email),
                            _buildDetailRow(Icons.phone, contact),
                            _buildDetailRow(Icons.location_on, address),
                            SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: status == 'active' ? Colors.red : Colors.green,
                                ),
                                onPressed: () => _togglePatientStatus(doc.id, status),
                                child: Text(status == 'active' ? "Deactivate" : "Activate"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _togglePatientStatus(String patientId, String currentStatus) async {
    String newStatus = currentStatus == 'active' ? 'inactive' : 'active';

    await FirebaseFirestore.instance.collection('patients').doc(patientId).update({
      'status': newStatus,
    });

    await FirebaseFirestore.instance.collection('users').doc(patientId).update({
      'status': newStatus,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Patient status updated successfully.")),
    );
  }
}
