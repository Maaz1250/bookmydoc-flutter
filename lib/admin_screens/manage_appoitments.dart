import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class ViewAppointmentsScreen extends StatefulWidget {
  @override
  _ViewAppointmentsScreenState createState() => _ViewAppointmentsScreenState();
}

class _ViewAppointmentsScreenState extends State<ViewAppointmentsScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  String doctorPhone = "";
  String doctorEmail = "";
  String doctorName = "";
  String appointmentId = "";
  String date = "";
  String time = "";
  String status = "";
  String patientName = "";
  String patientContact = "";
  String emailAddress = "";

  Future<void> _sendReminder(String appointmentId, String patientId) async {
    DocumentSnapshot patientDoc =
        await FirebaseFirestore.instance.collection("patients").doc(patientId).get();

    if (patientDoc.exists) {
      String patientEmail = patientDoc['email'];
      String patientPhone = patientDoc['contactNumber'];
      String patientName = patientDoc['fullname'];
      String patientContact = patientDoc['contactNumber'];

      DocumentSnapshot appointmentDoc =
          await FirebaseFirestore.instance.collection("booked_appointments").doc(appointmentId).get();
      if (appointmentDoc.exists) {
        String date = appointmentDoc['date'];
        String time = appointmentDoc['time'];
        String doctorName = appointmentDoc['doctorName'];

        _sendEmail(patientEmail, patientName, date, time, doctorName);
        _sendSMS(patientPhone, patientName, date, time, doctorName);
      }
    }
  }

  Future<void> _sendEmail(String email, String patientName, String date, String time, String doctorName) async {
    final smtpServer = gmail("bookmydoc512@gmail.com", "jqcu gccz dtyn qfds");

    final message = Message()
      ..from = Address("bookmydoc512@gmail.com", "BookMyDoc")
      ..recipients.add(email)
      ..subject = "Appointment Notification"
      ..text = "Hello $patientName,\n\nYour appointment with Dr. $doctorName on $date at $time has been updated.\n\nThank you for using BookMyDoc!";

    try {
      await send(message, smtpServer);
      print("Email Sent Successfully");
    } catch (e) {
      print("Failed to send email: $e");
    }
  }

  void _sendSMS(String phoneNumber, String patientName, String date, String time, String doctorName) async {
    String twilioSID = "ACf3f40f3cc8574097a430f60e084d56cf";
    String twilioAuthToken = "ccb4aaeb26b54522263ed5b44e8edbdf";
    String twilioPhoneNumber = "+1 814 498 4239";

    String message = "Appointment Update: Your appointment with Dr. $doctorName is on $date at $time. - BookMyDoc";

    var url = Uri.parse("https://api.twilio.com/2010-04-01/Accounts/$twilioSID/Messages.json");
    var response = await http.post(
      url,
      headers: {
        "Authorization": "Basic " + base64Encode(utf8.encode("$twilioSID:$twilioAuthToken")),
      },
      body: {
        "From": twilioPhoneNumber,
        "To": phoneNumber,
        "Body": message,
      },
    );

    if (response.statusCode == 201) {
      print("SMS Sent Successfully");
    } else {
      print("Failed to send SMS: ${response.body}");
    }
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String patientId, String status) async {
    await FirebaseFirestore.instance.collection("booked_appointments").doc(appointmentId).update({
      "status": status,
    });

    _sendReminder(appointmentId, patientId);
  }

  Future<void> _updateAttendanceStatus(String appointmentId, String attendanceStatus) async {
    await FirebaseFirestore.instance.collection("booked_appointments").doc(appointmentId).update({
      "attendanceStatus": attendanceStatus,
    });
  }

   Future<void> _sendEmailReschedule(String email, String patientName, String message) async {
    final smtpServer = gmail("bookmydoc512@gmail.com", "jqcu gccz dtyn qfds");

    final emailMessage = Message()
      ..from = Address("bookmydoc512@gmail.com", "BookMyDoc")
      ..recipients.add(email)
      ..subject = "Appointment Update"
      ..text = "Hello $patientName,\n\n$message\n\nThank you for using BookMyDoc!";

    try {
      await send(emailMessage, smtpServer);
      print("Email Sent Successfully");
    } catch (e) {
      print("Failed to send email: $e");
    }
  }

  void _sendSMSReschedule(String phoneNumber, String message) async {
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
        "Body": message,
      },
    );

    if (response.statusCode == 201) {
      print("SMS Sent Successfully");
    } else {
      print("Failed to send SMS: ${response.body}");
    }
  }

  Future<void> _sendRescheduleNotification(String appointmentId, String patientId) async {
    DocumentSnapshot patientDoc = await FirebaseFirestore.instance.collection("patients").doc(patientId).get();
    if (patientDoc.exists) {
      String patientEmail = patientDoc['email'];
      String patientPhone = patientDoc['contactNumber'];
      String patientName = patientDoc['fullname'];

      _sendEmailReschedule(patientEmail, patientName, "Your appointment has been rescheduled. Please accept or reject it.");
      _sendSMSReschedule(patientPhone, "Your appointment has been rescheduled. Please check the app.");
    }
  }

  Future<void> _rescheduleAppointment(String appointmentId, String patientId) async {
    await FirebaseFirestore.instance.collection("booked_appointments").doc(appointmentId).update({
      "status": "rescheduled",
      "reschedulePending": true, 
    });

    _sendRescheduleNotification(appointmentId, patientId);
  }


