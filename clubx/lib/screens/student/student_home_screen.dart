import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
              );
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            final studentName = userData?['name'] ?? 'Student';

            return CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $studentName 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Welcome back to ClubX',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Stats Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Joined Clubs',
                            user.uid,
                            _getJoinedClubsCount,
                            Icons.groups,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Pending Requests',
                            user.uid,
                            _getPendingRequestsCount,
                            Icons.pending,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Upcoming Events Section
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Text(
                      'Upcoming Registered Events',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Events List
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('eventRegistrations')
                      .where('studentId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, regSnapshot) {
                    if (!regSnapshot.hasData) {
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
                          ),
                        ),
                      );
                    }

                    final registeredEventIds = regSnapshot.data!.docs
                        .map((doc) => doc['eventId'] as String)
                        .toList();

                    if (registeredEventIds.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'No registered events yet',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ),
                        ),
                      );
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('events')
                          .where(FieldPath.documentId, whereIn: registeredEventIds)
                          .snapshots(),
                      builder: (context, eventsSnapshot) {
                        if (!eventsSnapshot.hasData) {
                          return const SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
                              ),
                            ),
                          );
                        }

                        // Filter out completed events and sort by date
                        var events = eventsSnapshot.data!.docs.where((doc) {
                          final status = (doc.data() as Map<String, dynamic>)['status'] ?? '';
                          return status.toLowerCase() != 'completed';
                        }).toList();

                        // Sort by date (upcoming first)
                        events.sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          final aDate = (aData['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                          final bDate = (bData['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                          return aDate.compareTo(bDate);
                        });

                        if (events.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No upcoming events',
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                              ),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final eventData = events[index].data() as Map<String, dynamic>;
                                return _buildEventCard(context, eventData);
                              },
                              childCount: events.length,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String userId,
    Future<int> Function(String) countFunction,
    IconData icon,
  ) {
    return FutureBuilder<int>(
      future: countFunction(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Container(
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
            children: [
              Icon(
                icon,
                color: const Color(0xFFFF6B2C),
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> eventData) {
    final DateTime eventDate = (eventData['date'] as Timestamp).toDate();
    final String status = eventData['status'] ?? 'upcoming';
    
    Color statusColor;
    String statusText;
    
    switch (status) {
      case 'ongoing':
        statusColor = Colors.green;
        statusText = 'Ongoing';
        break;
      case 'completed':
        statusColor = Colors.grey;
        statusText = 'Completed';
        break;
      default:
        statusColor = const Color(0xFFFF6B2C);
        statusText = 'Upcoming';
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('clubs')
          .doc(eventData['clubId'])
          .get(),
      builder: (context, clubSnapshot) {
        final clubName = clubSnapshot.hasData && clubSnapshot.data!.data() != null
            ? (clubSnapshot.data!.data() as Map<String, dynamic>)['name'] ?? 'Unknown Club'
            : 'Loading...';

        return Container(
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      eventData['title'] ?? 'Event',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(eventDate),
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.groups, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    clubName,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
              if (eventData['venue'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        eventData['venue'],
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<int> _getJoinedClubsCount(String userId) async {
    final requests = await FirebaseFirestore.instance
        .collection('clubJoinRequests')
        .where('studentId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .get();
    return requests.docs.length;
  }

  Future<int> _getPendingRequestsCount(String userId) async {
    final requests = await FirebaseFirestore.instance
        .collection('clubJoinRequests')
        .where('studentId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    return requests.docs.length;
  }
}
