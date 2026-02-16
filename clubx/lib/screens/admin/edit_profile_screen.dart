import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  bool _loadingProfile = true;
  String? _existingProfileImageUrl;
  File? _newProfileImage;
  
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userData = userDoc.data();
      setState(() {
        _nameController.text = userData?['name'] ?? '';
        _emailController.text = user.email ?? '';
        _existingProfileImageUrl = userData?['profileImage'];
        _loadingProfile = false;
      });
    } catch (e) {
      setState(() => _loadingProfile = false);
      _showError('Error loading profile: $e');
    }
  }
  
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      setState(() {
        _newProfileImage = File(pickedFile.path);
      });
    }
  }
  
  Future<String?> _uploadProfileImage() async {
    if (_newProfileImage == null) return _existingProfileImageUrl;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      
      final fileName = 'profile_images/${user.uid}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(_newProfileImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      _showError('Error uploading image: $e');
      return null;
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('No user logged in');
        setState(() => _isLoading = false);
        return;
      }
      
      // Upload profile image if changed
      String? profileImageUrl = _existingProfileImageUrl;
      if (_newProfileImage != null) {
        profileImageUrl = await _uploadProfileImage();
      }
      
      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _nameController.text.trim(),
        'profileImage': profileImageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      _showError('Error updating profile: $e');
      setState(() => _isLoading = false);
    }
  }
  
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1B2D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loadingProfile
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B2C),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Profile Image Picker
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 70,
                              backgroundColor: const Color(0xFFFF6B2C),
                              backgroundImage: _newProfileImage != null
                                  ? FileImage(_newProfileImage!)
                                  : (_existingProfileImageUrl != null
                                      ? NetworkImage(_existingProfileImageUrl!)
                                      : null) as ImageProvider?,
                              child: _newProfileImage == null &&
                                      _existingProfileImageUrl == null
                                  ? Text(
                                      _nameController.text.isNotEmpty
                                          ? _nameController.text[0].toUpperCase()
                                          : 'A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B2C),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF0F1B2D),
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to change photo',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Name Field
                      CustomTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        prefixIcon: const Icon(Icons.person),
                        required: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          if (value.trim().length < 3) {
                            return 'Name must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Email Field (Read-only)
                      CustomTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'Your email address',
                        prefixIcon: const Icon(Icons.email),
                        enabled: false,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Email cannot be changed',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Save Button
                      PrimaryButton(
                        text: 'Save Changes',
                        onPressed: _saveProfile,
                        isLoading: _isLoading,
                        icon: Icons.save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
