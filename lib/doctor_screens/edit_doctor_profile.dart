import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class EditDoctorProfileScreen extends StatefulWidget {
  @override
  _EditDoctorProfileScreenState createState() => _EditDoctorProfileScreenState();
}

class _EditDoctorProfileScreenState extends State<EditDoctorProfileScreen> {
  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController specializationController = TextEditingController();
  TextEditingController clinicAddressController = TextEditingController();  // New controller for clinic address
  String profileImage = "";
  File? _image;

  @override
  void initState() {
    super.initState();
    _fetchCurrentProfile();
  }

  void _fetchCurrentProfile() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          nameController.text = doc['name'] ?? "";
          phoneController.text = doc['phone'] ?? "";
          specializationController.text = doc['specialization'] ?? "";
          clinicAddressController.text = doc['clinic_address'] ?? "";  // Fetch clinic address
          profileImage = doc['imageUrl'] ?? "https://www.w3schools.com/howto/img_avatar.png";
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String? uploadedImageUrl = profileImage;

      if (_image != null) {
        uploadedImageUrl = await _uploadImageToFirebase(_image!);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': nameController.text,
        'phone': phoneController.text,
        'specialization': specializationController.text,
        'clinic_address': clinicAddressController.text,  // Save clinic address
        'imageUrl': uploadedImageUrl,
      });

      Navigator.pop(context); // Go back after saving
    }
  }

  Future<String> _uploadImageToFirebase(File imageFile) async {
    String fileName = "profile_images/${FirebaseAuth.instance.currentUser!.uid}.jpg";
    Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
    await storageRef.putFile(imageFile);
    return await storageRef.getDownloadURL();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Profile"),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _image != null ? FileImage(_image!) : NetworkImage(profileImage) as ImageProvider,
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Full Name"),
            ),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: "Phone Number"),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: specializationController,
              decoration: InputDecoration(labelText: "Specialization"),
            ),
            TextField(
              controller: clinicAddressController,  // New TextField for clinic address
              decoration: InputDecoration(labelText: "Clinic Address"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateProfile,
              child: Text("Save Changes"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            ),
          ],
        ),
      ),
    );
  }
}
