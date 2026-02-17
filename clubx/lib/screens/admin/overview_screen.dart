import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/stat_card.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Grid with real data
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
            builder: (context, clubSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, userSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('events').snapshots(),
                    builder: (context, eventSnapshot) {
                      final clubCount = clubSnapshot.hasData ? clubSnapshot.data!.docs.length : 0;
                      final userCount = userSnapshot.hasData ? userSnapshot.data!.docs.length : 0;
                      final eventCount = eventSnapshot.hasData ? eventSnapshot.data!.docs.length : 0;

                      return GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.95,
                        children: [
                          StatCard(
                            icon: Icons.groups,
                            title: 'Total Clubs',
                            value: clubCount.toString(),
                          ),
                          StatCard(
                            icon: Icons.people,
                            title: 'Total Users',
                            value: userCount.toString(),
                          ),
                          StatCard(
                            icon: Icons.event,
                            title: 'Total Events',
                            value: eventCount.toString(),
                          ),
                          const StatCard(
                            icon: Icons.health_and_safety,
                            title: 'System Health',
                            value: 'Active',
                            iconColor: Colors.green,
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
          // Recent Activity
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('activity')
                .orderBy('timestamp', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              // Handle errors
              if (snapshot.hasError) {
                final errorString = snapshot.error.toString().toLowerCase();
                final isIndexBuilding = errorString.contains('index is currently building') || 
                                      errorString.contains('cannot be used yet');
                
                if (isIndexBuilding) {
                  // Index is building - show friendly message
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFFFF6B2C),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Setting up activity feed...',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This will load automatically',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                
                // Show error for other types
                return _buildActivityItem(
                  Icons.error_outline,
                  'Error loading activity',
                  'Please check your connection',
                  'Now',
                );
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildActivityItem(
                  Icons.info_outline,
                  'No recent activity',
                  'System activity will appear here',
                  'Just now',
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildActivityItem(
                    _getActivityIcon(data['type'] ?? 'default'),
                    data['title'] ?? 'Activity',
                    data['description'] ?? '',
                    _formatTime(data['timestamp']),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'club_created':
        return Icons.group_add;
      case 'coordinator_assigned':
        return Icons.person_add;
      case 'event_created':
        return Icons.event_available;
      default:
        return Icons.info_outline;
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    
    try {
      final DateTime dateTime = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());
      
      final difference = DateTime.now().difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  Widget _buildActivityItem(
    IconData icon,
    String title,
    String description,
    String time,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B2C).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF6B2C),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
