import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapplication/dashboards/patient_dashboard.dart';
import 'package:myapplication/patient_screens/profile_screen.dart';

class AppointmentBookingScreen extends StatefulWidget {
  @override
  _AppointmentBookingScreenState createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _slotKeys = {};

  int _selectedIndex = 1;
  String? _selectedDoctorId;
  String? _selectedDate;
  String? _selectedAppointmentId;
  TextEditingController _reasonController = TextEditingController();
  bool _isBooking = false;
  bool _isLoadingSlots = false;
  List<Map<String, dynamic>> _doctorsList = [];
  List<Map<String, dynamic>> _availableSlots = [];

  // NEW: track if the patient already has a booking on the selected date
  bool _hasBookingOnSelectedDate = false;

  Map<String, bool> _slotSectionExpanded = {
    'Morning': true,
    'Afternoon': false,
    'Evening': false,
  };

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection("users")
          .where("role", isEqualTo: "doctor")
          .where("status", isEqualTo: "active")
          .get();

      List<Map<String, dynamic>> doctors = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          "id": doc.id,
          "name": data["name"] ?? "Unknown Doctor",
          "image": data["imageUrl"] ?? null,
        };
      }).toList();

      setState(() {
        _doctorsList = doctors;
        if (doctors.length == 1) {
          _selectedDoctorId = doctors[0]['id'];
        }
      });
    } catch (e) {
      _showError("Failed to load doctors. Please try again.");
    }
  }

  Future<void> _fetchAvailableSlots() async {
    if (_selectedDoctorId == null || _selectedDate == null) return;

    setState(() => _isLoadingSlots = true);

    try {
      QuerySnapshot snapshot = await _firestore
          .collection("appointments")
          .where("doctorId", isEqualTo: _selectedDoctorId)
          .where("date", isEqualTo: _selectedDate)
          .get();

      List<Map<String, dynamic>> slots = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          "id": doc.id,
          "time": data["time"],
          "slots": data["slots"],
        };
      }).toList();

      setState(() {
        _availableSlots = slots;
      });
    } catch (e) {
      _showError("Failed to load slots. Please try again.");
    } finally {
      setState(() => _isLoadingSlots = false);
    }
  }

  // NEW: check if the current patient already has a booking on _selectedDate
  Future<void> _checkExistingBooking() async {
    if (_selectedDate == null) return;
    User? user = _auth.currentUser;
    if (user == null) return;

    final snap = await _firestore
        .collection("booked_appointments")
        .where("patientId", isEqualTo: user.uid)
        .where("date", isEqualTo: _selectedDate)
        .get();

    setState(() {
      _hasBookingOnSelectedDate = snap.docs.isNotEmpty;
    });
  }

  void _scrollToSelectedSlot(String appointmentId) {
    final key = _slotKeys[appointmentId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: Duration(milliseconds: 400),
        alignment: 0.5,
        curve: Curves.easeInOut,
      );
    }
  }

  void _showAppointmentPreview() {
    final selectedSlot = _availableSlots.firstWhere((s) => s['id'] == _selectedAppointmentId);
    final doctorName = _doctorsList.firstWhere((doc) => doc["id"] == _selectedDoctorId)["name"];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Appointment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("👨‍⚕️ Doctor: $doctorName"),
            Text("📅 Date: $_selectedDate"),
            Text("⏰ Time: ${selectedSlot["time"]}"),
            Text("📝 Reason: ${_reasonController.text.trim().isEmpty ? 'N/A' : _reasonController.text.trim()}"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _bookAppointment();
            },
            child: Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> _bookAppointment() async {
    setState(() => _isBooking = true);

    try {
      User? user = _auth.currentUser;
      if (user == null) {
        _showError("User not logged in.");
        return;
      }

      DocumentSnapshot userDoc = await _firestore.collection("patients").doc(user.uid).get();
      String patientName = userDoc.exists ? (userDoc["fullname"] ?? "Unknown Patient") : "Unknown Patient";

      DocumentSnapshot appointmentDoc = await _firestore.collection("appointments").doc(_selectedAppointmentId).get();
      Map<String, dynamic> appointmentData = appointmentDoc.data() as Map<String, dynamic>;

      int currentSlots = appointmentData["slots"] ?? 0;
      if (currentSlots <= 0) {
        _showError("Slot no longer available.");
        return;
      }

      await _firestore.collection("booked_appointments").add({
        "appointmentId": _selectedAppointmentId,
        "date": _selectedDate,
        "doctorId": _selectedDoctorId,
        "doctorName": _doctorsList.firstWhere((doc) => doc["id"] == _selectedDoctorId)["name"],
        "patientId": user.uid,
        "patientName": patientName,
        "reason": _reasonController.text.trim(),
        "status": "pending",
        "time": appointmentData["time"],
        "createdAt": FieldValue.serverTimestamp(),
      });

      await _firestore.collection("appointments").doc(_selectedAppointmentId).update({
        "slots": currentSlots - 1,
      });

      // Show modern success overlay and redirect
      await _showSuccessAndRedirect();

      setState(() {
        _selectedAppointmentId = null;
        _reasonController.clear();
      });

      // refresh slots & booking flag
      await Future.wait([
        _fetchAvailableSlots(),
        _checkExistingBooking(),
      ]);
    } catch (e) {
      _showError("Error booking: ${e.toString()}");
    } finally {
      setState(() => _isBooking = false);
    }
  }

  Future<void> _showSuccessAndRedirect() async {
    // Display a full‐screen dialog
    showGeneralDialog(
      barrierDismissible: false,
      barrierLabel: 'Booking Success',
      context: context,
      pageBuilder: (_, __, ___) => Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(24),
            margin: EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'Appointment Booked!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Wait 2 seconds, then close dialog and redirect
    await Future.delayed(Duration(seconds: 2));
    Navigator.of(context).pop(); // close the dialog
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PatientDashboard()),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PatientDashboard()));
    } else if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MyProfileScreen()));
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupSlotsByTime(List<Map<String, dynamic>> slots) {
    final Map<String, List<Map<String, dynamic>>> grouped = {
      "Morning ☀️": [],
      "Afternoon 🌤️": [],
      "Evening 🌙": [],
    };

    for (var slot in slots) {
      String time = slot['time'];
      try {
        final parsedTime = DateFormat.jm().parse(time);
        final hour = parsedTime.hour;

        if (hour < 12) {
          grouped["Morning ☀️"]!.add(slot);
        } else if (hour < 17) {
          grouped["Afternoon 🌤️"]!.add(slot);
        } else {
          grouped["Evening 🌙"]!.add(slot);
        }
      } catch (e) {
        print("Invalid time format: $time");
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedSlots = _groupSlotsByTime(_availableSlots);

    return Scaffold(
      appBar: AppBar(title: Text("Book Appointment")),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor display
            Text("Doctor:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            _doctorsList.isEmpty
                ? Center(child: CircularProgressIndicator())
                : Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        if (_doctorsList[0]["image"] != null)
                          CircleAvatar(
                            backgroundImage: NetworkImage(_doctorsList[0]["image"]),
                            radius: 20,
                          )
                        else
                          CircleAvatar(
                            backgroundColor: Colors.grey,
                            radius: 20,
                          ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _doctorsList[0]["name"],
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
            SizedBox(height: 10),

            // Date selection + booking check
            ElevatedButton(
              onPressed: _selectedDoctorId == null
                  ? null
                  : () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 30)),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _selectedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
                          _selectedAppointmentId = null;
                          _hasBookingOnSelectedDate = false; // reset
                        });
                        await Future.wait([
                          _fetchAvailableSlots(),
                          _checkExistingBooking(),
                        ]);
                      }
                    },
              child: Text(_selectedDate ?? "Choose a Date"),
            ),

            // Banner if already booked that date
            if (_hasBookingOnSelectedDate)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: Icon(Icons.error_outline, color: Colors.red),
                    title: Text(
                      "You already have an appointment on $_selectedDate",
                      style: TextStyle(color: Colors.red[900]),
                    ),
                  ),
                ),
              ),

            // ONLY show slots if no existing booking
            if (!_hasBookingOnSelectedDate) ...[
              SizedBox(height: 16),
              Text("Available Slots:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              AnimatedSwitcher(
                duration: Duration(milliseconds: 400),
                child: _selectedDate == null
                    ? Card(
                        key: ValueKey('select_date'),
                        color: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                "Please select a date to view available slots.",
                                style: TextStyle(fontSize: 14, color: Colors.blue[900]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _availableSlots.isEmpty
                        ? Card(
                            key: ValueKey('no_slots'),
                            color: Colors.red.shade50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text(
                                    "No slots available for the selected date.",
                                    style: TextStyle(fontSize: 14, color: Colors.red[900]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: groupedSlots.entries.map((entry) {
                              final key = entry.key;
                              final slots = entry.value;

                              IconData icon;
                              List<Color> gradient;
                              switch (key) {
                                case 'Morning ☀️':
                                  icon = Icons.wb_sunny_outlined;
                                  gradient = [Colors.orange.shade200, Colors.orange.shade400];
                                  break;
                                case 'Afternoon 🌤️':
                                  icon = Icons.sunny;
                                  gradient = [Colors.yellow.shade300, Colors.amber.shade400];
                                  break;
                                case 'Evening 🌙':
                                  icon = Icons.nightlight_round;
                                  gradient = [Colors.deepPurple.shade200, Colors.deepPurple.shade400];
                                  break;
                                default:
                                  icon = Icons.access_time;
                                  gradient = [Colors.blueGrey.shade200, Colors.blueGrey.shade400];
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: gradient),
                                      ),
                                      child: ExpansionTile(
                                        initiallyExpanded: _slotSectionExpanded[key] ?? false,
                                        onExpansionChanged: (expanded) {
                                          setState(() {
                                            _slotSectionExpanded[key] = expanded;
                                          });
                                        },
                                        leading: Icon(icon, color: Colors.white),
                                        title: Text(
                                          key,
                                          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        children: slots.isEmpty
                                            ? [
                                                Padding(
                                                  padding: const EdgeInsets.all(16.0),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).brightness == Brightness.dark
                                                          ? Colors.grey.shade800
                                                          : Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: Colors.grey.shade400,
                                                      ),
                                                    ),
                                                    padding: const EdgeInsets.all(12),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.hourglass_empty,
                                                            color: Theme.of(context).colorScheme.secondary),
                                                        const SizedBox(width: 10),
                                                        Text(
                                                          "No slots available in this section!",
                                                          style: TextStyle(
                                                            color: Theme.of(context).textTheme.bodyLarge?.color,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ]
                                            : slots.map((slot) {
                                                bool isAvailable = (slot["slots"] ?? 0) > 0;
                                                bool isSelected = _selectedAppointmentId == slot["id"];
                                                final cardKey = GlobalKey();
                                                _slotKeys[slot["id"]] = cardKey;

                                                return Padding(
                                                  key: cardKey,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 300),
                                                    curve: Curves.easeInOut,
                                                    decoration: BoxDecoration(
                                                      gradient: isSelected
                                                          ? LinearGradient(
                                                              colors: [
                                                                Theme.of(context).colorScheme.primary.withOpacity(0.9),
                                                                Theme.of(context).colorScheme.primary.withOpacity(0.6),
                                                              ],
                                                              begin: Alignment.topLeft,
                                                              end: Alignment.bottomRight,
                                                            )
                                                          : null,
                                                      color: isSelected
                                                          ? null
                                                          : (Theme.of(context).brightness == Brightness.dark
                                                              ? Colors.grey.shade900
                                                              : Colors.white),
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? Theme.of(context).colorScheme.primary
                                                            : Colors.grey.shade300,
                                                        width: isSelected ? 2 : 1,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: isSelected
                                                              ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                                                              : Colors.black.withOpacity(0.05),
                                                          blurRadius: 10,
                                                          offset: const Offset(0, 6),
                                                        ),
                                                      ],
                                                    ),
                                                    child: InkWell(
                                                      borderRadius: BorderRadius.circular(16),
                                                      onTap: (!isAvailable)
                                                          ? null
                                                          : () {
                                                              setState(() {
                                                                _selectedAppointmentId = slot["id"];
                                                              });
                                                              _scrollToSelectedSlot(slot["id"]);
                                                            },
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(12),
                                                        child: Row(
                                                          children: [
                                                            CircleAvatar(
                                                              radius: 24,
                                                              backgroundColor: isAvailable
                                                                  ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
                                                                  : Colors.grey.shade300,
                                                              child: Icon(Icons.access_time,
                                                                  color: isAvailable
                                                                      ? Theme.of(context).colorScheme.secondary
                                                                      : Colors.grey),
                                                            ),
                                                            const SizedBox(width: 16),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    slot['time'],
                                                                    style: TextStyle(
                                                                      fontSize: 16,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: isAvailable
                                                                          ? Theme.of(context).textTheme.bodyLarge?.color
                                                                          : Colors.grey,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(height: 4),
                                                                  Row(
                                                                    children: [
                                                                      Icon(
                                                                        Icons.event_available,
                                                                        size: 16,
                                                                        color: isAvailable ? Colors.green : Colors.grey,
                                                                      ),
                                                                      const SizedBox(width: 4),
                                                                      Text(
                                                                        isAvailable
                                                                            ? "${slot['slots']} slot${slot['slots'] > 1 ? 's' : ''} available"
                                                                            : "No slots left",
                                                                        style: TextStyle(
                                                                          fontSize: 13,
                                                                          color: isAvailable ? Colors.green : Colors.grey,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            if (isSelected)
                                                              const Icon(Icons.check_circle, color: Colors.white, size: 28),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
              ),
            ],

            SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: "Reason for Appointment",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              // disable booking button if already booked that date
              onPressed: _selectedAppointmentId == null || _isBooking || _hasBookingOnSelectedDate
                  ? null
                  : _showAppointmentPreview,
              child: Text(_isBooking ? "Booking..." : "Book Now"),
            ),
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
}
