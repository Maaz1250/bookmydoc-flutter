import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ManageStaffLeaveScreen extends StatefulWidget {
  @override
  _ManageStaffLeaveScreenState createState() => _ManageStaffLeaveScreenState();
}

class _ManageStaffLeaveScreenState extends State<ManageStaffLeaveScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch leave requests
  Stream<QuerySnapshot> _getLeaveRequests() {
    return _firestore.collection('staff_leaves').snapshots();
  }

  // Function to update leave request status
  Future<void> _updateLeaveStatus(String docId, String status) async {
    await _firestore.collection('staff_leaves').doc(docId).update({
      'status': status,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Staff Leave"),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getLeaveRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No leave requests found."));
          }

          var leaveRequests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: leaveRequests.length,
            itemBuilder: (context, index) {
              var leave = leaveRequests[index];
              String docId = leave.id;
              String staffId = leave['staffId'];
              String comments = leave['comments'];
              Timestamp startTimestamp = leave['leaveStartDate'];
              Timestamp endTimestamp = leave['leaveEndDate'];
              String status = leave['status'];

              // Format dates
              String startDate = DateFormat('yyyy-MM-dd').format(startTimestamp.toDate());
              String endDate = DateFormat('yyyy-MM-dd').format(endTimestamp.toDate());

              return Card(
                margin: EdgeInsets.all(10),
                child: ListTile(
                  title: Text("Staff ID: $staffId", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Start Date: $startDate"),
                      Text("End Date: $endDate"),
                      Text("Comments: $comments"),
                      Text(
                        "Status: $status",
                        style: TextStyle(
                          color: status == "pending"
                              ? Colors.orange
                              : status == "approved"
                                  ? Colors.green
                                  : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: status == "pending"
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check, color: Colors.green),
                              onPressed: () {
                                _updateLeaveStatus(docId, "approved");
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                _updateLeaveStatus(docId, "rejected");
                              },
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
