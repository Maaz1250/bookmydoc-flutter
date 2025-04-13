import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewLeaveScreen extends StatefulWidget {
  @override
  _ViewLeaveScreenState createState() => _ViewLeaveScreenState();
}

class _ViewLeaveScreenState extends State<ViewLeaveScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  // Fetch leave records only for the logged-in staff
  Stream<QuerySnapshot> _fetchLeaveRecords() {
    if (_user != null) {
      return _firestore
          .collection('staff_leaves')
          .where('staffId', isEqualTo: _user!.uid) // Filter by current user ID
          .orderBy('leaveStartDate', descending: true)
          .snapshots();
    }
    return Stream.empty();
  }

  // Format date for display
  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Leave Records'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchLeaveRecords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error fetching leave records'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No leave records found'));
          }

          var leaveRecords = snapshot.data!.docs;

          return ListView.builder(
            itemCount: leaveRecords.length,
            itemBuilder: (context, index) {
              var leave = leaveRecords[index];
              Timestamp startDate = leave['leaveStartDate'];
              Timestamp endDate = leave['leaveEndDate'];
              String status = leave['status'];
              String comments = leave['comments'] ?? 'No comments';

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
                        'Leave Request #${index + 1}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text('Start Date: ${_formatDate(startDate)}'),
                      Text('End Date: ${_formatDate(endDate)}'),
                      SizedBox(height: 8),
                      Text(
                        'Status: $status',
                        style: TextStyle(
                          color: status == 'approved' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Comments: $comments'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
