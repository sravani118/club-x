import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/coordinator/member_card.dart';

class MembersManagementScreen extends StatefulWidget {
  final String clubId;

  const MembersManagementScreen({
    super.key,
    required this.clubId,
  });

  @override
  State<MembersManagementScreen> createState() => _MembersManagementScreenState();
}

class _MembersManagementScreenState extends State<MembersManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    'Club Members',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFFFF6B2C),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A2332),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Members List
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(widget.clubId)
                    .snapshots(),
                builder: (context, clubSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('clubs')
                        .doc(widget.clubId)
                        .collection('members')
                        .snapshots(),
                    builder: (context, membersSnapshot) {
                      if (membersSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF6B2C),
                          ),
                        );
                      }

                      if (!membersSnapshot.hasData || membersSnapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      final clubData = clubSnapshot.data?.data() as Map<String, dynamic>?;
                      final maxCapacity = clubData?['maxCapacity'] ?? 100;
                      final members = membersSnapshot.data!.docs;

                      return Column(
                        children: [
                          // Member Count
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2332),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Members',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  Text(
                                    '${members.length} / $maxCapacity',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF6B2C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Members List
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: members.length,
                              itemBuilder: (context, index) {
                                final memberDoc = members[index];
                                final memberId = memberDoc.id;
                                final memberData = memberDoc.data() as Map<String, dynamic>;

                                // Try to use stored member data first, fallback to fetching from users
                                final hasStoredData = memberData.containsKey('name') && 
                                                     memberData.containsKey('email');

                                if (hasStoredData) {
                                  // Use stored data
                                  final name = memberData['name'] ?? 'Unknown';
                                  final email = memberData['email'] ?? '';
                                  final photoUrl = memberData['photoUrl'] ?? '';

                                  // Check if member matches search query
                                  if (_searchQuery.isNotEmpty) {
                                    final nameMatch = name.toLowerCase().contains(_searchQuery);
                                    final emailMatch = email.toLowerCase().contains(_searchQuery);
                                    if (!nameMatch && !emailMatch) {
                                      return const SizedBox.shrink();
                                    }
                                  }

                                  return FutureBuilder<double>(
                                    future: _calculateAttendanceRate(memberId),
                                    builder: (context, attendanceSnapshot) {
                                      final attendanceRate = attendanceSnapshot.data ?? 0.0;

                                      return MemberCard(
                                        name: name,
                                        email: email,
                                        avatarUrl: photoUrl,
                                        attendanceRate: attendanceRate,
                                        onRemove: () => _showRemoveMemberDialog(
                                          context,
                                          memberId,
                                          name,
                                        ),
                                      );
                                    },
                                  );
                                }

                                // Fallback: Fetch user details from users collection (for old members)
                                return FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(memberId)
                                      .get(),
                                  builder: (context, userSnapshot) {
                                    if (!userSnapshot.hasData) {
                                      return const SizedBox();
                                    }

                                    final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                                    final name = userData?['name'] ?? 'Unknown';
                                    final email = userData?['email'] ?? '';
                                    final photoUrl = userData?['photoUrl'] ?? '';

                                    // Check if member matches search query
                                    if (_searchQuery.isNotEmpty) {
                                      final nameMatch = name.toLowerCase().contains(_searchQuery);
                                      final emailMatch = email.toLowerCase().contains(_searchQuery);
                                      if (!nameMatch && !emailMatch) {
                                        return const SizedBox.shrink();
                                      }
                                    }

                                    return FutureBuilder<double>(
                                      future: _calculateAttendanceRate(memberId),
                                      builder: (context, attendanceSnapshot) {
                                        final attendanceRate = attendanceSnapshot.data ?? 0.0;

                                        return MemberCard(
                                          name: name,
                                          email: email,
                                          avatarUrl: photoUrl,
                                          attendanceRate: attendanceRate,
                                          onRemove: () => _showRemoveMemberDialog(
                                            context,
                                            memberId,
                                            name,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 24),
            Text(
              'No Members Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Members will appear here once they join your club',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<double> _calculateAttendanceRate(String memberId) async {
    try {
      // Get all closed sessions for this club
      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('clubSessions')
          .where('clubId', isEqualTo: widget.clubId)
          .where('status', isEqualTo: 'closed')
          .get();

      if (sessionsSnapshot.docs.isEmpty) {
        return 0.0;
      }

      int totalSessions = sessionsSnapshot.docs.length;
      int attendedSessions = 0;

      for (var sessionDoc in sessionsSnapshot.docs) {
        final attendanceDoc = await FirebaseFirestore.instance
            .collection('clubAttendance')
            .doc(sessionDoc.id)
            .collection('students')
            .doc(memberId)
            .get();

        if (attendanceDoc.exists) {
          attendedSessions++;
        }
      }

      return (attendedSessions / totalSessions) * 100;
    } catch (e) {
      return 0.0;
    }
  }

  void _showRemoveMemberDialog(BuildContext context, String memberId, String memberName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2332),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Remove Member',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to remove $memberName from the club?',
            style: TextStyle(color: Colors.grey[400]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(widget.clubId)
                    .collection('members')
                    .doc(memberId)
                    .delete();
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$memberName removed from club'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text(
                'Remove',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }
}
