import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/user_card.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _selectedRoleFilter = 'all';
  String _searchQuery = '';

  void _changeUserRole(String userId, String userName, String currentRole, String newRole) {
    if (currentRole == newRole) return;

    // If changing to coordinator, show club selection dialog first
    if (newRole == 'coordinator') {
      _showClubSelectionDialog(userId, userName);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Role Change',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Change $userName\'s role to ${newRole[0].toUpperCase() + newRole.substring(1)}?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                debugPrint('🎯 [ADMIN] Changing role: userId=$userId, from=$currentRole, to=$newRole');
                
                // Remove clubId if changing away from coordinator (use set with merge to handle edge cases)
                final Map<String, dynamic> updateData = {'role': newRole};
                if (currentRole == 'coordinator') {
                  updateData['clubId'] = FieldValue.delete();
                  debugPrint('🗑️ [ADMIN] Removing clubId from former coordinator');
                }
                
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .set(updateData, SetOptions(merge: true));
                
                debugPrint('✅ [ADMIN] Role change successful');

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Role updated to $newRole'),
                      backgroundColor: const Color(0xFFFF6B2C),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B2C),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showClubSelectionDialog(String userId, String userName) {
    String? selectedClubId;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Assign Club to Coordinator',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a club for $userName',
              style: TextStyle(color: Colors.grey[300]),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final clubs = snapshot.data!.docs;
                
                if (clubs.isEmpty) {
                  return Text(
                    'No clubs available. Please create a club first.',
                    style: TextStyle(color: Colors.grey[400]),
                  );
                }

                return Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      children: clubs.map((club) {
                        final clubData = club.data() as Map<String, dynamic>;
                        final clubName = clubData['name'] ?? 'Unnamed Club';
                        
                        return RadioListTile<String>(
                          title: Text(
                            clubName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            clubData['category'] ?? '',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          value: club.id,
                          groupValue: selectedClubId,
                          onChanged: (value) {
                            Navigator.pop(context);
                            _confirmCoordinatorAssignment(userId, userName, value!);
                          },
                          activeColor: const Color(0xFFFF6B2C),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmCoordinatorAssignment(String userId, String userName, String clubId) async {
    try {
      debugPrint('🎯 [ADMIN] Assigning coordinator: userId=$userId, userName=$userName, clubId=$clubId');
      debugPrint('🔍 [ADMIN] clubId validation: isEmpty=${clubId.isEmpty}, length=${clubId.length}');
      
      // Validate clubId is not empty
      if (clubId.trim().isEmpty) {
        debugPrint('❌ [ADMIN] ERROR: clubId is empty!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Club ID is empty'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      
      // Use .set() with merge: true instead of .update() to handle both existing and new documents
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'role': 'coordinator',
        'clubId': clubId.trim(), // Ensure no extra whitespace
      }, SetOptions(merge: true));
      
      debugPrint('✅ [ADMIN] Coordinator assignment successful');
      
      // Add a small delay to ensure Firestore propagation
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Verify the assignment by reading from server
      final verifyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(const GetOptions(source: Source.server));
      
      if (verifyDoc.exists) {
        final verifyData = verifyDoc.data();
        debugPrint('🔍 [ADMIN] Verification - role: ${verifyData?['role']}, clubId: ${verifyData?['clubId']}');
        
        // Double-check the clubId was saved correctly
        final savedClubId = verifyData?['clubId'];
        if (savedClubId == null || savedClubId.toString().trim().isEmpty) {
          debugPrint('⚠️ [ADMIN] WARNING: clubId was not saved correctly!');
        } else {
          debugPrint('✅ [ADMIN] Verification successful - clubId saved: $savedClubId');
        }
      } else {
        debugPrint('❌ [ADMIN] ERROR: User document does not exist after assignment!');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName assigned as coordinator'),
            backgroundColor: const Color(0xFFFF6B2C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [ADMIN] Coordinator assignment failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeUser(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove User',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove $userName?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .delete();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User removed'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Management',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          // Search Bar
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFF1A2332),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Role Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRoleFilter,
                isExpanded: true,
                dropdownColor: const Color(0xFF1A2332),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Roles')),
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(
                      value: 'coordinator', child: Text('Coordinator')),
                  DropdownMenuItem(
                      value: 'subCoordinator', child: Text('Sub Coordinator')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  setState(() => _selectedRoleFilter = value!);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          // User List
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF6B2C),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Filter users
              final filteredDocs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                final role = _normalizeRole(data['role'] ?? 'student');

                final matchesRole =
                    _selectedRoleFilter == 'all' || role == _selectedRoleFilter;
                final matchesSearch = _searchQuery.isEmpty ||
                    name.contains(_searchQuery.toLowerCase()) ||
                    email.contains(_searchQuery.toLowerCase());

                return matchesRole && matchesSearch;
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Text(
                    'No users match your search',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return UserCard(
                    name: data['name'] ?? 'Unknown',
                    email: data['email'] ?? '',
                    currentRole: _normalizeRole(data['role'] ?? 'student'),
                    onRoleChange: (newRole) => _changeUserRole(
                      doc.id,
                      data['name'] ?? 'Unknown',
                      _normalizeRole(data['role'] ?? 'student'),
                      newRole,
                    ),
                    onRemove: () => _removeUser(doc.id, data['name'] ?? 'Unknown'),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _normalizeRole(String role) {
    // Normalize role values to camelCase format
    if (role == 'sub-coordinator' || role == 'Sub-Coordinator') {
      return 'subCoordinator';
    }
    return role;
  }
}
