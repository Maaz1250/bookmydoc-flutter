import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LeaveRequestScreen extends StatefulWidget {
  @override
  _LeaveRequestScreenState createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime? _leaveStartDate;
  DateTime? _leaveEndDate;
  String? _comments;

  // Current user's details
  String _userName = "Loading...";
  String _userEmail = "Loading...";

  // Date format for displaying the dates
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserInfo();
  }

  // Fetch current user's details from Firestore
  Future<void> _fetchCurrentUserInfo() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection("users").doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _userName = userDoc['fullname'] ?? "Unknown";
          _userEmail = userDoc['email'] ?? "No Email";
        });
      }
    }
  }

  // Function to pick start date
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _leaveStartDate ?? now,
      firstDate: now,  // Prevent selecting past dates
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && pickedDate != _leaveStartDate) {
      setState(() {
        _leaveStartDate = pickedDate;
      });
    }
  }

  // Function to pick end date
Future<void> _selectEndDate(BuildContext context) async {
  // If _leaveStartDate is null, default to today
  final DateTime startDate = _leaveStartDate ?? DateTime.now();

  // Ensure end date is after the start date
  final DateTime? pickedDate = await showDatePicker(
    context: context,
    initialDate: _leaveEndDate ?? startDate, // Default to start date if not selected
    firstDate: startDate, // Ensure end date is not before start date
    lastDate: DateTime(2101),
  );

  if (pickedDate != null && pickedDate != _leaveEndDate) {
    setState(() {
      _leaveEndDate = pickedDate;
    });
  }
}

  // Function to submit leave request
  Future<void> _submitLeaveRequest() async {
    if (_leaveStartDate == null || _leaveEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select both start and end date')),
      );
      return;
    }

    if (_leaveEndDate!.isBefore(_leaveStartDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('End date cannot be earlier than start date')),
      );
      return;
    }

    try {
      await _firestore.collection('staff_leaves').add({
        'staffId': _auth.currentUser?.uid,  // Use current user's UID
        'leaveStartDate': Timestamp.fromDate(_leaveStartDate!),
        'leaveEndDate': Timestamp.fromDate(_leaveEndDate!),
        'status': 'pending',
        'comments': _comments ?? '', // Optional comments
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave request submitted successfully')),
      );

      // Reset form fields after submission
      setState(() {
        _leaveStartDate = null;
        _leaveEndDate = null;
        _comments = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting leave request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Request Leave'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display current user info
            Text('Welcome, $_userName', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Email: $_userEmail', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            SizedBox(height: 16),

            // Leave start date picker
            Text('Start Date:', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            InkWell(
              onTap: () => _selectStartDate(context),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  _leaveStartDate != null
                      ? _dateFormat.format(_leaveStartDate!)
                      : 'Select start date',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
            ),
            SizedBox(height: 16),

            // Leave end date picker
            Text('End Date:', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            InkWell(
              onTap: () => _selectEndDate(context),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  _leaveEndDate != null
                      ? _dateFormat.format(_leaveEndDate!)
                      : 'Select end date',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
            ),
            SizedBox(height: 16),

            // Comments (optional)
            Text('Comments (optional):', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            TextField(
              onChanged: (value) {
                setState(() {
                  _comments = value;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter comments (optional)',
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),

            // Submit button
            Center(
              child: ElevatedButton(
                onPressed: _submitLeaveRequest,
                child: Text('Submit Leave Request'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15), backgroundColor: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
