import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class DoctorDetailsPage extends StatefulWidget {
  final Map<String, dynamic> doctor;

  DoctorDetailsPage({required this.doctor});

  @override
  _DoctorDetailsPageState createState() => _DoctorDetailsPageState();
}

class _DoctorDetailsPageState extends State<DoctorDetailsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  double _rating = 0.0;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _fetchExistingRating();
    _debugDoctorData();
  }

  /// Debugging function to print doctor details
  void _debugDoctorData() {
    print("Doctor Data: ${widget.doctor}");
  }

  /// Fetch user's previous rating for this doctor
  Future<void> _fetchExistingRating() async {
    if (_user == null) return;

    String? doctorId = widget.doctor["id"];
    if (doctorId == null) {
      print("Error: Doctor ID is null");
      return;
    }

    print("Fetching rating for Doctor ID: $doctorId");

    final snapshot = await _firestore
        .collection("doctor_ratings")
        .where("doctorId", isEqualTo: doctorId)
        .where("userId", isEqualTo: _user!.uid)
        .get();

    print("Existing ratings found: ${snapshot.docs.length}");

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _rating = snapshot.docs.first["rating"].toDouble();
      });
    }
  }

  /// Store or update the rating in Firestore
  Future<void> _submitRating() async {
    if (_user == null) return;

    String? doctorId = widget.doctor["id"];
    if (doctorId == null) {
      print("Error: Doctor ID is null");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: Doctor information is missing.")),
      );
      return;
    }

    print("Submitting rating for Doctor ID: $doctorId with rating: $_rating");

    try {
      final ratingRef = _firestore.collection("doctor_ratings");

      final querySnapshot = await ratingRef
          .where("doctorId", isEqualTo: doctorId)
          .where("userId", isEqualTo: _user!.uid)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Update existing rating
        await ratingRef.doc(querySnapshot.docs.first.id).update({"rating": _rating});
        print("Rating updated successfully!");
      } else {
        // Add new rating
        await ratingRef.add({
          "doctorId": doctorId,
          "userId": _user!.uid,
          "rating": _rating,
          "timestamp": FieldValue.serverTimestamp(),
        });
        print("New rating stored successfully!");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Thank you for your feedback!")),
      );
    } catch (e) {
      print("Error storing rating: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit rating. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(widget.doctor["fullName"] ?? "Doctor Details"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Doctor Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundImage: widget.doctor["imageUrl"] != null
                          ? NetworkImage(widget.doctor["imageUrl"])
                          : AssetImage('assets/default_profile.png') as ImageProvider,
                      radius: 50,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Dr. ${widget.doctor["name"] ?? "Unknown Doctor"}",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      "Specialization: ${widget.doctor["specialization"] ?? "No Specialization"}",
                      style: TextStyle(fontSize: 16, color: Colors.blueGrey),
                    ),
                    Divider(thickness: 1, color: Colors.grey[300]),
                    SizedBox(height: 10),
                    _buildInfoRow(Icons.phone, widget.doctor["phone"], "Phone"),
                    _buildInfoRow(Icons.mail, widget.doctor["email"], "Email"),
                    _buildInfoRow(Icons.location_on, widget.doctor["clinic_address"], "Clinic Address"),
                  ],
                ),
              ),
            ),

            SizedBox(height: 30),

            // Feedback Section
            if (_user != null) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        "Rate this Doctor",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      RatingBar.builder(
                        initialRating: _rating,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 40,
                        itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                        itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (rating) {
                          setState(() => _rating = rating);
                        },
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _submitRating,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text("Submit Feedback", style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Helper function to build information rows
  Widget _buildInfoRow(IconData icon, String? value, String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.blueAccent, size: 20),
        SizedBox(width: 5),
        Text(
          value != null && value.isNotEmpty ? value : "Not Available",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
