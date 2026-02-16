import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../utils/cloudinary_service.dart';

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
    debugPrint('📥 [LOAD] Loading user profile...');
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ [LOAD] No user logged in');
        return;
      }
      
      debugPrint('👤 [LOAD] Loading profile for user: ${user.uid}');
      
      // Force fetch from server to get latest data (not cache)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      
      if (!userDoc.exists) {
        debugPrint('⚠️ [LOAD] User document does not exist');
        setState(() => _loadingProfile = false);
        return;
      }
      
      final userData = userDoc.data();
      if (userData == null) {
        debugPrint('⚠️ [LOAD] User document data is null');
        setState(() => _loadingProfile = false);
        return;
      }
      
      debugPrint('📊 [LOAD] User data loaded:');
      debugPrint('   - name: ${userData['name'] ?? "null"}');
      debugPrint('   - email: ${user.email ?? "null"}');
      
      final profileImageUrl = userData['profileImage'] as String?;
      debugPrint('   - profileImage raw: "$profileImageUrl"');
      
      // Only set profile image if it's not null and not empty
      final validProfileImageUrl = (profileImageUrl != null && profileImageUrl.isNotEmpty) 
          ? profileImageUrl 
          : null;
      
      debugPrint('   - profileImage valid: ${validProfileImageUrl != null ? "YES" : "NO"}');
      if (validProfileImageUrl != null) {
        debugPrint('   - profileImage URL: ${validProfileImageUrl.substring(0, 50)}...');
      }
      
      setState(() {
        _nameController.text = userData['name'] ?? '';
        _emailController.text = user.email ?? '';
        _existingProfileImageUrl = validProfileImageUrl;
        _loadingProfile = false;
      });
      
      debugPrint('✅ [LOAD] Profile loaded successfully');
      
    } catch (e, stackTrace) {
      debugPrint('❌ [LOAD] Error loading profile: $e');
      debugPrint('📋 [LOAD] Stack trace: $stackTrace');
      setState(() => _loadingProfile = false);
      _showError('Error loading profile: $e');
    }
  }
  
  Future<void> _pickImage() async {
    debugPrint('📸 [PICKER] Starting image picker...');
    
    try {
      final ImagePicker picker = ImagePicker();
      debugPrint('📸 [PICKER] Opening gallery...');
      
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (pickedFile == null) {
        debugPrint('⚠️ [PICKER] No image selected (user cancelled)');
        return;
      }
      
      debugPrint('📸 [PICKER] Image selected: ${pickedFile.path}');
      debugPrint('📸 [PICKER] Image name: ${pickedFile.name}');
      
      if (pickedFile.path.isEmpty) {
        debugPrint('❌ [PICKER] Image path is empty');
        _showError('Selected image path is invalid');
        return;
      }
      
      final file = File(pickedFile.path);
      
      // Check if file exists and is valid
      final fileExists = await file.exists();
      debugPrint('📸 [PICKER] File exists: $fileExists');
      
      if (!fileExists) {
        debugPrint('❌ [PICKER] Selected image file not found');
        _showError('Selected image file not found');
        return;
      }
      
      // Get file size
      final fileSize = await file.length();
      debugPrint('📸 [PICKER] File size: ${fileSize ~/ 1024} KB');
      
      if (fileSize == 0) {
        debugPrint('❌ [PICKER] File is empty (0 bytes)');
        _showError('Selected image file is empty');
        return;
      }
      
      if (fileSize > 5 * 1024 * 1024) {
        debugPrint('❌ [PICKER] File too large: ${fileSize ~/ 1024 / 1024} MB');
        _showError('Image file is too large (max 5MB)');
        return;
      }
      
      setState(() {
        _newProfileImage = file;
      });
      
      debugPrint('✅ [PICKER] Image selected successfully');
      
    } catch (e, stackTrace) {
      debugPrint('❌ [PICKER] Error picking image: $e');
      debugPrint('📋 [PICKER] Stack trace: $stackTrace');
      _showError('Error picking image: $e');
    }
  }
  
  Future<String?> _uploadProfileImage() async {
    if (_newProfileImage == null) return _existingProfileImageUrl;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ [UPLOAD] No user logged in');
      throw Exception('User not logged in');
    }
    
    try {
      // Upload to Cloudinary
      final imageUrl = await CloudinaryService().uploadProfileImage(
        imageFile: _newProfileImage!,
        userId: user.uid,
      );
      
      debugPrint('🎉 [UPLOAD] Profile image upload completed successfully!');
      debugPrint('🔗 [UPLOAD] Image URL: $imageUrl');
      
      return imageUrl;
      
    } catch (e, stackTrace) {
      debugPrint('❌ [UPLOAD] Critical error during upload: $e');
      debugPrint('📋 [UPLOAD] Stack trace: $stackTrace');
      _showError('Error uploading image: $e');
      rethrow;
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('⚠️ [SAVE] Form validation failed');
      return;
    }
    
    debugPrint('💾 [SAVE] Starting profile save process');
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ [SAVE] No user logged in');
        _showError('No user logged in');
        setState(() => _isLoading = false);
        return;
      }
      
      debugPrint('👤 [SAVE] Saving profile for user: ${user.uid}');
      debugPrint('📝 [SAVE] Name: ${_nameController.text.trim()}');
      debugPrint('🖼️ [SAVE] Has new image: ${_newProfileImage != null}');
      debugPrint('🖼️ [SAVE] Existing image URL: ${_existingProfileImageUrl ?? "none"}');
      
      // Upload profile image if changed
      String? profileImageUrl = _existingProfileImageUrl;
      if (_newProfileImage != null) {
        debugPrint('📤 [SAVE] New image detected, starting upload...');
        try {
          profileImageUrl = await _uploadProfileImage();
          
          if (profileImageUrl == null || profileImageUrl.isEmpty) {
            debugPrint('❌ [SAVE] Upload returned null or empty URL');
            throw Exception('Failed to upload image - no URL returned');
          }
          
          debugPrint('✅ [SAVE] Image uploaded successfully');
          debugPrint('🔗 [SAVE] New image URL: ${profileImageUrl.substring(0, 50)}...');
          
        } catch (e, stackTrace) {
          debugPrint('❌ [SAVE] Image upload failed: $e');
          debugPrint('📋 [SAVE] Stack trace: $stackTrace');
          setState(() => _isLoading = false);
          _showError('Failed to upload profile image. Please try again.');
          return;
        }
      } else {
        debugPrint('ℹ️ [SAVE] No new image to upload, using existing URL');
      }
      
      // Prepare update data
      final updateData = {
        'name': _nameController.text.trim(),
        'profileImage': profileImageUrl, // Save null if no image, not empty string
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      debugPrint('📊 [SAVE] Update data prepared:');
      debugPrint('   - name: ${updateData['name']}');
      debugPrint('   - profileImage: ${profileImageUrl ?? "null"}');
      
      // Update Firestore with retry logic
      int firestoreAttempts = 0;
      const maxFirestoreAttempts = 3;
      bool firestoreSuccess = false;
      
      while (firestoreAttempts < maxFirestoreAttempts && !firestoreSuccess) {
        firestoreAttempts++;
        debugPrint('🔄 [SAVE] Firestore update attempt $firestoreAttempts/$maxFirestoreAttempts');
        
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update(updateData);
          
          firestoreSuccess = true;
          debugPrint('✅ [SAVE] Firestore updated successfully');
          
          // Verify the update by reading back from server
          debugPrint('🔍 [SAVE] Verifying update by reading from server...');
          final verifyDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(const GetOptions(source: Source.server));
          
          if (verifyDoc.exists) {
            final verifyData = verifyDoc.data();
            debugPrint('✓ [SAVE] Verification - name: ${verifyData?['name']}');
            debugPrint('✓ [SAVE] Verification - profileImage exists: ${verifyData?['profileImage'] != null}');
            
            if (verifyData?['name'] != updateData['name']) {
              debugPrint('⚠️ [SAVE] WARNING: Name mismatch after update!');
              debugPrint('   Expected: ${updateData['name']}');
              debugPrint('   Got: ${verifyData?['name']}');
            }
            
            if (profileImageUrl != null && verifyData?['profileImage'] != profileImageUrl) {
              debugPrint('⚠️ [SAVE] WARNING: Profile image mismatch after update!');
            }
          } else {
            debugPrint('❌ [SAVE] ERROR: Document does not exist after update!');
          }
          
        } catch (e) {
          debugPrint('❌ [SAVE] Firestore update attempt $firestoreAttempts failed: $e');
          
          if (firestoreAttempts >= maxFirestoreAttempts) {
            debugPrint('❌ [SAVE] All Firestore update attempts exhausted');
            rethrow;
          }
          
          // Wait before retrying
          await Future.delayed(Duration(seconds: firestoreAttempts));
        }
      }
      
      debugPrint('🎉 [SAVE] Profile saved successfully!');
      
      // Clear image cache to ensure new profile image is shown
      if (_newProfileImage != null) {
        debugPrint('🗑️ [SAVE] Clearing image cache...');
        imageCache.clear();
        imageCache.clearLiveImages();
      }
      
      // Wait a moment for Firestore to propagate the changes to listeners
      await Future.delayed(const Duration(milliseconds: 500));
      
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
        debugPrint('✅ [SAVE] Success notification shown, returning to previous screen');
        
        // Wait for snackbar to show
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ [SAVE] Critical error during profile save: $e');
      debugPrint('📋 [SAVE] Stack trace: $stackTrace');
      _showError('Error updating profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('🏁 [SAVE] Profile save process completed');
      }
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
