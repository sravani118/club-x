import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/club_card.dart';
import 'create_club_page.dart';

class ClubManagementScreen extends StatefulWidget {
  const ClubManagementScreen({super.key});

  @override
  State<ClubManagementScreen> createState() => _ClubManagementScreenState();
}

class _ClubManagementScreenState extends State<ClubManagementScreen> {
  void _toggleClubStatus(String clubId, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
      await FirebaseFirestore.instance.collection('clubs').doc(clubId).update({
        'status': newStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Club ${newStatus == 'active' ? 'activated' : 'deactivated'} successfully',
            ),
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

  void _editClub(String clubId, Map<String, dynamic> clubData) async {
    // Navigate to CreateClubPage in edit mode
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CreateClubPage(clubId: clubId, clubData: clubData),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Club updated'),
          backgroundColor: Color(0xFFFF6B2C),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _createClub() async {
    // Navigate to CreateClubPage with smooth slide animation
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CreateClubPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0); // Slide from bottom
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    // Refresh handled automatically by StreamBuilder
    if (result == true && mounted) {
      // Optional: Show a brief success indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Club list updated'),
          backgroundColor: Color(0xFFFF6B2C),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Club Management',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .snapshots(),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.groups_outlined,
                            size: 80,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No clubs found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      // Parse sub-coordinator IDs (support both old single and new multiple format)
                      List<String> subCoordinatorIds = [];
                      if (data['subCoordinatorIds'] != null) {
                        // New format: array
                        subCoordinatorIds = List<String>.from(data['subCoordinatorIds']);
                      } else if (data['subCoordinatorId'] != null && 
                                 data['subCoordinatorId'].toString().isNotEmpty) {
                        // Old format: single string
                        subCoordinatorIds = [data['subCoordinatorId']];
                      }

                      return ClubCard(
                        clubId: doc.id,
                        clubName: data['name'] ?? 'Unnamed Club',
                        category: data['category'] ?? 'Uncategorized',
                        currentMembers: data['currentMembers'] ?? 0,
                        maxMembers: data['maxMembers'] ?? 50,
                        status: data['status'] ?? 'active',
                        logoUrl: data['logoUrl'],
                        mainCoordinatorId: data['mainCoordinatorId'] ?? '',
                        subCoordinatorIds: subCoordinatorIds,
                        onToggle: () =>
                            _toggleClubStatus(doc.id, data['status'] ?? 'active'),
                        onEdit: () => _editClub(doc.id, data),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createClub,
        backgroundColor: const Color(0xFFFF6B2C),
        icon: const Icon(Icons.add),
        label: const Text('Create Club'),
      ),
    );
  }
}
