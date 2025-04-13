import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageStaffScreen extends StatefulWidget {
  const ManageStaffScreen({super.key});

  @override
  State<ManageStaffScreen> createState() => _ManageStaffScreenState();
}

class _ManageStaffScreenState extends State<ManageStaffScreen> {
  bool _loading = true;
  List<DocumentSnapshot> _staffList = [];

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    setState(() {
      _loading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('staff')
          .orderBy('fullname') // Order by name in ascending order
          .get();

      setState(() {
        _staffList = snapshot.docs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error fetching staff data: $e"),
      ));
    }
  }

  void _toggleStaffStatus(String staffId, String currentStatus) async {
    String newStatus = currentStatus == 'active' ? 'inactive' : 'active';

    await FirebaseFirestore.instance.collection('staff').doc(staffId).update({
      'status': newStatus,
    });

    await FirebaseFirestore.instance.collection('users').doc(staffId).update({
      'status': newStatus,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Staff status updated successfully.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Staffs'),
        backgroundColor: Colors.teal,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _staffList.isEmpty
              ? Center(child: Text("No staff available."))
              : ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: _staffList.length,
                  itemBuilder: (context, index) {
                    final doc = _staffList[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final String name = data['fullname'] ?? 'Unknown';
                    final String email = data['email'] ?? 'No Email';
                    final String contact = data['phone'] ?? 'No Contact';
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
                                      ? NetworkImage(imageUrl) // Show staff's image if available
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
                                onPressed: () => _toggleStaffStatus(doc.id, status),
                                child: Text(status == 'active' ? "Deactivate" : "Activate"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
}
