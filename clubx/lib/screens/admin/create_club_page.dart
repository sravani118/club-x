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
  String? _subCoordinatorId;
  bool _isActive = true;
  bool _isPublic = true;
  bool _isLoading = false;

  List<Map<String, dynamic>> _students = [];
  bool _loadingStudents = true;

  bool get isEditMode => widget.clubId != null;

  final List<String> _categories = [
    'Technical',
    'Cultural',
    'Sports',
    'Literary',
    'Social Service',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadStudentsAndCoordinators();
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

        // Load club data after students are loaded to ensure coordinator IDs exist
        if (isEditMode && widget.clubData != null) {
          _loadClubData();
        }
      });
    } catch (e) {
      setState(() => _loadingStudents = false);
      if (mounted) {
        _showError('Error loading users: $e');
      }
    }
  }

  void _loadClubData() {
    final data = widget.clubData!;
    _clubNameController.text = data['name'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _maxMembersController.text = (data['maxMembers'] ?? 60).toString();
    _selectedCategory = data['category'];
    _existingLogoUrl = data['logoUrl'];
    _openJoin = data['openJoin'] ?? true;
    _isActive = data['isActive'] ?? true;
    _isPublic = data['visibility'] == 'public';

    // Only set coordinator IDs if they exist in the loaded students list
    final mainCoordId = data['mainCoordinatorId'];
    final subCoordId = data['subCoordinatorId'];

    if (mainCoordId != null &&
        _students.any((s) => s['id'] == mainCoordId)) {
      _mainCoordinatorId = mainCoordId;
    }

    if (subCoordId != null &&
        subCoordId.isNotEmpty &&
        _students.any((s) => s['id'] == subCoordId)) {
      _subCoordinatorId = subCoordId;
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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _logoImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadLogo() async {
    if (_logoImage == null) return null;

    try {
      final fileName =
          'club_logos/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(_logoImage!);
      return await ref.getDownloadURL();
    } catch (e) {
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

  Future<void> _assignCoordinatorRole(String userId, String role) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': role,
      });
    } catch (e) {
      _showError('Error assigning role: $e');
    }
  }

  Future<void> _createClub() async {
    if (!_formKey.currentState!.validate()) return;

    if (_mainCoordinatorId == null) {
      _showError('Please select a main coordinator');
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
        'subCoordinatorId': _subCoordinatorId ?? '',
        'isActive': _isActive,
        'visibility': _isPublic ? 'public' : 'private',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isEditMode) {
        // Update existing club
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(widget.clubId)
            .update(clubData);
      } else {
        // Create new club
        clubData['currentMembers'] = 0;
        clubData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('clubs').add(clubData);
      }

      // Assign coordinator roles
      await _assignCoordinatorRole(_mainCoordinatorId!, 'coordinator');
      if (_subCoordinatorId != null) {
        await _assignCoordinatorRole(_subCoordinatorId!, 'subCoordinator');
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
                CustomDropdown<String>(
                  label: 'Club Category',
                  required: true,
                  value: _selectedCategory,
                  hint: 'Select a category',
                  items: _categories
                      .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value),
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
                  CustomDropdown<String>(
                    label: 'Sub-Coordinator',
                    required: false,
                    value: _subCoordinatorId,
                    hint: 'Select sub-coordinator (optional)',
                    items: _students
                        .where((s) => s['id'] != _mainCoordinatorId)
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
                        setState(() => _subCoordinatorId = value),
                  ),
                ],
                const SizedBox(height: 32),

                // SECTION 4: VISIBILITY SETTINGS
                _buildSectionHeader('Visibility Settings'),
                const SizedBox(height: 16),
                _buildToggleTile(
                  'Club Status',
                  _isActive,
                  (value) => setState(() => _isActive = value),
                  _isActive ? 'Active' : 'Inactive',
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
