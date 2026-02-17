import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/coordinator/activity_item.dart';

class CoordinatorOverviewScreen extends StatelessWidget {
  final String clubId;
  final String coordinatorName;

  const CoordinatorOverviewScreen({
    super.key,
    required this.clubId,
    required this.coordinatorName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Refresh logic
            await Future.delayed(const Duration(seconds: 1));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Coordinator Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome back, $coordinatorName',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 32),

                // Stats Grid
                StreamBuilder<Map<String, dynamic>>(
                  stream: _getStatsStream(),
                  builder: (context, snapshot) {
                    final stats = snapshot.data ?? {
                      'totalMembers': 0,
                      'upcomingEvents': 0,
                      'ongoingEvent': 0,
                      'attendanceRate': 0.0,
                    };

                    return GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 0.95,
                      children: [
                        StatCard(
                          icon: Icons.groups,
                          title: 'Total Members',
                          value: stats['totalMembers'].toString(),
                        ),
                        StatCard(
                          icon: Icons.event,
                          title: 'Upcoming Events',
                          value: stats['upcomingEvents'].toString(),
                          iconColor: Colors.blue,
                        ),
                        StatCard(
                          icon: Icons.play_circle,
                          title: 'Ongoing Event',
                          value: stats['ongoingEvent'].toString(),
                          iconColor: Colors.green,
                        ),
                        StatCard(
                          icon: Icons.bar_chart,
                          title: 'Attendance Rate',
                          value: '${stats['attendanceRate'].toStringAsFixed(0)}%',
                          iconColor: Colors.purple,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Recent Activity Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // View all activity
                      },
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          color: Color(0xFFFF6B2C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('activity')
                      .where('clubId', isEqualTo: clubId)
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
                        return Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2332),
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                      
                      // Show error for other types of errors
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2332),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Error loading activity',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
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
                      return _buildEmptyActivity();
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final activity = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        return ActivityItem(
                          icon: _getActivityIcon(activity['type']),
                          title: activity['title'] ?? 'Activity',
                          description: activity['description'] ?? '',
                          timestamp: (activity['timestamp'] as Timestamp).toDate(),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No recent activity',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Activity will appear here as you manage your club',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Stream<Map<String, dynamic>> _getStatsStream() {
    return Stream.periodic(const Duration(seconds: 5), (_) async {
      try {
        // Get total members
        final membersSnapshot = await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('members')
            .get();
        final totalMembers = membersSnapshot.docs.length;

        // Get upcoming events
        final upcomingEventsSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .where('clubId', isEqualTo: clubId)
            .where('status', isEqualTo: 'upcoming')
            .get();
        final upcomingEvents = upcomingEventsSnapshot.docs.length;

        // Get ongoing events
        final ongoingEventsSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .where('clubId', isEqualTo: clubId)
            .where('status', isEqualTo: 'ongoing')
            .get();
        final ongoingEvent = ongoingEventsSnapshot.docs.length;

        // Calculate attendance rate
        final eventsSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .where('clubId', isEqualTo: clubId)
            .where('status', isEqualTo: 'completed')
            .get();

        double attendanceRate = 0.0;
        if (eventsSnapshot.docs.isNotEmpty) {
          int totalRegistered = 0;
          int totalAttended = 0;

          for (var doc in eventsSnapshot.docs) {
            final data = doc.data();
            totalRegistered += (data['registeredCount'] ?? 0) as int;
            totalAttended += (data['attendanceCount'] ?? 0) as int;
          }

          if (totalRegistered > 0) {
            attendanceRate = (totalAttended / totalRegistered) * 100;
          }
        }

        return {
          'totalMembers': totalMembers,
          'upcomingEvents': upcomingEvents,
          'ongoingEvent': ongoingEvent,
          'attendanceRate': attendanceRate,
        };
      } catch (e) {
        return {
          'totalMembers': 0,
          'upcomingEvents': 0,
          'ongoingEvent': 0,
          'attendanceRate': 0.0,
        };
      }
    }).asyncMap((event) => event);
  }

  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'event_created':
        return Icons.event_available;
      case 'member_joined':
        return Icons.person_add;
      case 'attendance_marked':
        return Icons.qr_code_scanner;
      default:
        return Icons.notifications;
    }
  }
}
