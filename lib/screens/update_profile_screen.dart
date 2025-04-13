// update_profile_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class UpdateProfileScreen extends StatefulWidget {
  final String role;
  final String uid;

  const UpdateProfileScreen({
    required this.role,
    required this.uid,
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
  late TextEditingController _contactController;
  late TextEditingController _dobController;
  late TextEditingController _genderController;
  late TextEditingController _addressController;

  File? _newProfileImage;
  bool _isLoading = false;
  String _currentProfileImage = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _contactController = TextEditingController();
    _dobController = TextEditingController();
    _genderController = TextEditingController();
    _addressController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      DocumentSnapshot userDoc = await _firestore
          .collection(widget.role == 'patient' ? 'patients' : 'users')
          .doc(widget.uid)
          .get();

      if (userDoc.exists) {
        _nameController.text = userDoc['fullname'] ?? '';
        _contactController.text = userDoc['contactNumber'] ?? '';
        _dobController.text = userDoc['dateOfBirth'] ?? '';
        _genderController.text = userDoc['gender'] ?? '';
        _addressController.text = userDoc['address'] ?? '';
        _currentProfileImage = userDoc['profileImage'] ?? '';
        _email = userDoc['email'] ?? '';
      }

      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        _email = user.email!;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading profile: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
      String? imageUrl = await _uploadImage() ?? _currentProfileImage;

      await _auth.currentUser!.updateProfile(
        displayName: _nameController.text.trim(),
        photoURL: imageUrl,
      );

      await _firestore
          .collection(widget.role == 'patient' ? 'patients' : 'users')
          .doc(widget.uid)
          .update({
        'fullname': _nameController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'gender': _genderController.text.trim(),
        'address': _addressController.text.trim(),
        'profileImage': imageUrl,
        'isProfileComplete': true,
      });

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _dobController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      });
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
                            : (_currentProfileImage.isNotEmpty
                                ? NetworkImage(_currentProfileImage)
                                : AssetImage('assets/default_profile.png'))
                                as ImageProvider,
                        child: _newProfileImage == null
                            ? Icon(Icons.camera_alt, size: 30)
                            : null,
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildTextField(_nameController, "Full Name"),
                    _buildReadOnlyTextField("Email", _email),
                    _buildTextField(_contactController, "Contact Number"),
                    _buildDateField(_dobController, "Date of Birth"),
                    _buildTextField(_genderController, "Gender"),
                    _buildTextField(_addressController, "Address"),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildReadOnlyTextField(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        initialValue: value,
        readOnly: true,
      ),
    );
  }

  Widget _buildDateField(TextEditingController controller, String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today),
        ),
        onTap: () => _selectDate(context),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a date';
          }
          return null;
        },
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
