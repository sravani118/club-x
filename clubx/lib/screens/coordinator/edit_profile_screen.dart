import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/cloudinary_service.dart';

class CoordinatorEditProfileScreen extends StatefulWidget {
  const CoordinatorEditProfileScreen({super.key});

  @override
  State<CoordinatorEditProfileScreen> createState() => _CoordinatorEditProfileScreenState();
}

class _CoordinatorEditProfileScreenState extends State<CoordinatorEditProfileScreen> {
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
    debugPrint('📥 [COORD_PROFILE] Loading user profile...');
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ [COORD_PROFILE] No user logged in');
        return;
      }
      
      debugPrint('👤 [COORD_PROFILE] Loading profile for user: ${user.uid}');
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      
      if (!userDoc.exists) {
        debugPrint('⚠️ [COORD_PROFILE] User document does not exist');
        setState(() => _loadingProfile = false);
        return;
      }
      
      final userData = userDoc.data();
      if (userData == null) {
        debugPrint('⚠️ [COORD_PROFILE] User document data is null');
        setState(() => _loadingProfile = false);
        return;
      }
      
      debugPrint('📊 [COORD_PROFILE] User data loaded:');
      debugPrint('   - name: ${userData['name'] ?? "null"}');
      
      final profileImageUrl = userData['profileImage'] as String?;
      final validProfileImageUrl = (profileImageUrl != null && profileImageUrl.isNotEmpty) 
          ? profileImageUrl 
          : null;
      
      debugPrint('   - profileImage valid: ${validProfileImageUrl != null ? "YES" : "NO"}');
      
      setState(() {
        _nameController.text = userData['name'] ?? '';
        _emailController.text = user.email ?? '';
        _existingProfileImageUrl = validProfileImageUrl;
        _loadingProfile = false;
      });
      
      debugPrint('✅ [COORD_PROFILE] Profile loaded successfully');
      
    } catch (e) {
      debugPrint('❌ [COORD_PROFILE] Error loading profile: $e');
      setState(() => _loadingProfile = false);
      _showError('Error loading profile: $e');
    }
  }
  
  Future<void> _pickImage() async {
    debugPrint('📸 [COORD_PICKER] Starting image picker...');
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (pickedFile == null) {
        debugPrint('⚠️ [COORD_PICKER] No image selected');
        return;
      }
      
      debugPrint('📸 [COORD_PICKER] Image selected: ${pickedFile.path}');
      
      if (pickedFile.path.isEmpty) {
        debugPrint('❌ [COORD_PICKER] Image path is empty');
        _showError('Selected image path is invalid');
        return;
      }
      
      final file = File(pickedFile.path);
      
      final fileExists = await file.exists();
      debugPrint('📸 [COORD_PICKER] File exists: $fileExists');
      
      if (!fileExists) {
        debugPrint('❌ [COORD_PICKER] Selected image file not found');
        _showError('Selected image file not found');
        return;
      }
      
      final fileSize = await file.length();
      debugPrint('📸 [COORD_PICKER] File size: ${fileSize ~/ 1024} KB');
      
      if (fileSize == 0) {
        debugPrint('❌ [COORD_PICKER] File is empty (0 bytes)');
        _showError('Selected file is empty');
        return;
      }
      
      if (fileSize > 5 * 1024 * 1024) {
        debugPrint('❌ [COORD_PICKER] File too large: ${fileSize ~/ 1024} KB');
        _showError('Image too large. Please select an image under 5MB');
        return;
      }
      
      debugPrint('✅ [COORD_PICKER] Image validated successfully');
      
      setState(() {
        _newProfileImage = file;
      });
      
      debugPrint('✅ [COORD_PICKER] Image set in state');
      
    } catch (e) {
      debugPrint('❌ [COORD_PICKER] Error picking image: $e');
      _showError('Error selecting image: $e');
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isLoading = true);
    debugPrint('💾 [COORD_SAVE] Starting profile save...');
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }
      
      String? finalImageUrl = _existingProfileImageUrl;
      
      if (_newProfileImage != null) {
        debugPrint('📤 [COORD_SAVE] Uploading new profile image...');
        finalImageUrl = await CloudinaryService().uploadProfileImage(
          imageFile: _newProfileImage!,
          userId: user.uid,
        );
        debugPrint('✅ [COORD_SAVE] Image uploaded: $finalImageUrl');
      }
      
      final updateData = {
        'name': _nameController.text.trim(),
        if (finalImageUrl != null && finalImageUrl.isNotEmpty)
          'profileImage': finalImageUrl,
      };
      
      debugPrint('💾 [COORD_SAVE] Updating Firestore with data: $updateData');
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));
      
      debugPrint('✅ [COORD_SAVE] Profile updated in Firestore');
      
      // Verify the update
      await Future.delayed(const Duration(milliseconds: 500));
      final verifyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      
      final verifyData = verifyDoc.data();
      debugPrint('🔍 [COORD_SAVE] Verification - name: ${verifyData?['name']}');
      debugPrint('🔍 [COORD_SAVE] Verification - profileImage: ${verifyData?['profileImage']?.substring(0, 50) ?? "null"}...');
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      debugPrint('❌ [COORD_SAVE] Error saving profile: $e');
      _showError('Error updating profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2332),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    
                    // Profile Image
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF6B2C).withOpacity(0.2),
                              border: Border.all(
                                color: const Color(0xFFFF6B2C),
                                width: 3,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: _newProfileImage != null
                                  ? Image.file(
                                      _newProfileImage!,
                                      fit: BoxFit.cover,
                                    )
                                  : _existingProfileImageUrl != null
                                      ? Image.network(
                                          _existingProfileImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildDefaultAvatar();
                                          },
                                        )
                                      : _buildDefaultAvatar(),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6B2C),
                                shape: BoxShape.circle,
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
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Name Field
                    _buildTextField(
                      controller: _nameController,
                      label: 'Name',
                      hint: 'Enter your name',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Email Field (read-only)
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'Email',
                      icon: Icons.email,
                      enabled: false,
                    ),
                    const SizedBox(height: 32),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B2C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildDefaultAvatar() {
    return Center(
      child: Text(
        _nameController.text.isNotEmpty
            ? _nameController.text[0].toUpperCase()
            : 'C',
        style: const TextStyle(
          color: Color(0xFFFF6B2C),
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: Icon(icon, color: const Color(0xFFFF6B2C)),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF6B2C)),
            ),
          ),
        ),
      ],
    );
  }
}
