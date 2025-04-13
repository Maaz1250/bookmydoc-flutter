import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:myapplication/admin_screens/add_doctor_screen.dart';
import 'package:myapplication/admin_screens/add_staff_screen.dart';
import 'package:myapplication/admin_screens/manage_appoitments.dart';
import 'package:myapplication/admin_screens/manage_doctors.dart';
import 'package:myapplication/admin_screens/manage_staff.dart';
import 'package:myapplication/admin_screens/manage_staff_leave.dart';
import 'package:myapplication/screens/login_screen.dart';
import 'package:myapplication/admin_screens/manage_postedappointments_screen.dart';
import 'package:myapplication/admin_screens/manage_patients.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => LoginScreen())
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatisticsSection(context),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  // _buildMenuCard(
                  //   context,
                  //   icon: LucideIcons.userPlus,
                  //   label: 'Add Doctor',
                  //   onTap: () => _navigate(context, AddDoctorScreen()),
                  // ),
                  // _buildMenuCard(
                  //   context,
                  //   icon: LucideIcons.userPlus,
                  //   label: 'Manage Doctor',
                  //   onTap: () => _navigate(context, ManageDoctorsScreen()),
                  // ),
                  _buildMenuCard(
                    context,
                    icon: LucideIcons.userPlus,
                    label: 'Add Staff',
                    onTap: () => _navigate(context, AddStaffScreen()),
                  ),
                  _buildMenuCard(
                    context,
                    icon: LucideIcons.users,
                    label: 'Manage Staff',
                    onTap: () => _navigate(context, ManageStaffScreen()),
                  ),
                  _buildMenuCard(
                    context,
                    icon: LucideIcons.users,
                    label: 'Manage patients',
                    onTap: () => _navigate(context, ManagePatientsScreen()),
                  ),
                  _buildMenuCard(
                    context,
                    icon: LucideIcons.calendarClock,
                    label: 'Booked Appointments',
                    onTap: () => _navigate(context, ViewAppointmentsScreen()),
                  ),
                  _buildMenuCard(
                    context,
                    icon: LucideIcons.calendarPlus,
                    label: 'Posted Appointments',
                    onTap: () => _navigate(context, ManagePostedAppointmentsScreen()),
                  ),
                  _buildMenuCard(
                    context,
                    icon: LucideIcons.checkSquare,
                    label: 'Staff Leaves',
                    onTap: () => _navigate(context, ManageStaffLeaveScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Debug print to verify tap
          print("Navigating from card: $label");
          onTap();
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard(
          context, 
          "Doctors", 
          "doctors", 
          LucideIcons.stethoscope, 
          Colors.blue
        ),
        _buildStatCard(
          context, 
          "Patients", 
          "patients", 
          LucideIcons.user, 
          Colors.green
        ),
        _buildStatCard(
          context, 
          "Staff", 
          "staff", 
          LucideIcons.briefcase, 
          Colors.purple
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String collection,
    IconData icon,
    Color color,
  ) {
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Card(
          color: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
          child: Container(
            padding: const EdgeInsets.all(12),
            width: 100,
            child: Column(
              children: [
                Icon(icon, size: 30, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
