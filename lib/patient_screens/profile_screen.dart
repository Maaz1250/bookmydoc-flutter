import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myapplication/dashboards/patient_dashboard.dart';
import 'package:myapplication/patient_screens/book_appointment_screen.dart';
import 'package:myapplication/patient_screens/update_password_screen.dart';
import 'package:myapplication/patient_screens/view_appointments_screen.dart';
import 'package:myapplication/screens/update_profile_screen.dart';

class MyProfileScreen extends StatefulWidget {
  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  String? _profileImageUrl;  // Variable to store profile image URL
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    if (_user != null) {
      _fetchUserProfileImage();  // Fetch profile image URL from Firestore
    }
  }

  // Fetch user's profile image from Firestore
  Future<void> _fetchUserProfileImage() async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('patients') // Ensure the collection name is correct
          .doc(_user!.uid) // Use UID to fetch the specific user document
          .get();

      if (userDoc.exists) {
        setState(() {
          _profileImageUrl = userDoc['profileImage'];  // Get the profile image URL
        });
      }
    } catch (e) {
      print("Error fetching user profile image: $e");
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PatientDashboard()),
      );
    } else if (index == 1) {
      if (_user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("You need to log in to view appointments"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AppointmentBookingScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, "/login");
  }

  Widget _buildActionButton(String title, IconData icon, VoidCallback onPressed,
      {Color? color}) {
    final isLogout = title.toLowerCase().contains('logout');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ElevatedButton.icon(
        icon: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isLogout ? Colors.red : Colors.indigo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 4,
          shadowColor: Colors.black26,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _user == null
          ? Center(
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, "/login"),
                child: Text("Click here to Login"),
              ),
            )
          : Stack(
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo, Colors.blueAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      SizedBox(height: 20),
                      Center(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundImage: _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!) // Use Firestore profileImage URL
                              : AssetImage("assets/default_profile.png")
                                  as ImageProvider,
                        ),
                      ),
                      SizedBox(height: 16),
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        color: Colors.grey.shade200,
                        margin: EdgeInsets.symmetric(horizontal: 24),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 20),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.indigo,
                                child: Text(
                                  _user?.displayName != null
                                      ? _user!.displayName![0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Hi ${_user?.displayName?.split(' ').first ?? 'there'} 👋",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo[700],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Have a great day ahead!",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 6,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    "Account Settings",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  _buildActionButton("Update Profile", Icons.edit, () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UpdateProfileScreen(
                                          role: 'patient',
                                          uid: _user!.uid,
                                        ),
                                      ),
                                    ).then((_) async {
                                      await _user!.reload();
                                      setState(() {
                                        _user = _auth.currentUser;
                                      });
                                    });
                                  }),
                                  _buildActionButton("Update Password", Icons.lock, () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              UpdatePasswordScreen()),
                                    );
                                  }),
                                  _buildActionButton("View Appointments",
                                      Icons.calendar_today, () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              AppointmentsScreen()),
                                    );
                                  }),
                                  Divider(height: 32),
                                  _buildActionButton("Logout", Icons.logout, _logout,
                                      color: Colors.red),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.schedule), label: 'Appointments'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
