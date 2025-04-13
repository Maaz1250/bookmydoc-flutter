import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

class AppointmentsScreen extends StatefulWidget {
  @override
  _AppointmentsScreenState createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  String emailAddress = "", patientName = "", patientContact = "";

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _fetchUserDetails();
    requestStoragePermission();
  }

  Future<void> requestStoragePermission() async {
    await Permission.storage.request();
  }

  Future<void> _fetchUserDetails() async {
    if (_user == null) return;

    DocumentSnapshot userDoc =
        await _firestore.collection('patients').doc(_user!.uid).get();

    if (userDoc.exists) {
      setState(() {
        patientName = userDoc['fullname'] ?? "N/A";
        patientContact = userDoc['contactNumber'] ?? "N/A";
        emailAddress = userDoc['email'] ?? "N/A";
      });
    }
  }

  Future<Map<String, String>> _getDoctorDetails(String doctorId) async {
    try {
      DocumentSnapshot doctorDoc =
          await _firestore.collection('users').doc(doctorId).get();
      if (doctorDoc.exists && doctorDoc.data() != null) {
        return {
          'phone': doctorDoc['phone'] ?? "N/A",
          'email': doctorDoc['email'] ?? "N/A",
        };
      }
    } catch (e) {
      print("Error fetching doctor details: $e");
    }
    return {'phone': "N/A", 'email': "N/A"};
  }

  Future<void> _generateReceipt(
      String doctorPhone,
      String doctorEmail,
      String doctorName,
      String appointmentId,
      String date,
      String time,
      String status) async {
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
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
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
            pw.SizedBox(height: 90),
            pw.Divider(),
            pw.Center(
              child: pw.Text("Thank you for using BookMyDoc!",
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
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

  Future<void> _cancelAppointment(String appointmentId) async {
    bool confirmCancel = await _showCancelConfirmationDialog();
    if (!confirmCancel) return;

    try {
      await _firestore
          .collection('booked_appointments')
          .doc(appointmentId)
          .update({
        'status': 'Cancelled',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Appointment Cancelled Successfully")),
      );
    } catch (e) {
      print("Error cancelling appointment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to cancel appointment")),
      );
    }
  }

  Future<bool> _showCancelConfirmationDialog() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Cancel Appointment"),
            content: Text("Are you sure you want to cancel this appointment?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text("No"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    Text("Yes", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _convertTo12Hour(String time) {
    final format =
        RegExp(r'(\d+):(\d+)\s?(AM|PM)', caseSensitive: false);
    final match = format.firstMatch(time);
    if (match == null) return time;

    int hour = int.parse(match.group(1)!);
    int minute = int.parse(match.group(2)!);
    String period = match.group(3)!.toUpperCase();

    if (period == "PM" && hour != 12) hour += 12;
    if (period == "AM" && hour == 12) hour = 0;

    return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00";
  }

  Stream<QuerySnapshot> _getAppointments() {
  if (_user == null) return Stream.empty();
  return _firestore
      .collection('booked_appointments')
      .where('patientId', isEqualTo: _user!.uid)
      .orderBy("date", descending: true)  // Order by "appointmentDate"
      .snapshots();
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Appointments")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getAppointments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No Appointments Found"));
          }

          var appointments = snapshot.data!.docs;
          DateTime now = DateTime.now();
          DateTime todayDate = DateTime(now.year, now.month, now.day);
          List<QueryDocumentSnapshot> upcomingAppointments = [];
          List<QueryDocumentSnapshot> pastAppointments = [];

          // Split the appointments into upcoming and past based solely on the date.
          for (var doc in appointments) {
            String date = doc['date'];
            String time = doc['time'];
            DateTime appointmentDateTime =
                DateTime.parse("$date ${_convertTo12Hour(time)}");
            DateTime appointmentDate = DateTime(
                appointmentDateTime.year,
                appointmentDateTime.month,
                appointmentDateTime.day);

            if (appointmentDate.isBefore(todayDate)) {
              pastAppointments.add(doc);
            } else {
              upcomingAppointments.add(doc);
            }
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show upcoming (current & future) appointments first.
                if (upcomingAppointments.isNotEmpty)
                  ...upcomingAppointments
                      .map((appointment) => _buildAppointmentCard(appointment))
                      .toList(),
                // Past appointments in an expandable section.
                if (pastAppointments.isNotEmpty)
                  ExpansionTile(
                    title: Text(
                      "Past Appointments",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: pastAppointments
                        .map((appointment) => _buildAppointmentCard(appointment))
                        .toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppointmentCard(QueryDocumentSnapshot appointment) {
    String doctorName = appointment['doctorName'];
    String doctorId = appointment['doctorId'];
    String status = appointment['status'];
    String date = appointment['date'];
    String time = appointment['time'];
    String appointmentId = appointment.id;

    return FutureBuilder<Map<String, String>>(
      future: _getDoctorDetails(doctorId),
      builder: (context, doctorSnapshot) {
        String doctorPhone = "Fetching...";
        String doctorEmail = "Fetching...";
        if (doctorSnapshot.connectionState == ConnectionState.done &&
            doctorSnapshot.hasData) {
          doctorPhone = doctorSnapshot.data!['phone']!;
          doctorEmail = doctorSnapshot.data!['email']!;
        }

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Icon(Icons.calendar_today, color: Colors.indigo),
            title: Text("Dr. $doctorName"),
            subtitle: Text("Date: $date\nTime: $time\nStatus: $status"),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == "generate_receipt") {
                  _generateReceipt(doctorPhone, doctorEmail, doctorName,
                      appointmentId, date, time, status);
                } else if (value == "cancel_appointment") {
                  _cancelAppointment(appointmentId);
                }
              },
              itemBuilder: (context) {
                List<PopupMenuEntry<String>> menuItems = [
                  PopupMenuItem(
                    value: "generate_receipt",
                    child: Text("Generate Receipt"),
                  ),
                ];
                if (status != "Cancelled" && status != "rejected") {
                  menuItems.add(
                    PopupMenuItem(
                      value: "cancel_appointment",
                      child: Text("Cancel Appointment",
                          style: TextStyle(color: Colors.red)),
                    ),
                  );
                }
                return menuItems;
              },
              icon: Icon(Icons.more_vert),
            ),
          ),
        );
      },
    );
  }
}