Future<void> _generateReceipt(
    String doctorPhone,
    String doctorEmail,
    String doctorName,
    String appointmentId,
    String date,
    String time,
    String status,
    String patientName,
    String patientContact,
    String emailAddress) async {
  final pdf = pw.Document();

  final ByteData logoData = await rootBundle.load('assets/logo.jpg');
  final Uint8List logoBytes = logoData.buffer.asUint8List();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Container(
                height: 80,
                child: pw.Image(pw.MemoryImage(logoBytes)),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Doctor: Dr. $doctorName",
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Phone: $doctorPhone",
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Email: $doctorEmail",
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Address: 123 Health Street, City",
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
          pw.Divider(),
          pw.SizedBox(height: 20),

          pw.Center(
            child: pw.Text("Appointment Receipt",
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),

          pw.SizedBox(height: 20),

          pw.Text("Reference ID: $appointmentId",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text("Date: $date",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text("Time: $time",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text("Status: $status",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text("Patient Name: $patientName",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text("Patient Contact: $patientContact",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text("Patient Email: $emailAddress",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 50),
          pw.SizedBox(height: 50),
          pw.SizedBox(height: 50),
          pw.SizedBox(height: 50),
          pw.SizedBox(height: 50),
          pw.SizedBox(height: 50),
          pw.SizedBox(height: 50),
          pw.SizedBox(height: 30),


          pw.Divider(),

          pw.Center(
            child: pw.Text("Thank you for using BookMyDoc!",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    ),
  );

  final output = await getApplicationDocumentsDirectory();
  final file = File("${output.path}/appointment_receipt.pdf");

  await file.writeAsBytes(await pdf.save());
  OpenFile.open(file.path);
}


  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    DateTime initialDate = isFromDate
        ? _fromDate ?? DateTime.now()
        : (_toDate ?? _fromDate ?? DateTime.now());

    DateTime firstDate = isFromDate ? DateTime(2020) : (_fromDate ?? DateTime(2020));
    DateTime lastDate = DateTime(2030);

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          _toDate = null;
        } else {
          if (picked.isBefore(_fromDate!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("To Date must be greater than or equal to From Date")),
            );
          } else {
            _toDate = picked;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Booked Appointments")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(_fromDate == null ? "Select From Date" : "From: ${_fromDate!.toLocal()}".split(' ')[0]),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _fromDate == null ? null : () => _selectDate(context, false),
                    child: Text(_toDate == null ? "Select To Date" : "To: ${_toDate!.toLocal()}".split(' ')[0]),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: (_fromDate == null || _toDate == null)
                ? Center(child: Text("Please select both dates to view appointments"))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection("booked_appointments").snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("No appointments found"));

                      var appointments = snapshot.data!.docs.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        DateTime appointmentDate = DateTime.parse(data['date']);

                        return appointmentDate.isAfter(_fromDate!.subtract(Duration(days: 1))) &&
                            appointmentDate.isBefore(_toDate!.add(Duration(days: 1)));
                      }).toList();

                      return appointments.isEmpty
                          ? Center(child: Text("No appointments in selected date range"))
                          : ListView.builder(
                              itemCount: appointments.length,
                              itemBuilder: (context, index) {
                                var data = appointments[index].data() as Map<String, dynamic>;
                                String appointmentId = appointments[index].id;
                                String patientId = data['patientId'];
                                String status = data['status'];

                                return Card(
                                  elevation: 3,
                                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                  child: ListTile(
                                    title: Text("Patient: ${data['patientName']}"),
                                    subtitle: Text("Doctor: Dr. ${data['doctorName']} | Date: ${data['date']} | Time: ${data['time']} | Status: ${data['status']} | Attendece Status: ${data['attendanceStatus']}"),
                                    trailing: status == "pending"
    ? PopupMenuButton<String>(
        onSelected: (value) {
          if (value == "Accept") _updateAppointmentStatus(appointmentId, patientId, "accepted");
          if (value == "Reject") _updateAppointmentStatus(appointmentId, patientId, "rejected");
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: "Accept", child: Text("Accept")),
          PopupMenuItem(value: "Reject", child: Text("Reject")),
        ],
      )
    : status == "accepted" || status == "rescheduled"
        ? PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == "Attended") {
                _updateAttendanceStatus(appointmentId, "Attended");
              } else if (value == "Not Attended") {
                _updateAttendanceStatus(appointmentId, "Not Attended");
              } else if (value == "Reminder") {
                _sendReminder(appointmentId, patientId);
              } else if (value == "Generate Receipt") {
                try {
                  DocumentSnapshot appointmentDoc = await FirebaseFirestore.instance
                      .collection("booked_appointments")
                      .doc(appointmentId)
                      .get();

                  if (appointmentDoc.exists) {
                    String doctorName = appointmentDoc['doctorName'] ?? "Unknown";
                    String date = appointmentDoc['date'] ?? "Unknown";
                    String time = appointmentDoc['time'] ?? "Unknown";
                    String status = appointmentDoc['status'] ?? "Unknown";
                    String doctorId = appointmentDoc['doctorId'];

                    DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
                        .collection("doctors")
                        .doc(doctorId)
                        .get();

                    String doctorPhone = doctorDoc.exists ? doctorDoc['phone'] ?? "Unknown" : "Unknown";
                    String doctorEmail = doctorDoc.exists ? doctorDoc['email'] ?? "Unknown" : "Unknown";

                    DocumentSnapshot patientDoc = await FirebaseFirestore.instance
                        .collection("patients")
                        .doc(patientId)
                        .get();

                    if (patientDoc.exists) {
                      String patientName = patientDoc['fullname'] ?? "Unknown";
                      String patientContact = patientDoc['contactNumber'] ?? "Unknown";
                      String emailAddress = patientDoc['email'] ?? "Unknown";

                      _generateReceipt(
                          doctorPhone, doctorEmail, doctorName, appointmentId,
                          date, time, status, patientName, patientContact, emailAddress);
                    }
                  }
                } catch (e) {
                  print("Error fetching details for receipt: $e");
                }
              } else if (value == "Reschedule" || value == "Prioritised Reschedule") {
                _rescheduleAppointment(appointmentId, patientId);
              }
            },
            itemBuilder: (context) {
              List<PopupMenuItem<String>> items = [
                PopupMenuItem(value: "Attended", child: Text("Attended")),
                PopupMenuItem(value: "Not Attended", child: Text("Not Attended")),
                PopupMenuItem(value: "Reminder", child: Text("Reminder")),
                PopupMenuItem(value: "Generate Receipt", child: Text("Generate Receipt")),
              ];

              if (data['attendanceStatus'] == "Attended") {
                items.add(PopupMenuItem(value: "Prioritised Reschedule", child: Text("Prioritised Reschedule")));
              } else {
                items.add(PopupMenuItem(value: "Reschedule", child: Text("Reschedule")));
              }

              return items;
            },
          )
        : null,

                                  ),
                                );
                              },
                            );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
