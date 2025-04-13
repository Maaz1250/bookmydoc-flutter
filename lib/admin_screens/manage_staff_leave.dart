import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageStaffLeaveScreen extends StatefulWidget {
  @override
  _ManageStaffLeaveScreenState createState() => _ManageStaffLeaveScreenState();
}

class _ManageStaffLeaveScreenState extends State<ManageStaffLeaveScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all leave requests from Firestore
  Stream<QuerySnapshot> _fetchLeaveRequests() {
    return _firestore
        .collection('staff_leaves')
        .orderBy('leaveStartDate', descending: true)
        .snapshots();
  }

  // Fetch staff name from 'staff' collection using staffId
  Future<String> _getStaffName(String staffId) async {
    try {
      DocumentSnapshot staffDoc = await _firestore.collection('staff').doc(staffId).get();
      if (staffDoc.exists) {
        return staffDoc['fullname'] ?? 'Unknown';
      }
    } catch (e) {
      print('Error fetching staff name: $e');
    }
    return 'Unknown';
  }

  // Update leave request status (Approve/Reject)
  Future<void> _updateLeaveStatus(String leaveId, String status) async {
    try {
      await _firestore.collection('staff_leaves').doc(leaveId).update({
        'status': status,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave request $status successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  // Get color based on status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Staff Leave'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchLeaveRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No leave requests found'));
          }

          var leaveRequests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: leaveRequests.length,
            itemBuilder: (context, index) {
              var leave = leaveRequests[index];
              String leaveId = leave.id;
              String staffId = leave['staffId'];
              Timestamp startDate = leave['leaveStartDate'];
              Timestamp endDate = leave['leaveEndDate'];
              String reason = leave['comments'] ?? 'No reason provided';
              String status = leave['status'];

              return FutureBuilder<String>(
                future: _getStaffName(staffId),
                builder: (context, nameSnapshot) {
                  if (nameSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  String staffName = nameSnapshot.data ?? 'Unknown';

                  return Card(
                    elevation: 6,
                    margin: EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Staff Name: $staffName',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 5),
                          Text('Start Date: ${startDate.toDate().day}/${startDate.toDate().month}/${startDate.toDate().year}'),
                          Text('End Date: ${endDate.toDate().day}/${endDate.toDate().month}/${endDate.toDate().year}'),
                          SizedBox(height: 8),
                          Text(
                            'Reason: $reason',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Status: $status',
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          if (status == 'pending') // Show buttons only if status is pending
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _updateLeaveStatus(leaveId, 'approved'),
                                  child: Text('Approve'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                ),
                                SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () => _updateLeaveStatus(leaveId, 'rejected'),
                                  child: Text('Reject'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
