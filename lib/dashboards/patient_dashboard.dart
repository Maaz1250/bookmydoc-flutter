import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myapplication/patient_screens/book_appointment_screen.dart';
import 'package:myapplication/patient_screens/doctor_details_screen.dart';
import 'package:myapplication/patient_screens/profile_screen.dart';
import 'package:myapplication/patient_screens/NotificationScreen.dart';

class PatientDashboard extends StatefulWidget {
  @override
  _PatientDashboardState createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _selectedIndex = 0;
  String _patientName = "Loading...";
  String? _profileImageUrl;
  bool _isLoading = true;
  int _notificationCount = 0;
  String? _clinicStatus;
  bool _isClinicStatusLoading = true; 

  final List<String> _carouselImages = [
    'assets/ex.jpeg',
    'assets/2.jpeg',
    'assets/1.jpeg',
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchPatientDetails();
    _fetchNotificationCount();
    _fetchClinicStatus(); // ← new
  }

  void _fetchClinicStatus() async {
  try {
    DocumentSnapshot doc = await _firestore.collection("clinic").doc("status").get();
    if (doc.exists && doc["isOpen"] != null) {
      setState(() {
        _clinicStatus = doc["isOpen"] ? "Clinic is Open" : "Clinic is Closed";
        _isClinicStatusLoading = false;
      });
    } else {
      setState(() {
        _clinicStatus = "Status Unknown";
        _isClinicStatusLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      _clinicStatus = "Error fetching status";
      _isClinicStatusLoading = false;
    });
    print("Error fetching clinic status: $e");
  }
}

Widget _buildClinicStatusCard() {
  if (_isClinicStatusLoading) {
    return Center(child: CircularProgressIndicator());
  }

  // Determine the status color based on clinic status
  Color statusColor = _clinicStatus == "Clinic is Open"
      ? Colors.green.shade100
      : Colors.red.shade100;

  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 4,
    margin: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    child: Padding(
      padding: const EdgeInsets.all(20.0), // Adjusted padding for a cleaner look
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.indigo,
            size: 30, // Adjusted icon size for better balance
          ),
          SizedBox(width: 16), // Increased space between icon and text
          Expanded(
            child: Text(
              _clinicStatus ?? "Unknown",
              style: TextStyle(
                fontSize: 18, // Slightly larger font for better readability
                fontWeight: FontWeight.w600,
                color: Colors.black87, // Text color for clarity
              ),
              overflow: TextOverflow.ellipsis, // Ensures text doesn't overflow
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(12), // Rounded corners for the status container
            ),
            child: Text(
              _clinicStatus ?? "",
              style: TextStyle(
                color: statusColor == Colors.green.shade100
                    ? Colors.green.shade800
                    : Colors.red.shade800, // Contrasting text color
                fontWeight: FontWeight.bold,
                fontSize: 16, // Adjusted font size for balance
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  void _fetchNotificationCount() {
    User? user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection("booked_appointments")
        .where("patientId", isEqualTo: user.uid)
        .where("reschedulePending", isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _notificationCount = snapshot.docs.length;
      });
    });
  }

  Future<void> _fetchPatientDetails() async {
    User? user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _patientName = "User";
        _isLoading = false;
      });
      return;
    }

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection("patients").doc(user.uid).get();

      if (userDoc.exists) {
        setState(() {
          _patientName = userDoc["fullname"] ?? "No Name";
          _profileImageUrl = userDoc["profileImage"];
          _isLoading = false;
        });
      } else {
        setState(() {
          _patientName = "No Data Found";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _patientName = "Error Loading Data";
        _isLoading = false;
      });
      print("Error fetching patient details: $e");
    }
  }

  void _onItemTapped(int index) {
    User? user = _auth.currentUser;

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MyProfileScreen()),
      );
    } else if (index == 1) {
      if (user == null) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildCustomAppBar(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageCarousel(),
                  _buildClinicStatusCard(), // ← new line
                  SizedBox(height: 20),
                  _buildSectionTitle(Icons.local_hospital, 'Available Doctors'),
                  _buildDoctorsList(),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.black54,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Appointments'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildCustomAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          CircleAvatar(
            backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                ? NetworkImage(_profileImageUrl!)
                : AssetImage('assets/default_profile.png') as ImageProvider,
            radius: 20,
          ),
          SizedBox(width: 10),
          _isLoading
              ? CircularProgressIndicator(color: Colors.black)
              : Text(
                  'Welcome $_patientName',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black),
                ),
          Spacer(),
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications, color: Colors.black),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NotificationsScreen()),
                  );
                },
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    return SizedBox(
      height: 180,
      child: PageView.builder(
        itemCount: _carouselImages.length,
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              _carouselImages[index],
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo),
        SizedBox(width: 8),
        Text(title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDoctorsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("users")
          .where("role", isEqualTo: "doctor")
          .where("status", isEqualTo: "active")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text("No active doctors available",
                  style: TextStyle(fontSize: 16)));
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            Map<String, dynamic> doctor = doc.data() as Map<String, dynamic>;

            return StreamBuilder<double>(
              stream: _fetchAverageRating(doc.id), // ✅ Fixed rating issue
              builder: (context, ratingSnapshot) {
                double averageRating = ratingSnapshot.data ?? 0.0;

                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: doctor["imageUrl"] != null &&
                              doctor["imageUrl"].isNotEmpty
                          ? NetworkImage(doctor["imageUrl"])
                          : AssetImage('assets/default_profile.png') as ImageProvider,
                      radius: 30,
                    ),
                    title: Text(doctor["name"] ?? "Unknown Doctor"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doctor["specialization"] ?? "No Specialization"),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 18),
                            SizedBox(width: 4),
                            Text(averageRating.toStringAsFixed(1)),
                          ],
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.arrow_forward, color: Colors.indigo),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DoctorDetailsPage(
                              doctor: {
                                "id": doc.id,
                                "name": doctor["name"],
                                "specialization": doctor["specialization"],
                                "imageUrl": doctor["imageUrl"],
                                "phone": doctor["phone"],
                                "email": doctor["email"],
                                "clinic_address": doctor["clinic_address"],
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Stream<double> _fetchAverageRating(String doctorId) {
    return _firestore
        .collection("doctor_ratings")
        .where("doctorId", isEqualTo: doctorId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return 0.0;
      }

      double total = 0.0;
      int count = 0;

      for (var doc in snapshot.docs) {
        var ratingData = doc.data();
        if (ratingData.containsKey("rating")) {
          var ratingValue = ratingData["rating"];
          if (ratingValue is num) {
            total += ratingValue.toDouble();
            count++;
          }
        }
      }

      return count > 0 ? total / count : 0.0;
    });
  }
}
