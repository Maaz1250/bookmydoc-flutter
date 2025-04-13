// ignore_for_file: unused_import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:myapplication/staff_screens/staff_update_password.dart';
import 'package:myapplication/screens/login_screen.dart';
import 'package:myapplication/staff_screens/request_leave_screen.dart';
import 'package:myapplication/staff_screens/staff_manage_profile.dart';
import 'dart:math';
import 'package:myapplication/staff_screens/view_appointments.dart';
import 'package:myapplication/staff_screens/view_leave_screen.dart';
import 'package:myapplication/staff_screens/view_posted_appointments.dart';
import 'package:myapplication/staff_screens/manage_patients.dart';

class StaffDashboard extends StatefulWidget {
  @override
  _StaffDashboardState createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  String _fullname = "Loading...";
  String _profilePhotoUrl = "";
  
  // Appointment status counts
  int confirmedCount = 0;
  int pendingCount = 0;
  int rejectedCount = 0;

  // Attendance status counts
  int attendedCount = 0;
  int notAttendedCount = 0;

  // Clinic status
  bool isClinicOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchAppointmentStats();
    _fetchClinicStatus(); // Add this
  }

  void _fetchClinicStatus() async {
  DocumentSnapshot doc = await FirebaseFirestore.instance.collection("clinic").doc("status").get();
  if (doc.exists && doc["isOpen"] != null) {
    setState(() {
      isClinicOpen = doc["isOpen"];
    });
  }
}


  void _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _fullname = userDoc["fullname"] ?? "No Name";
          _profilePhotoUrl = userDoc["profileImage"] ?? "";
        });
      }
    }
  }

  void _fetchAppointmentStats() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection("booked_appointments").get();

    // Reset counts
    int confirmed = 0, pending = 0, rejected = 0;
    int attended = 0, notAttended = 0;

    for (var doc in snapshot.docs) {
      String status = doc["status"];

      // Count appointment statuses
      if (status == "Confirmed" || status == "accepted" || status == "approved") {
        confirmed++;
      } else if (status == "pending") {
        pending++;
      } else if (status.toLowerCase() == "rejected" || status.toLowerCase() == "cancelled") {
        rejected++;
      }

      // Count attendance statuses only if the field exists
      if (doc.data().toString().contains("attendanceStatus")) {
        String attendanceStatus = doc["attendanceStatus"].toLowerCase();
        if (attendanceStatus == "attended" || attendanceStatus == "Attended") {
          attended++;
        } else if (attendanceStatus == "not attended" || attendanceStatus == "Not Attended") {
          notAttended++;
        }
      }
    }

    setState(() {
      confirmedCount = confirmed;
      pendingCount = pending;
      rejectedCount = rejected;
      attendedCount = attended;
      notAttendedCount = notAttended;
    });
  }

  // Toggle clinic status
  void _toggleClinicStatus() async {
  bool newStatus = !isClinicOpen;

  await FirebaseFirestore.instance.collection("clinic").doc("status").set({
    "isOpen": newStatus,
  });

  setState(() {
    isClinicOpen = newStatus;
  });
}


  /// Logout Function
  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Staff Dashboard"), backgroundColor: Colors.indigo),
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(  
        child: Column(
          children: [
            _buildStatisticsSection(),
            SizedBox(height: 20),
            // Clinic Status Section
            _buildClinicStatusSection(),
            SizedBox(height: 20),
            _buildPieChart("Appointment Status", confirmedCount, pendingCount, rejectedCount, ["Confirmed", "Pending", "Rejected"], [Colors.green, Colors.orange, Colors.red]),
            SizedBox(height: 20),
            _buildAttendancePieChart(),
          ],
        ),
      ),
    );
  }

  /// Clinic Status Section
  Widget _buildClinicStatusSection() {
    return Column(
      children: [
        Text("Clinic Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text(isClinicOpen ? "Clinic is Open" : "Clinic is Closed", 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isClinicOpen ? Colors.green : Colors.red),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: _toggleClinicStatus,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isClinicOpen ? Icons.lock_open : Icons.lock,
                color: Colors.white,
                size: 24, // Adjusted icon size for better balance
              ),
              SizedBox(width: 12), // Increased space between icon and text
              Text(
                isClinicOpen ? "Click to Close Clinic" : "Click to Open Clinic",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text for contrast
                ),
              ),
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isClinicOpen ? Colors.red : Colors.green, // Red for close, Green for open
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24), // Balanced padding for better look
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // More pronounced rounded corners for a modern look
            ),
            elevation: 5, // Slightly higher shadow for a more polished effect
          ),
        ),
      ],
    );
  }

  // Add a new method for the attendance pie chart with two sections
  Widget _buildAttendancePieChart() {
    return Column(
      children: [
        Text("Attendance Status (All Time)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        SizedBox(
          height: 300,
          width: 300,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: attendedCount.toDouble(),
                  color: Colors.blue,
                  title: "$attendedCount",
                  radius: 80,
                  titleStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                PieChartSectionData(
                  value: notAttendedCount.toDouble(),
                  color: Colors.grey,
                  title: "$notAttendedCount",
                  radius: 80,
                  titleStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 50,
            ),
          ),
        ),
        SizedBox(height: 20),
        _buildPieChartLabels(["Attended", "Not Attended"], [Colors.blue, Colors.grey]),
      ],
    );
  }

  /// Staff Options Menu (Drawer)
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.indigo),
            accountName: Text(_fullname, style: TextStyle(fontSize: 18)),
            accountEmail: null,
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: _profilePhotoUrl.isNotEmpty
                  ? NetworkImage(_profilePhotoUrl)
                  : AssetImage("assets/default_profile.png") as ImageProvider,
            ),
          ),
          _buildDrawerItem(Icons.calendar_today, "Manage Booked Appointments", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ViewAppointmentsScreen()));
          }),
          _buildDrawerItem(Icons.event_available, "View Posted Appointments", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ViewPostedAppointmentsScreen()));
          }),
          _buildDrawerItem(Icons.assignment_ind, "Manage Patients", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ManagePatientsScreen()));
          }),
          _buildDrawerItem(Icons.request_page, "Request Leave", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveRequestScreen()));
          }),
          _buildDrawerItem(Icons.view_list, "View Leaves", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ViewLeaveScreen()));
          }),
          _buildDrawerItem(Icons.person, "Manage Profile", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ManageProfile()));
          }),
          _buildDrawerItem(Icons.lock, "Change Password", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => UpdatePasswordScreen()));
          }),
          _buildDrawerItem(Icons.logout, "Logout", () => _logout(context)),
        ],
      ),
    );
  }

  /// Generic Drawer Item Builder
  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo),
      title: Text(title, style: TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }

  /// Statistics Section
  Widget _buildStatisticsSection() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _buildStatCard("Patients", "patients", Icons.people, Colors.green),
      ],
    );
  }

  /// Firestore Statistics Cards
  Widget _buildStatCard(String label, String collection, IconData icon, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          child: Container(
            padding: EdgeInsets.all(16),
            width: 110,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: color),
                SizedBox(height: 8),
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("$count", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Reusable Pie Chart Widget
  Widget _buildPieChart(String title, int count1, int count2, int count3, List<String> labels, List<Color> colors) {
    return Column(
      children: [
        Text("$title (All Time)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        SizedBox(
          height: 300,
          width: 300,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: count1.toDouble(),
                  color: colors[0],
                  title: "$count1",
                  radius: 80,
                  titleStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                PieChartSectionData(
                  value: count2.toDouble(),
                  color: colors[1],
                  title: "$count2",
                  radius: 80,
                  titleStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                PieChartSectionData(
                  value: count3.toDouble(),
                  color: colors[2],
                  title: "$count3",
                  radius: 80,
                  titleStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 50,
            ),
          ),
        ),
        SizedBox(height: 20),
        _buildPieChartLabels(labels, colors),
      ],
    );
  }

  /// Pie Chart Labels
  Widget _buildPieChartLabels(List<String> labels, List<Color> colors) {
    return Column(
      children: List.generate(labels.length, (index) => _buildLegendItem(colors[index], labels[index])),
    );
  }

  /// Pie Chart Legend Item
  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 16, height: 16, color: color),
        SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
