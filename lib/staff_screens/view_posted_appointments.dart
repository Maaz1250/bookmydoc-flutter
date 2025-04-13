import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ViewPostedAppointmentsScreen extends StatefulWidget {
  @override
  _ViewPostedAppointmentsScreenState createState() => _ViewPostedAppointmentsScreenState();
}

class _ViewPostedAppointmentsScreenState extends State<ViewPostedAppointmentsScreen> {
  DateTime? fromDate;
  DateTime? toDate;

  // Function to show a date picker
  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    DateTime initialDate = isFromDate
        ? fromDate ?? DateTime.now()
        : toDate ?? fromDate ?? DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          fromDate = picked;
          if (toDate != null && toDate!.isBefore(fromDate!)) {
            toDate = fromDate; // Ensure "To Date" is not before "From Date"
          }
        } else {
          if (picked.isBefore(fromDate!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("To Date cannot be earlier than From Date")),
            );
            return;
          }
          toDate = picked;
        }
      });
    }
  }

  // Function to fetch appointments within the selected date range
  Stream<QuerySnapshot>? getAppointments() {
    if (fromDate == null || toDate == null) {
      return null; // Do not fetch until both dates are selected
    }

    return FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(fromDate!))
        .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(toDate!))
        .snapshots();
  }

  // Function to fetch doctor's name from Firestore
  Future<String> getDoctorName(String doctorId) async {
    DocumentSnapshot doctorSnapshot =
        await FirebaseFirestore.instance.collection('doctors').doc(doctorId).get();
    if (doctorSnapshot.exists && doctorSnapshot.data() != null) {
      return doctorSnapshot['name'] ?? 'Unknown Doctor';
    } else {
      return 'Unknown Doctor';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("View Appointments")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text("From Date"),
                    ElevatedButton(
                      onPressed: () => _selectDate(context, true),
                      child: Text(fromDate == null
                          ? "Select Date"
                          : DateFormat('yyyy-MM-dd').format(fromDate!)),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text("To Date"),
                    ElevatedButton(
                      onPressed: () => _selectDate(context, false),
                      child: Text(toDate == null
                          ? "Select Date"
                          : DateFormat('yyyy-MM-dd').format(toDate!)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getAppointments(),
              builder: (context, snapshot) {
                if (fromDate == null || toDate == null) {
                  return Center(child: Text("Please select both dates to view appointments"));
                }

                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var appointments = snapshot.data!.docs;
                if (appointments.isEmpty) {
                  return Center(child: Text("No appointments found"));
                }

                return ListView.builder(
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    var appointment = appointments[index];
                    String doctorId = appointment['doctorId'];

                    return FutureBuilder<String>(
                      future: getDoctorName(doctorId),
                      builder: (context, doctorSnapshot) {
                        if (!doctorSnapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }

                        return Card(
                          margin: EdgeInsets.all(8),
                          child: ListTile(
                            title: Text("Doctor: ${doctorSnapshot.data}"),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Date: ${appointment['date']}"),
                                Text("Time: ${appointment['time']}"),
                                Text("Slots: ${appointment['slots']}"),
                              ],
                            ),
                          ),
                        );
                      },
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
