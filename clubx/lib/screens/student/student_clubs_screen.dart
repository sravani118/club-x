import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_club_detail_screen.dart';

class StudentClubsScreen extends StatefulWidget {
  const StudentClubsScreen({super.key});

  @override
  State<StudentClubsScreen> createState() => _StudentClubsScreenState();
}

class _StudentClubsScreenState extends State<StudentClubsScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Browse Clubs',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join clubs and be part of the community',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2840),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF6B2C).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search clubs...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.grey),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Category Filter
                  _buildCategoryFilter(),
                ],
              ),
            ),

            // Clubs List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No active clubs available',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  var clubs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final category = data['category'] ?? '';
                    
                    final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery);
                    final matchesCategory = _selectedCategory == 'All' || category == _selectedCategory;
                    
                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (clubs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No clubs match your search',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: clubs.length,
                    itemBuilder: (context, index) {
                      final clubDoc = clubs[index];
                      final clubData = clubDoc.data() as Map<String, dynamic>;
                      return _buildClubCard(context, clubDoc.id, clubData, user.uid);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['All', 'Technical', 'Cultural', 'Sports', 'Arts', 'Social'];
    
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedCategory = category);
              },
              backgroundColor: const Color(0xFF1A2840),
              selectedColor: const Color(0xFFFF6B2C),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFFFF6B2C) : Colors.grey.withOpacity(0.3),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClubCard(BuildContext context, String clubId, Map<String, dynamic> clubData, String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubJoinRequests')
          .doc('${clubId}_$userId')
          .snapshots(),
      builder: (context, requestSnapshot) {
        String? requestStatus;
        if (requestSnapshot.hasData && requestSnapshot.data!.exists) {
          requestStatus = (requestSnapshot.data!.data() as Map<String, dynamic>?)?['status'];
        }

        // Only allow navigation if the student is an approved member
        final isApprovedMember = requestStatus == 'approved';

        return GestureDetector(
          onTap: isApprovedMember
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentClubDetailScreen(
                        clubId: clubId,
                        clubData: clubData,
                      ),
                    ),
                  );
                }
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2840),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF6B2C).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Club Header
                Row(
                  children: [
                    // Club Logo
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B2C).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF6B2C),
                          width: 2,
                        ),
                      ),
                    child: clubData['logoUrl'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              clubData['logoUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.groups,
                                  color: Color(0xFFFF6B2C),
                                  size: 30,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.groups,
                            color: Color(0xFFFF6B2C),
                            size: 30,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clubData['name'] ?? 'Club',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B2C).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            clubData['category'] ?? 'General',
                            style: const TextStyle(
                              color: Color(0xFFFF6B2C),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              if (clubData['description'] != null) ...[
                Text(
                  clubData['description'],
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
              ],

              // Stats Row
              Row(
                children: [
                  _buildStatItem(
                    Icons.people,
                    '${clubData['currentMembers'] ?? 0}/${clubData['maxMembers'] ?? 0}',
                    'Members',
                  ),
                  const SizedBox(width: 24),
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(clubData['mainCoordinatorId'])
                        .get(),
                    builder: (context, coordinatorSnapshot) {
                      final coordinatorName = coordinatorSnapshot.hasData && coordinatorSnapshot.data!.data() != null
                          ? (coordinatorSnapshot.data!.data() as Map<String, dynamic>)['name'] ?? 'Unknown'
                          : 'Loading...';
                      return _buildStatItem(
                        Icons.person,
                        coordinatorName,
                        'Coordinator',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Join Button or Status Badge
              _buildActionButton(context, clubId, userId, requestStatus, clubData),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String clubId,
    String userId,
    String? requestStatus,
    Map<String, dynamic> clubData,
  ) {
    if (requestStatus == 'approved') {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Joined',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _leaveClub(context, clubId, userId),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.2),
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.red, width: 1),
              ),
            ),
            child: const Text('Leave'),
          ),
        ],
      );
    } else if (requestStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange, width: 1),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(
              'Pending Approval',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else if (requestStatus == 'rejected') {
      return ElevatedButton(
        onPressed: () => _requestToJoin(context, clubId, userId, clubData),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B2C),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Request Again',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: () => _requestToJoin(context, clubId, userId, clubData),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B2C),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Request to Join',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
  }

  Future<void> _requestToJoin(
    BuildContext context,
    String clubId,
    String userId,
    Map<String, dynamic> clubData,
  ) async {
    try {
      // Check if student already joined 2 clubs
      final approvedRequests = await FirebaseFirestore.instance
          .collection('clubJoinRequests')
          .where('studentId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();

      if (approvedRequests.docs.length >= 2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only join a maximum of 2 clubs'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check if club is full
      final currentMembers = clubData['currentMembers'] ?? 0;
      final maxMembers = clubData['maxMembers'] ?? 0;
      
      if (currentMembers >= maxMembers) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This club is currently full'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get student name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userData = userDoc.data();
      final studentName = userData?['name'] ?? 'Student';

      // Create join request
      await FirebaseFirestore.instance
          .collection('clubJoinRequests')
          .doc('${clubId}_$userId')
          .set({
        'clubId': clubId,
        'studentId': userId,
        'studentName': studentName,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Join request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveClub(BuildContext context, String clubId, String userId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2840),
        title: const Text(
          'Leave Club?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to leave this club?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete join request
      await FirebaseFirestore.instance
          .collection('clubJoinRequests')
          .doc('${clubId}_$userId')
          .delete();

      // Decrement club member count
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .update({
        'currentMembers': FieldValue.increment(-1),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Left club successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
