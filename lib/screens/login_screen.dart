import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:myapplication/dashboards/admin_dashboard.dart';
import 'package:myapplication/dashboards/doctor_dashboard.dart';
import 'package:myapplication/dashboards/patient_dashboard.dart';
import 'package:myapplication/dashboards/staff_dashboard.dart';
import 'package:myapplication/screens/register_patient.dart';
import 'package:myapplication/screens/forgot_password.dart';
import 'update_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        String role = userDoc['role'];
        bool isProfileComplete = userDoc['isProfileComplete'] ?? false;

        // Check status for doctor, staff, and patient
if (role == 'doctor' || role == 'staff' || role == 'patient') {
  String status = userDoc['status'] ?? 'inactive';
  if (status == 'inactive') {
    Fluttertoast.showToast(msg: "Your account is inactive. Contact admin.");
    setState(() {
      _isLoading = false;
    });
    return;
  }
}


        if (!isProfileComplete) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => UpdateProfileScreen(uid: uid, role: role)),
          );
        } else {
          if (role == 'admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminDashboard()),
            );
          } else if (role == 'doctor') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => DoctorDashboard()),
            );
          } else if (role == 'staff') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => StaffDashboard()),
            );
          } else if (role == 'patient') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => PatientDashboard()),
            );
          } else {
            Fluttertoast.showToast(msg: "Invalid role.");
          }
        }
      } else {
        Fluttertoast.showToast(msg: "User not found in database.");
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          Fluttertoast.showToast(msg: "Invalid email format.");
          break;
        case 'user-not-found':
          Fluttertoast.showToast(msg: "No user found with this email.");
          break;
        case 'wrong-password':
          Fluttertoast.showToast(msg: "Incorrect password.");
          break;
        case 'user-disabled':
          Fluttertoast.showToast(msg: "This account has been disabled.");
          break;
        default:
          Fluttertoast.showToast(msg: "Authentication failed: ${e.message}");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "An unexpected error occurred.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : const LinearGradient(
                  colors: [Colors.lightBlue, Colors.blueAccent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          color: isDark ? Colors.black : null,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset("assets/auth_selection.jpeg", height: 180),
                      const SizedBox(height: 20),
                      Text(
                        "Login to Your Account",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _emailController,
                        label: "Email",
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        isDark: isDark,
                      ),
                      _buildTextField(
                        controller: _passwordController,
                        label: "Password",
                        icon: Icons.lock,
                        obscureText: _obscurePassword,
                        isDark: isDark,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: isDark ? Colors.white70 : Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
                          );
                        },
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.grey[850] : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 50),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.blueAccent)
                            : Text(
                                "Log In",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDark ? Colors.white : Colors.blueAccent,
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => RegisterPatient()),
                          );
                        },
                        child: Text(
                          "Don't have an account?",
                          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: TextStyle(color: isDark ? Colors.white : Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.white70),
          prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.white70),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: isDark ? Colors.grey[850] : Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Please enter your $label";
          }
          return null;
        },
      ),
    );
  }
}
