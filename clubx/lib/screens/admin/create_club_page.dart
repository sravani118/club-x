import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/primary_button.dart';

class CreateClubPage extends StatefulWidget {
  final String? clubId;
  final Map<String, dynamic>? clubData;

  const CreateClubPage({super.key, this.clubId, this.clubData});

  @override
  State<CreateClubPage> createState() => _CreateClubPageState();
}

class _CreateClubPageState extends State<CreateClubPage> {
  final _formKey = GlobalKey<FormState>();
  final _clubNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxMembersController = TextEditingController(text: '60');

  File? _logoImage;
  String? _existingLogoUrl;
  String? _selectedCategory;
  bool _openJoin = true;
  String? _mainCoordinatorId;
  List<String> _subCoordinatorIds = [];
  String _status = 'active';
  bool _isPublic = true;
  bool _isLoading = false;

  List<Map<String, dynamic>> _students = [];
  bool _loadingStudents = true;

  bool get isEditMode => widget.clubId != null;

  // Categories will be loaded from Firestore
  List<String> _categories = [];
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadStudentsAndCoordinators();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clubCategories')
          .orderBy('name')
          .get();

      if (snapshot.docs.isEmpty) {
        // Initialize default categories if none exist
        await _initializeDefaultCategories();
      } else {
        setState(() {
          _categories = snapshot.docs
              .map((doc) => doc.data()['name'] as String)
              .toList();
          _loadingCategories = false;
        });
        
        // Try to load club data now that categories are ready
        _tryLoadClubData();
      }
    } catch (e) {
      // If collection doesn't exist or error, initialize defaults
      await _initializeDefaultCategories();
    }
  }

  Future<void> _initializeDefaultCategories() async {
    final defaultCategories = [
      'Dance',
      'Sports',
      'Music',
      'Treking',
      'Quiz',
      'Art',
      'Coding',
      'Event Management',
    ];

    try {
      for (String category in defaultCategories) {
        await FirebaseFirestore.instance.collection('clubCategories').add({
          'name': category,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _categories = defaultCategories;
        _loadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _categories = defaultCategories;
        _loadingCategories = false;
      });
    }
    
    // Try to load club data now that categories are ready
    _tryLoadClubData();
  }

  Future<void> _loadStudentsAndCoordinators() async {
    try {
      // Load users who are students, coordinators, or subCoordinators
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role',
              whereIn: ['student', 'coordinator', 'subCoordinator']).get();

      setState(() {
        _students = snapshot.docs
            .map(
              (doc) => {
                'id': doc.id,
                'name': doc.data()['name'] ?? 'Unknown',
                'email': doc.data()['email'] ?? '',
                'role': doc.data()['role'] ?? 'student',
              },
            )
            .toList();
        _loadingStudents = false;
      });

      // Load club data after both students and categories are loaded
      _tryLoadClubData();
    } catch (e) {
      setState(() => _loadingStudents = false);
      if (mounted) {
        _showError('Error loading users: $e');
      }
    }
  }

  void _tryLoadClubData() {
    // Only load club data if both students and categories are ready
    if (isEditMode && 
        widget.clubData != null && 
        !_loadingStudents && 
        !_loadingCategories) {
      _loadClubData();
    }
  }

  void _loadClubData() {
    final data = widget.clubData!;
    _clubNameController.text = data['name'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _maxMembersController.text = (data['maxMembers'] ?? 60).toString();
    
    // Handle category - add old category if not in current list
    final oldCategory = data['category'];
    if (oldCategory != null && oldCategory.toString().isNotEmpty) {
      if (!_categories.contains(oldCategory)) {
        // Add old category to maintain backward compatibility
        setState(() {
          _categories.add(oldCategory);
          _categories.sort();
        });
      }
      _selectedCategory = oldCategory;
    }
    
    _existingLogoUrl = data['logoUrl'];
    _openJoin = data['openJoin'] ?? true;
    _status = data['status'] ?? 'active';
    _isPublic = data['visibility'] == 'public';

    // Load main coordinator ID
    final mainCoordId = data['mainCoordinatorId'];
    if (mainCoordId != null &&
        _students.any((s) => s['id'] == mainCoordId)) {
      _mainCoordinatorId = mainCoordId;
    }

    // Load sub-coordinator IDs (support both old single and new array format)
    if (data['subCoordinatorIds'] != null) {
      // New format: array
      final subIds = List<String>.from(data['subCoordinatorIds']);
      _subCoordinatorIds = subIds.where((id) => 
        id.isNotEmpty && _students.any((s) => s['id'] == id)
      ).toList();
    } else if (data['subCoordinatorId'] != null && 
               data['subCoordinatorId'].toString().isNotEmpty) {
      // Old format: single string
      final subId = data['subCoordinatorId'];
      if (_students.any((s) => s['id'] == subId)) {
        _subCoordinatorIds = [subId];
      }
    }
  }

  @override
  void dispose() {
    _clubNameController.dispose();
    _descriptionController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }


  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null && pickedFile.path.isNotEmpty) {
        final file = File(pickedFile.path);
        // Check if file exists and is valid
        if (await file.exists()) {
          setState(() {
            _logoImage = file;
          });
        } else {
          _showError('Selected image file not found');
        }
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<String?> _uploadLogo() async {
    if (_logoImage == null) {
      debugPrint('ℹ️ [CLUB_LOGO] No logo to upload');
      return null;
    }

    debugPrint('🚀 [CLUB_LOGO] Starting club logo upload');
    
    try {
      // Validate file exists
      final fileExists = await _logoImage!.exists();
      debugPrint('📁 [CLUB_LOGO] File exists check: $fileExists');
      debugPrint('📁 [CLUB_LOGO] File path: ${_logoImage!.path}');
      
      if (!fileExists) {
        debugPrint('❌ [CLUB_LOGO] Logo file not found');
        throw Exception('Logo file not found');
      }
      
      // Get file size for validation
      final fileSize = await _logoImage!.length();
      debugPrint('📊 [CLUB_LOGO] File size: ${fileSize ~/ 1024} KB');
      
      if (fileSize == 0) {
        debugPrint('❌ [CLUB_LOGO] File is empty (0 bytes)');
        throw Exception('Logo file is empty');
      }
      
      if (fileSize > 5 * 1024 * 1024) {
        debugPrint('❌ [CLUB_LOGO] File too large: ${fileSize ~/ 1024 / 1024} MB');
        throw Exception('Logo file is too large (max 5MB)');
      }
      
      // Validate file path is not empty
      if (_logoImage!.path.isEmpty) {
        debugPrint('❌ [CLUB_LOGO] Invalid logo file path (empty)');
        throw Exception('Invalid logo file path');
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'club_logos/$timestamp.jpg';
      debugPrint('📤 [CLUB_LOGO] Uploading to: $fileName');
      
      final ref = FirebaseStorage.instance.ref().child(fileName);
      
      // Upload with retry logic (max 3 attempts)
      int attempts = 0;
      const maxAttempts = 3;
      TaskSnapshot? snapshot;
      
      while (attempts < maxAttempts) {
        attempts++;
        debugPrint('🔄 [CLUB_LOGO] Upload attempt $attempts/$maxAttempts');
        
        try {
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          );
          
          final uploadTask = ref.putFile(_logoImage!, metadata);
          
          // Monitor upload progress
          uploadTask.snapshotEvents.listen((TaskSnapshot taskSnapshot) {
            final progress = (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) * 100;
            debugPrint('📊 [CLUB_LOGO] Progress: ${progress.toStringAsFixed(1)}%');
          });
          
          snapshot = await uploadTask.whenComplete(() {});
          debugPrint('✅ [CLUB_LOGO] Upload completed on attempt $attempts');
          break;
          
        } catch (e) {
          debugPrint('❌ [CLUB_LOGO] Upload attempt $attempts failed: $e');
          
          if (attempts >= maxAttempts) {
            debugPrint('❌ [CLUB_LOGO] All upload attempts exhausted');
            rethrow;
          }
          
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      }
      
      if (snapshot == null) {
        debugPrint('❌ [CLUB_LOGO] Upload failed - no snapshot');
        throw Exception('Upload failed after $maxAttempts attempts');
      }
      
      // Get download URL with retry
      String? downloadUrl;
      attempts = 0;
      
      while (attempts < maxAttempts) {
        attempts++;
        debugPrint('🔄 [CLUB_LOGO] Getting download URL attempt $attempts/$maxAttempts');
        
        try {
          downloadUrl = await snapshot.ref.getDownloadURL();
          debugPrint('✅ [CLUB_LOGO] Download URL obtained');
          break;
        } catch (e) {
          debugPrint('❌ [CLUB_LOGO] Failed to get download URL (attempt $attempts): $e');
          
          if (attempts >= maxAttempts) {
            debugPrint('❌ [CLUB_LOGO] Could not get download URL');
            rethrow;
          }
          
          await Future.delayed(Duration(seconds: attempts));
        }
      }
      
      if (downloadUrl == null || downloadUrl.isEmpty) {
        debugPrint('❌ [CLUB_LOGO] Download URL is null or empty');
        throw Exception('Failed to get download URL');
      }
      
      debugPrint('🎉 [CLUB_LOGO] Logo upload completed successfully!');
      debugPrint('🔗 [CLUB_LOGO] URL: ${downloadUrl.substring(0, 50)}...');
      
      return downloadUrl;
      
    } catch (e, stackTrace) {
      debugPrint('❌ [CLUB_LOGO] Critical error during upload: $e');
      debugPrint('📋 [CLUB_LOGO] Stack trace: $stackTrace');
      _showError('Error uploading logo: $e');
      return null;
    }
  }

  Future<bool> _isClubNameUnique(String name) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clubs')
          .where('name', isEqualTo: name.trim())
          .limit(1)
          .get();
      return snapshot.docs.isEmpty;
    } catch (e) {
      _showError('Error checking club name: $e');
      return false;
    }
  }

  Future<void> _assignCoordinatorRole(String userId, String role, String clubId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': role,
        'clubId': clubId,
      });
    } catch (e) {
      _showError('Error assigning role: $e');
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final TextEditingController categoryController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162A45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Add New Category',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: categoryController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter category name',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: const Color(0xFF0F1B2D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFFF6B2C),
                width: 2,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final categoryName = categoryController.text.trim();
              if (categoryName.isEmpty) {
                _showError('Category name cannot be empty');
                return;
              }

              if (_categories.contains(categoryName)) {
                _showError('Category already exists');
                return;
              }

              try {
                // Add to Firestore
                await FirebaseFirestore.instance
                    .collection('clubCategories')
                    .add({
                  'name': categoryName,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                // Update local list
                setState(() {
                  _categories.add(categoryName);
                  _categories.sort();
                  _selectedCategory = categoryName;
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Category "$categoryName" added successfully'),
                      backgroundColor: const Color(0xFFFF6B2C),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              } catch (e) {
                _showError('Error adding category: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Add',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createClub() async {
    if (!_formKey.currentState!.validate()) return;

    if (_mainCoordinatorId == null) {
      _showError('Please select a main coordinator');
      return;
    }

    if (_selectedCategory == null) {
      _showError('Please select a category');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check for unique club name (skip if editing same club)
      if (!isEditMode) {
        final isUnique = await _isClubNameUnique(_clubNameController.text);
        if (!isUnique) {
          _showError('A club with this name already exists');
          setState(() => _isLoading = false);
          return;
        }
      }

      // Upload logo if changed
      String? logoUrl = _existingLogoUrl;
      if (_logoImage != null) {
        logoUrl = await _uploadLogo();
      }

      final clubData = {
        'name': _clubNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'logoUrl': logoUrl ?? '',
        'maxMembers': int.parse(_maxMembersController.text),
        'openJoin': _openJoin,
        'mainCoordinatorId': _mainCoordinatorId,
        'subCoordinatorIds': _subCoordinatorIds,
        'status': _status,
        'visibility': _isPublic ? 'public' : 'private',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      String clubId;
      if (isEditMode) {
        // Update existing club
        clubId = widget.clubId!;
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .update(clubData);
      } else {
        // Create new club
        clubData['currentMembers'] = 0;
        clubData['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await FirebaseFirestore.instance.collection('clubs').add(clubData);
        clubId = docRef.id;
      }

      // Assign coordinator roles with clubId
      await _assignCoordinatorRole(_mainCoordinatorId!, 'coordinator', clubId);
      for (String subCoordId in _subCoordinatorIds) {
        if (subCoordId.isNotEmpty) {
          await _assignCoordinatorRole(subCoordId, 'subCoordinator', clubId);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditMode
                  ? 'Club "${_clubNameController.text}" updated successfully!'
                  : 'Club "${_clubNameController.text}" created successfully!',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Error ${isEditMode ? 'updating' : 'creating'} club: $e');
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
        title: Text(
          isEditMode ? 'Edit Club' : 'Create New Club',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1: CLUB BASIC INFO
                _buildSectionHeader('Club Basic Info'),
                const SizedBox(height: 16),
                _buildLogoUpload(),
                const SizedBox(height: 24),
                CustomTextField(
                  controller: _clubNameController,
                  label: 'Club Name',
                  required: true,
                  hint: 'Enter club name',
                  prefixIcon: const Icon(Icons.groups, color: Colors.grey),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Club name is required';
                    }
                    if (value.trim().length < 3) {
                      return 'Club name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _descriptionController,
                  label: 'Club Description',
                  required: true,
                  hint: 'Describe the club\'s purpose and activities',
                  maxLines: 4,
                  prefixIcon: const Icon(Icons.description, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                if (_loadingCategories)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6B2C),
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomDropdown<String>(
                        label: 'Club Category',
                        required: true,
                        value: _selectedCategory,
                        hint: 'Select a category',
                        items: _categories
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedCategory = value),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _showAddCategoryDialog,
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Color(0xFFFF6B2C),
                        ),
                        label: const Text(
                          'Add New Category',
                          style: TextStyle(
                            color: Color(0xFFFF6B2C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          backgroundColor: const Color(0xFFFF6B2C).withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),

                // SECTION 2: MEMBER SETTINGS
                _buildSectionHeader('Member Settings'),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _maxMembersController,
                  label: 'Maximum Members',
                  required: true,
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(
                    Icons.people_outline,
                    color: Colors.grey,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Maximum members is required';
                    }
                    final number = int.tryParse(value);
                    if (number == null) {
                      return 'Please enter a valid number';
                    }
                    if (number < 1 || number > 500) {
                      return 'Must be between 1 and 500';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildToggleTile(
                  'Open Join',
                  _openJoin,
                  (value) => setState(() => _openJoin = value),
                  'Students can join directly without approval',
                ),
                const SizedBox(height: 32),

                // SECTION 3: COORDINATOR ASSIGNMENT
                _buildSectionHeader('Coordinator Assignment'),
                const SizedBox(height: 16),
                if (_loadingStudents)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6B2C),
                      ),
                    ),
                  )
                else ...[
                  CustomDropdown<String>(
                    label: 'Main Coordinator',
                    required: true,
                    value: _mainCoordinatorId,
                    hint: 'Select main coordinator',
                    items: _students
                        .map(
                          (student) => DropdownMenuItem<String>(
                            value: student['id'] as String,
                            child: Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                student['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _mainCoordinatorId = value),
                  ),
                  const SizedBox(height: 20),
                  
                  // Sub-Coordinators (Multiple Selection)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Sub-Coordinators',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(Optional)',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Display selected sub-coordinators as chips
                      if (_subCoordinatorIds.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _subCoordinatorIds.map((id) {
                            final student = _students.firstWhere(
                              (s) => s['id'] == id,
                              orElse: () => {'name': 'Unknown', 'id': id},
                            );
                            return Chip(
                              backgroundColor: const Color(0xFFFF6B2C),
                              deleteIconColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFFFF6B2C),
                                width: 1,
                              ),
                              label: Text(
                                student['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              onDeleted: () {
                                setState(() {
                                  _subCoordinatorIds.remove(id);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Dropdown to add sub-coordinators
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1B2D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[700]!,
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text(
                              'Add sub-coordinator',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                            value: null,
                            dropdownColor: const Color(0xFF162A45),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFFFF6B2C),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            items: _students
                                .where((s) => 
                                  s['id'] != _mainCoordinatorId &&
                                  !_subCoordinatorIds.contains(s['id'])
                                )
                                .map((student) => DropdownMenuItem<String>(
                                  value: student['id'] as String,
                                  child: Text(
                                    student['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _subCoordinatorIds.add(value);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),

                // SECTION 4: VISIBILITY SETTINGS
                _buildSectionHeader('Visibility Settings'),
                const SizedBox(height: 16),
                _buildToggleTile(
                  'Club Status',
                  _status == 'active',
                  (value) => setState(() => _status = value ? 'active' : 'inactive'),
                  _status == 'active' ? 'Active' : 'Inactive',
                ),
                const SizedBox(height: 16),
                _buildToggleTile(
                  'Visibility',
                  _isPublic,
                  (value) => setState(() => _isPublic = value),
                  _isPublic ? 'Public' : 'Private',
                ),
                const SizedBox(height: 40),

                // SUBMIT BUTTON
                PrimaryButton(
                  text: isEditMode ? 'Update Club' : 'Create Club',
                  icon: isEditMode
                      ? Icons.check_circle_outline
                      : Icons.add_circle_outline,
                  isLoading: _isLoading,
                  onPressed: _createClub,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFFF6B2C), width: 2)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFF6B2C),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLogoUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Club Logo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B2C).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _logoImage != null
                  ? ClipOval(child: Image.file(_logoImage!, fit: BoxFit.cover))
                  : _existingLogoUrl != null && _existingLogoUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        _existingLogoUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF6B2C),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.add_photo_alternate,
                            size: 48,
                            color: Colors.grey,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.add_photo_alternate,
                      size: 48,
                      color: Colors.grey,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _pickLogo,
            icon: const Icon(Icons.upload, color: Color(0xFFFF6B2C)),
            label: Text(
              isEditMode ? 'Change Logo' : 'Upload Logo',
              style: const TextStyle(color: Color(0xFFFF6B2C)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTile(
    String title,
    bool value,
    void Function(bool) onChanged,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF6B2C),
            activeTrackColor: const Color(0xFFFF6B2C).withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}
