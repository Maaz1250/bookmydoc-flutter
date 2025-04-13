import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:myapplication/admin_screens/manage_staff_leave.dart';
import 'package:myapplication/doctor_screens/booked_appointments_screen.dart';
import 'package:myapplication/doctor_screens/edit_doctor_profile.dart';
import 'package:myapplication/doctor_screens/manage_posted_appointments.dart';
import 'package:myapplication/doctor_screens/post_appointment_screen.dart';
import 'package:myapplication/doctor_screens/updatepassword_screen.dart';
import 'package:myapplication/doctor_screens/viewpatient_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  String doctorName = "Doctor";
  String doctorEmail = "";
  String doctorId = "";
  String profileImage =
      "https://www.w3schools.com/howto/img_avatar.png";
  String _selectedFilter = "Past 7 Days";
  int upcomingCount = 0;
  int completedCount = 0;
  bool _isLoadingAppointments = true;
  bool _hasAppointments = true;

  @override
  void initState() {
    super.initState();
    _fetchDoctorData();
  }

  void _fetchDoctorData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          doctorId = user.uid;
          doctorName = doc['name'] ?? "Doctor";
          doctorEmail = doc['email'] ?? "";
          profileImage = doc['imageUrl'] ?? profileImage;
        });
        _fetchAppointments();
      }
    }
  }

  void _fetchAppointments() async {
    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('booked_appointments')
        .where('date', isEqualTo: todayDate)
        .where('doctorId', isEqualTo: doctorId)
        .get();

    int upcoming = 0, completed = 0;

    for (var doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        String status = data['status']?.toLowerCase() ?? '';
        String attendanceStatus = data.containsKey('attendanceStatus')
            ? data['attendanceStatus'].toString().toLowerCase()
            : '';

        if (attendanceStatus == "attended") {
          completed++;
        } else if (status == "confirmed" ||
            status == "accepted" ||
            status == "approved") {
          upcoming++;
        }
      } catch (e) {
        print("Error in document ${doc.id}: $e");
      }
    }

    setState(() {
      upcomingCount = upcoming;
      completedCount = completed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildCustomAppBar(),
      drawer: _buildSidebar(),
      body: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.indigo],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 20),
              _buildCard(
                  Icons.event_available,
                  "Today’s Appointments",
                  "Upcoming: $upcomingCount | Completed: $completedCount"),
              const SizedBox(height: 20),
              _buildBarChart(), // Dual Bar Chart
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return SizedBox(
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/firstpage.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }

  Widget _buildCard(IconData icon, String title, String subtitle) {
    return Card(
      elevation: 5,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  PreferredSizeWidget _buildCustomAppBar() {
    return AppBar(
      title: Row(
        children: [
          CircleAvatar(
              radius: 20, backgroundImage: NetworkImage(profileImage)),
          const SizedBox(width: 10),
          Text(doctorName,
              style:
                  const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.indigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 4,
    );
  }

  Widget _buildSidebar() {
    return Drawer(
      child: Column(
        children: [
          _buildSidebarHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(LucideIcons.plus, "Post Appointment",
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            PostAppointmentScreen()),
                  ).then((_) => _fetchDoctorData());
                }),
                _buildDrawerItem(
                    LucideIcons.calendar, "Manage Posted Appointments",
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            ManagePostedAppointmentsScreen()),
                  );
                }),
                _buildDrawerItem(LucideIcons.clipboard, "Booked Appointments",
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            ViewAppointmentsScreen()),
                  );
                }),
                _buildDrawerItem(LucideIcons.users, "Manage Staff Leaves",
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            ManageStaffLeaveScreen()),
                  ).then((_) => _fetchDoctorData());
                }),
                _buildDrawerItem(LucideIcons.book, "View patients",
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            ViewPatientsScreen()),
                  ).then((_) => _fetchDoctorData());
                }),
                _buildDrawerItem(LucideIcons.user, "Manage Profile",
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            EditDoctorProfileScreen()),
                  ).then((_) => _fetchDoctorData());
                }),
                _buildDrawerItem(LucideIcons.key, "Update Password",
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            UpdatePasswordScreen()),
                  ).then((_) => _fetchDoctorData());
                }),
                _buildDrawerItem(
                    LucideIcons.logOut, "Logout", () {
                  FirebaseAuth.instance.signOut();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                    color: Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.blueAccent,
        borderRadius:
            BorderRadius.only(bottomRight: Radius.circular(40)),
      ),
      child: Row(
        children: [
          CircleAvatar(
              radius: 30, backgroundImage: NetworkImage(profileImage)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 5),
                Text(
                  doctorEmail,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap,
      {Color color = Colors.black}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500, color: color),
      ),
      onTap: onTap,
    );
  }

  /// Dual Bar Chart (Posted + Booked)
  Widget _buildBarChart() {
    return FutureBuilder<List<Map<String, int>>>(
      future: _fetchDualAppointmentData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        List<Map<String, int>> data = snapshot.data!;
        List<String> labels = _generateLabels();

        double maxY = data
                .map((e) => max(e['posted']!, e['booked']!))
                .reduce(max)
                .toDouble() +
            2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Appointments (Next 7 Days)",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Container(
              height: 400,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12, blurRadius: 6)
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        barGroups: List.generate(7, (index) {
                          return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                    toY: data[index]['posted']!
                                        .toDouble(),
                                    color: Colors.orange,
                                    width: 8),
                                BarChartRodData(
                                    toY: data[index]['booked']!
                                        .toDouble(),
                                    color: Colors.indigo,
                                    width: 8),
                              ],
                              barsSpace: 4);
                        }),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                int index = value.toInt();
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      top: 8.0),
                                  child: Text(labels[index],
                                      style:
                                          TextStyle(fontSize: 12)),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: maxY / 5,
                              getTitlesWidget: (value, meta) {
                                return Text("${value.toInt()}",
                                    style:
                                        TextStyle(fontSize: 12));
                              },
                              reservedSize: 40,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                            show: true, drawHorizontalLine: true),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      LegendDot(
                          color: Colors.orange, label: "Posted"),
                      SizedBox(width: 16),
                      LegendDot(
                          color: Colors.indigo, label: "Booked"),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Fetch posted and booked appointments count for next 7 days
  Future<List<Map<String, int>>> _fetchDualAppointmentData() async {
    List<Map<String, int>> result = [];
    DateTime now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      DateTime day = now.add(Duration(days: i));
      String formattedDate =
          DateFormat('yyyy-MM-dd').format(day);

      // Fetch posted appointments for this doctor
      QuerySnapshot postedSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: formattedDate)
          .get();

      // Fetch booked appointments for this doctor
      QuerySnapshot bookedSnapshot = await FirebaseFirestore.instance
          .collection('booked_appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: formattedDate)
          .get();

      result.add({
        "posted": postedSnapshot.docs.length,
        "booked": bookedSnapshot.docs.length,
      });
    }

    return result;
  }

  /// X-Axis Labels
  List<String> _generateLabels() {
    DateTime now = DateTime.now();
    return List.generate(
        7,
        (i) => DateFormat('MM/dd')
            .format(now.add(Duration(days: i))));
  }
}

/// Simple Legend Dot Widget
class LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
