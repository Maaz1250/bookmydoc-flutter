import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboards/admin_dashboard.dart';
import 'dashboards/doctor_dashboard.dart';
import 'dashboards/patient_dashboard.dart';
import 'dashboards/staff_dashboard.dart';

import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Automatically switches theme
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        cardColor: Colors.white,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Color(0xFF121212),
        cardColor: Color(0xFF1E1E1E),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      initialRoute: "/",
      routes: {
        "/": (context) => AuthWrapper(),
        "/welcome": (context) => WelcomeScreen(),
        "/login": (context) => LoginScreen(),
        "/patient_dashboard": (context) => PatientDashboard(),
        "/doctor_dashboard": (context) => DoctorDashboard(),
        "/staff_dashboard": (context) => StaffDashboard(),
        "/admin_dashboard": (context) => AdminDashboard(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          return FutureBuilder<String>(
            future: _getUserRole(snapshot.data!.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              if (roleSnapshot.hasError || !roleSnapshot.hasData) {
                return WelcomeScreen();
              }

              String role = roleSnapshot.data!;
              print("User Role: $role");

              switch (role) {
                case "patient":
                  return PatientDashboard();
                case "doctor":
                  return DoctorDashboard();
                case "staff":
                  return StaffDashboard();
                case "admin":
                  return AdminDashboard();
                default:
                  return WelcomeScreen();
              }
            },
          );
        }

        return WelcomeScreen();
      },
    );
  }

  Future<String> _getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection("users").doc(uid).get();
      if (userDoc.exists) {
        return userDoc["role"] ?? "unknown";
      }
    } catch (e) {
      print("Error fetching user role: $e");
    }
    return "unknown";
  }
}




// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: PhoneAuthScreen(),
//     );
//   }
// }

// class PhoneAuthScreen extends StatefulWidget {
//   @override
//   _PhoneAuthScreenState createState() => _PhoneAuthScreenState();
// }

// class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController otpController = TextEditingController();
//   FirebaseAuth auth = FirebaseAuth.instance;
//   String verificationId = '';
//   bool isOTPSent = false;

//   // Send OTP
//   void sendOTP() async {
//   String phone = phoneController.text.trim();

//   // Ensure user enters the correct format
//   if (!phone.startsWith("+")) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Enter phone number with country code (e.g., +919876543210)")),
//     );
//     return;
//   }

//   try {
//     await auth.verifyPhoneNumber(
//       phoneNumber: phone,
//       timeout: const Duration(seconds: 60),
//       verificationCompleted: (PhoneAuthCredential credential) async {
//         await auth.signInWithCredential(credential);
//         print("Auto verification completed!");
//       },
//       verificationFailed: (FirebaseAuthException e) {
//         print("Verification failed: ${e.message}");
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text("Verification failed: ${e.message}"),
//         ));
//       },
//       codeSent: (String verId, int? resendToken) {
//         setState(() {
//           verificationId = verId;
//           isOTPSent = true;
//         });
//         print("OTP sent successfully!");
//       },
//       codeAutoRetrievalTimeout: (String verId) {
//         print("Auto-retrieval timeout.");
//       },
//     );
//   } catch (e) {
//     print("Error sending OTP: $e");
//   }
// }


//   // Verify OTP
//   void verifyOTP() async {
//     try {
//       PhoneAuthCredential credential = PhoneAuthProvider.credential(
//         verificationId: verificationId,
//         smsCode: otpController.text.trim(),
//       );
//       UserCredential userCredential = await auth.signInWithCredential(credential);

//       if (userCredential.user != null) {
//         print("User signed in successfully!");
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("User signed in successfully!")),
//         );
//       }
//     } catch (e) {
//       print("Error verifying OTP: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Invalid OTP, please try again.")),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Firebase OTP Authentication")),
//       body: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             TextField(
//               controller: phoneController,
//               keyboardType: TextInputType.phone,
//               decoration: InputDecoration(
//                 labelText: "Enter Phone Number",
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             SizedBox(height: 10),
//             ElevatedButton(
//               onPressed: sendOTP,
//               child: Text("Send OTP"),
//             ),
//             if (isOTPSent) ...[
//               SizedBox(height: 20),
//               TextField(
//                 controller: otpController,
//                 keyboardType: TextInputType.number,
//                 decoration: InputDecoration(
//                   labelText: "Enter OTP",
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               SizedBox(height: 10),
//               ElevatedButton(
//                 onPressed: verifyOTP,
//                 child: Text("Verify OTP"),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
