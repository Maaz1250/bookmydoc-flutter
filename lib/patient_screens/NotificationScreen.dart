import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Required for time parsing

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch next available slot (excluding past same-day slots)
  Future<Map<String, dynamic>?> _getNextAvailableSlot(
      String doctorId, String currentDate, String currentTime) async {
    QuerySnapshot snapshot = await _firestore
        .collection("appointments")
        .where("doctorId", isEqualTo: doctorId)
        .where("slots", isGreaterThan: 0) // Only available slots
        .where("date", isGreaterThanOrEqualTo: currentDate) // Same or future dates only
        .orderBy("date", descending: false) // Earliest dates first
        .get();

    print("Total slots fetched: ${snapshot.docs.length}");

    if (snapshot.docs.isNotEmpty) {
      // Loop through each slot
      for (var doc in snapshot.docs) {
        Map<String, dynamic> slot = doc.data() as Map<String, dynamic>;
        // Save the document ID for later update
        slot["id"] = doc.id;
        
        String slotDate = slot["date"];
        String slotTime = slot["time"];

        print("Checking slot - Date: $slotDate, Time: $slotTime");

        // If the slot is on the same day, compare times
        if (slotDate == currentDate) {
          try {
            DateFormat timeFormat = DateFormat("hh:mm a");
            DateTime currentTimeParsed = timeFormat.parse(currentTime);
            DateTime slotTimeParsed = timeFormat.parse(slotTime);

            print("Parsed current time: $currentTimeParsed, slot time: $slotTimeParsed");

            // Only accept future time slots on the same day
            if (slotTimeParsed.isAfter(currentTimeParsed)) {
              print("Returning same-day future slot: $slot");
              return slot;
            }
          } catch (e) {
            print("Time parsing error: $e");
            // If error in parsing, consider the slot as invalid for safety
          }
        } else {
          // For a future day, just return the slot
          print("Returning future day slot: $slot");
          return slot;
        }
      }
    }
    print("No valid slot found.");
    return null; // No valid slots found
  }

  // Reschedule appointment
  void _rescheduleAppointment(String appointmentId, String doctorId, String currentDate, String currentTime) async {
    Map<String, dynamic>? availableSlot = await _getNextAvailableSlot(doctorId, currentDate, currentTime);

    if (availableSlot != null) {
      String newDate = availableSlot["date"];
      String newTime = availableSlot["time"];
      String slotId = availableSlot["id"]; // Use the proper document ID

      // Update the booked appointment with the new schedule
      await _firestore.collection("booked_appointments").doc(appointmentId).update({
        "date": newDate,
        "time": newTime,
        "status": "rescheduled",
        "reschedulePending": false,
      });

      // Reduce the slot count by 1 in the correct slot document
      await _firestore.collection("appointments").doc(slotId).update({
        "slots": availableSlot["slots"] - 1,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Appointment rescheduled to $newDate | $newTime")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No valid available slots for rescheduling.")),
      );
    }
  }

  // Cancel appointment
  void _cancelAppointment(String appointmentId) async {
    await _firestore.collection("booked_appointments").doc(appointmentId).update({
      "status": "canceled",
      "reschedulePending": false,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Appointment canceled")),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Reschedule Requests"),
        backgroundColor: Colors.indigo,
      ),
      body: user == null
          ? Center(child: Text("Please log in to view reschedule requests."))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection("booked_appointments")
                  .where("patientId", isEqualTo: user.uid)
                  .where("reschedulePending", isEqualTo: true)
                  .orderBy("date", descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No reschedule requests."));
                }

                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    Map<String, dynamic> appointment = doc.data() as Map<String, dynamic>;
                    String appointmentId = doc.id;
                    String doctorId = appointment["doctorId"];
                    String doctorName = appointment["doctorName"];
                    String currentDate = appointment["date"];
                    String currentTime = appointment["time"];

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _getNextAvailableSlot(doctorId, currentDate, currentTime),
                      builder: (context, futureSnapshot) {
                        if (futureSnapshot.connectionState == ConnectionState.waiting) {
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              title: Text("Reschedule with Dr. $doctorName"),
                              subtitle: Text("Current: $currentDate | $currentTime"),
                              trailing: CircularProgressIndicator(),
                            ),
                          );
                        }

                        Map<String, dynamic>? nextSlot = futureSnapshot.data;

                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ListTile(
                            title: Text("Reschedule with Dr. $doctorName"),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Current: $currentDate | $currentTime"),
                                nextSlot != null
                                    ? Text(
                                        "New: ${nextSlot["date"]} | ${nextSlot["time"]}",
                                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                      )
                                    : Text(
                                        "No valid available slots for rescheduling",
                                        style: TextStyle(color: Colors.red),
                                      ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (nextSlot != null)
                                  ElevatedButton(
                                    onPressed: () => _rescheduleAppointment(appointmentId, doctorId, currentDate, currentTime),
                                    child: Text("Accept"),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  ),
                                SizedBox(width: 5),
                                ElevatedButton(
                                  onPressed: () => _cancelAppointment(appointmentId),
                                  child: Text("Cancel"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
    );
  }
}
