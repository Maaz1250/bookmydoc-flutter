import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

class ViewAppointmentsScreen extends StatelessWidget {
  void _sendReminder(String patientId, String appointmentId) async {
    // Fetch patient details
    DocumentSnapshot patientDoc = await FirebaseFirestore.instance.collection("patients").doc(patientId).get();

    if (patientDoc.exists) {
      String patientEmail = patientDoc['email'];
      String patientPhone = patientDoc['contactNumber'];
      String patientName = patientDoc['fullname'];

      // Fetch appointment details
      DocumentSnapshot appointmentDoc =
          await FirebaseFirestore.instance.collection("booked_appointments").doc(appointmentId).get();
      if (appointmentDoc.exists) {
        String date = appointmentDoc['date'];
        String time = appointmentDoc['time'];
        String doctorName = appointmentDoc['doctorName'];

        // Send Email & SMS
        _sendEmail(patientEmail, patientName, date, time, doctorName);
        _sendSMS(patientPhone, patientName, date, time, doctorName);
      }
    }
  }

  // Function to send Email using Gmail SMTP
  Future<void> _sendEmail(String email, String patientName, String date, String time, String doctorName) async {
    final smtpServer = gmail("mcaproject2024.25@gmail.com", "awib haqc svwg vacz");

    final message = Message()
      ..from = Address("mcaproject2024.25@gmail.com", "BookMyDoc")
      ..recipients.add(email)
      ..subject = "Appointment Reminder"
      ..text = """
Hello $patientName,

This is a reminder for your upcoming appointment.

Doctor: $doctorName
Date: $date
Time: $time

Please be on time.
Thank you for using BookMyDoc!
""";

    try {
      await send(message, smtpServer);
      print("Email reminder sent successfully");
    } catch (e) {
      print("Failed to send email: $e");
    }
  }

  // Function to send SMS using Twilio API
  void _sendSMS(String phoneNumber, String patientName, String date, String time, String doctorName) async {
    String twilioSID = "ACf3f40f3cc8574097a430f60e084d56cf";
    String twilioAuthToken = "ccb4aaeb26b54522263ed5b44e8edbdf";
    String twilioPhoneNumber = "+1 814 498 4239";

    var url = Uri.parse("https://api.twilio.com/2010-04-01/Accounts/$twilioSID/Messages.json");
    var response = await http.post(
      url,
      headers: {
        "Authorization": "Basic " + base64Encode(utf8.encode("$twilioSID:$twilioAuthToken")),
      },
      body: {
        "From": twilioPhoneNumber,
        "To": phoneNumber,
        "Body": "Hello $patientName, Reminder: Appointment with Dr. $doctorName on $date at $time. - BookMyDoc",
      },
    );

    if (response.statusCode == 201) {
      print("SMS Reminder Sent Successfully");
    } else {
      print("Failed to send SMS: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("All Appointments")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("booked_appointments").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading appointments"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No appointments found"));
          }

          var appointments = snapshot.data!.docs;

          return ListView.builder(
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              var data = appointments[index].data() as Map<String, dynamic>;
              String appointmentId = appointments[index].id;
              String patientId = data['patientId'];
              String doctorName = data['doctorName'];
              String date = data['date'];
              String time = data['time'];

              return Card(
                elevation: 3,
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: Icon(Icons.calendar_today, color: Colors.blue),
                  title: Text("Patient: ${data['patientName']}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Doctor: Dr. $doctorName"),
                      Text("Date: $date | Time: $time"),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.notifications_active, color: Colors.green),
                    onPressed: () => _sendReminder(patientId, appointmentId),
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
