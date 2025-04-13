import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ManagePostedAppointmentsScreen extends StatefulWidget {
  @override
  _ManagePostedAppointmentsScreenState createState() =>
      _ManagePostedAppointmentsScreenState();
}

class _ManagePostedAppointmentsScreenState
    extends State<ManagePostedAppointmentsScreen> {
  List<Map<String, dynamic>> _postedSlots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: user.uid)
        .orderBy('date', descending: false)
        .get();

    setState(() {
      _postedSlots = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'date': data['date'],
          'time': data['time'],
          'slots': data['slots'],
        };
      }).toList();
      _loading = false;
    });
  }

  void _showEditSheet(Map<String, dynamic> slotData) {
    final slotController =
        TextEditingController(text: slotData['slots'].toString());

    TimeOfDay? start;
    TimeOfDay? end;

    final parts = slotData['time']?.split(" - ");
    if (parts != null && parts.length == 2) {
      start = _parseTime(parts[0]);
      end = _parseTime(parts[1]);
    }

    if (start == null || end == null) {
      _showSnackbar("Invalid time format in appointment slot.");
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return CupertinoActionSheet(
            title: Text("Edit Appointment"),
            message: Column(
              children: [
                SizedBox(height: 10),
                CupertinoButton.filled(
                  child: Text('Start: ${_formatTime(start!)}'),
                  onPressed: () => _pickTime(
                    initial: start!,
                    onSelected: (val) => setModalState(() => start = val),
                  ),
                ),
                SizedBox(height: 8),
                CupertinoButton.filled(
                  child: Text('End: ${_formatTime(end!)}'),
                  onPressed: () => _pickTime(
                    initial: end!,
                    onSelected: (val) => setModalState(() => end = val),
                  ),
                ),
                SizedBox(height: 8),
                CupertinoTextField(
                  controller: slotController,
                  keyboardType: TextInputType.number,
                  placeholder: "Number of slots",
                ),
                SizedBox(height: 16),
                CupertinoButton(
                  color: CupertinoColors.activeGreen,
                  child: Text("Update"),
                  onPressed: () async {
                    final success = await _confirmAndUpdate(
                      slotData['id'],
                      slotData['date'],
                      start,
                      end,
                      slotController.text,
                    );
                    if (success) Navigator.pop(ctx);
                  },
                ),
                SizedBox(height: 8),
                CupertinoButton(
                  child: Text("Cancel"),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickTime({
    required TimeOfDay initial,
    required Function(TimeOfDay) onSelected,
  }) async {
    TimeOfDay selected = initial;
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 250,
        color: CupertinoTheme.of(ctx).barBackgroundColor,
        child: Column(
          children: [
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime:
                    DateTime(0, 0, 0, initial.hour, initial.minute),
                onDateTimeChanged: (dt) {
                  selected = TimeOfDay(hour: dt.hour, minute: dt.minute);
                },
              ),
            ),
            CupertinoButton(
              child: Text("Done"),
              onPressed: () {
                onSelected(selected);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmAndUpdate(
    String docId,
    String date,
    TimeOfDay? start,
    TimeOfDay? end,
    String slots,
  ) async {
    if (start == null || end == null || slots.isEmpty) {
      _showSnackbar("All fields are required");
      return false;
    }

    final startMin = start!.hour * 60 + start.minute;
    final endMin = end!.hour * 60 + end.minute;
    if (startMin >= endMin) {
      _showSnackbar("Start time must be before end time");
      return false;
    }

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text("Confirm Update"),
        content: Text("Are you sure you want to update this slot?"),
        actions: [
          CupertinoDialogAction(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text("Yes"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(docId)
          .update({
        'time': "${_formatTime(start)} - ${_formatTime(end)}",
        'slots': int.parse(slots),
      });

      _showSnackbar("Updated successfully!");
      await _fetchAppointments();
      return true;
    } catch (e) {
      _showSnackbar("Failed to update: $e");
      return false;
    }
  }

  TimeOfDay _parseTime(String raw) {
  try {
    // Clean up the time string to remove unwanted spaces or non-printable characters
    String clean = raw
        .replaceAll(RegExp(r'\u00A0'), ' ')  // non-breaking space
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '')  // remove non-ASCII characters
        .trim();

    // Extract valid time like "3:00 PM"
    final match = RegExp(r'(\d{1,2}:\d{2})\s?([APap][Mm])').firstMatch(clean);

    if (match != null) {
      final timeStr = '${match.group(1)} ${match.group(2)}';  // "10:00 AM"
      final parsed = DateFormat('h:mm a').parse(timeStr);
      return TimeOfDay.fromDateTime(parsed);
    } else {
      throw FormatException('No valid time found in "$raw"');
    }
  } catch (e) {
    print('Failed to parse time: $raw | $e');
    return TimeOfDay.now(); // fallback
  }
}


  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text("Manage Posted Appointments")),
      body: _loading
          ? Center(child: CupertinoActivityIndicator())
          : _postedSlots.isEmpty
              ? Center(child: Text("No appointments found"))
              : ListView.builder(
                  itemCount: _postedSlots.length,
                  itemBuilder: (ctx, i) {
                    final slot = _postedSlots[i];
                    return Card(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      child: ListTile(
                        title: Text("Date: ${slot['date']}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Time: ${slot['time']}"),
                            Text("Slots: ${slot['slots']}"),
                          ],
                        ),
                        trailing: CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Icon(CupertinoIcons.pencil),
                          onPressed: () => _showEditSheet(slot),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
