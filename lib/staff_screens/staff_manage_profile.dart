import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ManageProfile extends StatefulWidget {
  @override
  _ManageProfileState createState() => _ManageProfileState();
}

class _ManageProfileState extends State<ManageProfile> {
  final _formKey = GlobalKey<FormState>();
  String _fullname = "";
  String _phone = "";
  String _DOB = "";
  String _address = "";
  String _profilePhotoUrl = "";
  File? _imageFile;

  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _DOBController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Load user data from Firestore
  void _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _fullname = userDoc["fullname"] ?? "";
          _phone = userDoc["contactNumber"] ?? "";
          _DOB = userDoc["dateOfBirth"] ??""; // Ensure this field exists in Firestore
          _address = userDoc["address"] ?? "";
          _profilePhotoUrl = userDoc["profileImage"] ?? "";

          _fullnameController.text = _fullname;
          _phoneController.text = _phone;
          _DOBController.text = _DOB;
          _addressController.text = _address;
        });
      }
    }
  }

  /// Pick Image from Gallery
  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  /// Upload Image to Firebase Storage
  Future<String> _uploadImage(String userId) async {
    if (_imageFile == null) return _profilePhotoUrl;

    Reference ref =
        FirebaseStorage.instance.ref().child("profileImages/$userId.jpg");
    UploadTask uploadTask = ref.putFile(_imageFile!);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Update User Data in Firestore
  void _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String imageUrl = await _uploadImage(user.uid);

        Map<String, dynamic> updatedData = {
          "fullname": _fullnameController.text,
          "phone": _phoneController.text,
          "dob": _DOBController.text,
          "address": _addressController.text,
          "profileImage": imageUrl,
        };

        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .update(updatedData);
        await FirebaseFirestore.instance
            .collection("staff")
            .doc(user.uid)
            .update(updatedData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text("Manage Profile"), backgroundColor: Colors.indigo),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (_profilePhotoUrl.isNotEmpty
                                ? NetworkImage(_profilePhotoUrl)
                                : AssetImage("assets/default_profile.png"))
                            as ImageProvider,
                    child: _imageFile == null
                        ? Icon(Icons.camera_alt, size: 40, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _fullnameController,
                decoration: InputDecoration(labelText: "Full Name"),
                validator: (value) =>
                    value!.isEmpty ? "Enter your full name" : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: "Email", enabled: false),
                initialValue: FirebaseAuth.instance.currentUser?.email ?? "",
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: "Phone Number"),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value!.isEmpty ? "Enter your phone number" : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _DOBController,
                decoration: InputDecoration(
                  labelText: "Date of Birth",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true, // Prevent manual input
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );

                  if (pickedDate != null) {
                    setState(() {
                      _DOBController.text = "${pickedDate.toLocal()}"
                          .split(' ')[0]; // Format YYYY-MM-DD
                    });
                  }
                },
                validator: (value) =>
                    value!.isEmpty ? "Enter your Date of Birth" : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: "Address"),
                validator: (value) =>
                    value!.isEmpty ? "Enter your address" : null,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                child: Text("Update Profile", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
