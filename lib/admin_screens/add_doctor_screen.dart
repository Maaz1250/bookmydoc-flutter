import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:email_validator/email_validator.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

class AddDoctorScreen extends StatefulWidget {
  const AddDoctorScreen({super.key});

  @override
  _AddDoctorScreenState createState() => _AddDoctorScreenState();
}

class _AddDoctorScreenState extends State<AddDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSendingEmail = false;

  void _registerDoctor() async {
    if (!_formKey.currentState!.validate()) return;

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    try {
      // Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      // Store doctor details in Firestore (users and doctors collections)
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'role': 'doctor',
        'uid': uid,
        'status': 'active',
        'isProfileComplete': false, // Profile incomplete by default
      });

      await _firestore.collection('doctors').doc(uid).set({
        'email': email,
        'uid': uid,
        'status': 'active',
        'isProfileComplete': false, // Profile incomplete by default
        'created_at': FieldValue.serverTimestamp(),
      });

      // Send email with credentials
      _sendEmail(email, password);

      Fluttertoast.showToast(msg: "Doctor registered successfully!");
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    }
  }

  Future<void> _sendEmail(String recipientEmail, String password) async {
    setState(() {
      _isSendingEmail = true;
    });

    if (!EmailValidator.validate(recipientEmail)) {
      Fluttertoast.showToast(msg: "Invalid email format.");
      setState(() {
        _isSendingEmail = false;
      });
      return;
    }

    String username = 'mcaproject2024.25@gmail.com'; // Replace with your email
    String appPassword = 'awib haqc svwg vacz'; // Use App Password (not regular password)

    final smtpServer = gmail(username, appPassword);
    final message = Message()
      ..from = Address(username, 'Admin')
      ..recipients.add(recipientEmail)
      ..subject = 'Doctor Account Created'
      ..text = 'Hello Doctor,\n\nYour account has been created.\n\nEmail: $recipientEmail\nPassword: $password\n\nPlease log in and complete your profile before using the system.\n\nRegards,\nAdmin';

    try {
      await send(message, smtpServer);
      Fluttertoast.showToast(msg: "Email sent successfully!");
    } catch (e) {
      Fluttertoast.showToast(msg: "Email failed: $e");
    }

    setState(() {
      _isSendingEmail = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Doctor")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: "Email"),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Enter email";
                  if (!EmailValidator.validate(value)) return "Enter a valid email";
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true,
                validator: (value) => value!.length < 6 ? "Min 6 characters" : null,
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(labelText: "Confirm Password"),
                obscureText: true,
                validator: (value) => value != _passwordController.text ? "Passwords do not match" : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _registerDoctor,
                child: Text("Register Doctor"),
              ),
              if (_isSendingEmail) Padding(
                padding: EdgeInsets.only(top: 20),
                child: CircularProgressIndicator(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
