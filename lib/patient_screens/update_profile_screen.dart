// update_profile_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UpdateProfileScreen extends StatefulWidget {
  final String role;
  final String uid;
  final String currentName;
  final String currentEmail;
  final String currentProfileImage;
  final String currentContactNumber;
  final String currentDateOfBirth;
  final String currentGender;
  final String currentAddress;

  const UpdateProfileScreen({
    required this.role,
    required this.uid,
    required this.currentName,
    required this.currentEmail,
    required this.currentProfileImage,
    required this.currentContactNumber,
    required this.currentDateOfBirth,
    required this.currentGender,
    required this.currentAddress,
  });

  @override
  _UpdateProfileScreenState createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;
  late TextEditingController _dobController;
  late TextEditingController _genderController;
  late TextEditingController _addressController;

  File? _newProfileImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail);
    _contactController = TextEditingController(text: widget.currentContactNumber);
    _dobController = TextEditingController(text: widget.currentDateOfBirth);
    _genderController = TextEditingController(text: widget.currentGender);
    _addressController = TextEditingController(text: widget.currentAddress);
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newProfileImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_newProfileImage == null) return null;
    try {
      Reference ref = _storage.ref().child("profile_images/${widget.uid}.jpg");
      UploadTask uploadTask = ref.putFile(_newProfileImage!);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image upload failed: $e")),
      );
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl = await _uploadImage() ?? widget.currentProfileImage;

      // Update Firebase Auth
      await _auth.currentUser!.updateProfile(
        displayName: _nameController.text.trim(),
        photoURL: imageUrl,
      );

      // Update Firestore
      await _firestore.collection('patients').doc(widget.uid).update({
        'fullname': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'gender': _genderController.text.trim(),
        'address': _addressController.text.trim(),
        'profileImage': imageUrl,
        'isProfileComplete': true,
      });

      Navigator.pop(context, true); // Return success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Update Profile"),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _isLoading ? null : _updateProfile,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _newProfileImage != null
                            ? FileImage(_newProfileImage!)
                            : (widget.currentProfileImage.isNotEmpty
                                ? NetworkImage(widget.currentProfileImage)
                                : AssetImage('assets/default_profile.png'))
                                as ImageProvider,
                        child: _newProfileImage == null
                            ? Icon(Icons.camera_alt, size: 30)
                            : null,
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildTextField(_nameController, "Full Name"),
                    _buildTextField(_emailController, "Email", isEmail: true),
                    _buildTextField(_contactController, "Contact Number"),
                    _buildTextField(_dobController, "Date of Birth (DD/MM/YYYY)"),
                    _buildTextField(_genderController, "Gender"),
                    _buildTextField(_addressController, "Address"),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isEmail = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required';
          }
          if (isEmail && !value.contains('@')) {
            return 'Please enter a valid email';
          }
          return null;
        },
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}