import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PostAppointmentScreen extends StatefulWidget {
  @override
  _PostAppointmentScreenState createState() => _PostAppointmentScreenState();
}

class _PostAppointmentScreenState extends State<PostAppointmentScreen> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _slotController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<Map<String, dynamic>> _postedSlots = [];

  @override
  void dispose() {
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _slotController.dispose();
    super.dispose();
  }

  void _pickDate() {
    DateTime selectedDate = DateTime.now();
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Container(
          height: 250,
          child: Column(
            children: [
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  minimumDate: DateTime.now(),
                  maximumDate: DateTime(2100),
                  onDateTimeChanged: (DateTime value) {
                    selectedDate = value;
                  },
                ),
              ),
              CupertinoButton(
                child: Text("Select"),
                onPressed: () {
                  String formatted = DateFormat('yyyy-MM-dd').format(selectedDate);
                  setState(() {
                    _dateController.text = formatted;
                  });
                  _fetchPostedSlots(formatted);
                  Navigator.pop(context);
                },
              )
            ],
          ),
        );
      },
    );
  }

  void _pickTime({required bool isStartTime}) {
    TimeOfDay selectedTime = TimeOfDay.now();
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Container(
          height: 250,
          child: Column(
            children: [
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false,
                  onDateTimeChanged: (DateTime value) {
                    selectedTime = TimeOfDay(hour: value.hour, minute: value.minute);
                  },
                ),
              ),
              CupertinoButton(
                child: Text("Select"),
                onPressed: () {
                  final now = DateTime.now();
                  final dt = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
                  final formattedTime = DateFormat.jm().format(dt);

                  setState(() {
                    if (isStartTime) {
                      _startTime = selectedTime;
                      _startTimeController.text = formattedTime;
                    } else {
                      _endTime = selectedTime;
                      _endTimeController.text = formattedTime;
                    }
                  });
                  Navigator.pop(context);
                },
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchPostedSlots(String date) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: user.uid)
        .where('date', isEqualTo: date)
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      _postedSlots = snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<bool> _isSlotOverlapping(String date, TimeOfDay start, TimeOfDay end) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: user.uid)
        .where('date', isEqualTo: date)
        .get();

    for (var doc in snapshot.docs) {
      String timeRange = doc['time'];
      List<String> parts = timeRange.split(' - ');
      if (parts.length != 2) continue;

      TimeOfDay existingStart = _parseTime(parts[0]);
      TimeOfDay existingEnd = _parseTime(parts[1]);

      if (!(end.hour < existingStart.hour ||
          (end.hour == existingStart.hour && end.minute <= existingStart.minute) ||
          start.hour > existingEnd.hour ||
          (start.hour == existingEnd.hour && start.minute >= existingEnd.minute))) {
        return true;
      }
    }

    return false;
  }

  TimeOfDay _parseTime(String time) {
    final format = DateFormat.jm();
    final dt = format.parse(time);
    return TimeOfDay.fromDateTime(dt);
  }

  void _postAppointmentSlot() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String date = _dateController.text.trim();
    String slots = _slotController.text.trim();

    if (date.isEmpty || _startTime == null || _endTime == null || slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;

    if (startMinutes >= endMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Start time must be before end time")),
      );
      return;
    }

    bool hasOverlap = await _isSlotOverlapping(date, _startTime!, _endTime!);
    if (hasOverlap) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("This slot overlaps with an existing appointment")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('appointments').add({
      'doctorId': user.uid,
      'date': date,
      'time': "${_startTimeController.text} - ${_endTimeController.text}",
      'slots': int.parse(slots),
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Appointment slot posted successfully!")),
    );

    _fetchPostedSlots(date);

    _startTimeController.clear();
    _endTimeController.clear();
    _slotController.clear();
    _startTime = null;
    _endTime = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Post Appointment Slot")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: "Select Date",
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: _pickDate,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _startTimeController,
              decoration: InputDecoration(
                labelText: "Start Time",
                suffixIcon: Icon(Icons.access_time),
              ),
              readOnly: true,
              onTap: () => _pickTime(isStartTime: true),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _endTimeController,
              decoration: InputDecoration(
                labelText: "End Time",
                suffixIcon: Icon(Icons.access_time),
              ),
              readOnly: true,
              onTap: () => _pickTime(isStartTime: false),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _slotController,
              decoration: InputDecoration(labelText: "Number of Slots"),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _postAppointmentSlot,
              child: Text("Post Slot"),
            ),
            SizedBox(height: 30),
            if (_postedSlots.isNotEmpty) ...[
              Text("Posted Slots for Selected Date:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _postedSlots.length,
                itemBuilder: (context, index) {
                  final slot = _postedSlots[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      title: Text(slot['time']),
                      subtitle: Text("Slots: ${slot['slots']}"),
                    ),
                  );
                },
              ),
            ]
          ],
        ),
      ),
    );
  }
}
