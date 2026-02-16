import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'event_qr_pass_screen.dart';

class StudentEventsScreen extends StatefulWidget {
  const StudentEventsScreen({super.key});

  @override
  State<StudentEventsScreen> createState() => _StudentEventsScreenState();
}

class _StudentEventsScreenState extends State<StudentEventsScreen> {
  String _selectedFilter = 'All';

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
                    'Events',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Register for events from your clubs',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Filter Chips
                  _buildFilterChips(),
                ],
              ),
            ),

            // Events List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubJoinRequests')
                    .where('studentId', isEqualTo: user.uid)
                    .where('status', isEqualTo: 'approved')
                    .snapshots(),
                builder: (context, joinedClubsSnapshot) {
                  if (joinedClubsSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
                    );
                  }

                  if (!joinedClubsSnapshot.hasData || joinedClubsSnapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Join clubs to see their events',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final joinedClubIds = joinedClubsSnapshot.data!.docs
                      .map((doc) => doc['clubId'] as String)
                      .toList();

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .where('clubId', whereIn: joinedClubIds.isEmpty ? ['none'] : joinedClubIds)
                        .snapshots(),
                    builder: (context, eventsSnapshot) {
                      if (eventsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
                        );
                      }

                      if (!eventsSnapshot.hasData || eventsSnapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'No events available',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }

                      var events = eventsSnapshot.data!.docs;

                      // Filter out inactive events
                      events = events.where((doc) {
                        final status = (doc.data() as Map<String, dynamic>)['status'] ?? '';
                        return status.toLowerCase() != 'inactive';
                      }).toList();

                      // Sort by date (upcoming first)
                      events.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aDate = (aData['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                        final bDate = (bData['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                        return aDate.compareTo(bDate);
                      });

                      // Apply filter
                      if (_selectedFilter != 'All') {
                        events = events.where((doc) {
                          final status = (doc.data() as Map<String, dynamic>)['status'] ?? '';
                          return status.toLowerCase() == _selectedFilter.toLowerCase();
                        }).toList();
                      }

                      if (events.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'No events match your filter',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final eventDoc = events[index];
                          final eventData = eventDoc.data() as Map<String, dynamic>;
                          return _buildEventCard(context, eventDoc.id, eventData, user.uid);
                        },
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

  Widget _buildFilterChips() {
    final filters = ['All', 'Upcoming', 'Ongoing', 'Completed'];
    
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedFilter = filter);
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

  Widget _buildEventCard(
    BuildContext context,
    String eventId,
    Map<String, dynamic> eventData,
    String userId,
  ) {
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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventRegistrations')
          .doc('${eventId}_$userId')
          .snapshots(),
      builder: (context, regSnapshot) {
        final isRegistered = regSnapshot.hasData && regSnapshot.data!.exists;

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
                  // Event Banner
                  if (eventData['bannerUrl'] != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: Image.network(
                        eventData['bannerUrl'],
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 180,
                            color: const Color(0xFFFF6B2C).withOpacity(0.2),
                            child: const Center(
                              child: Icon(
                                Icons.event,
                                color: Color(0xFFFF6B2C),
                                size: 60,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Event Details
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Status
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                eventData['title'] ?? 'Event',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
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

                        // Date & Time
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.grey, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEEE, MMM dd, yyyy').format(eventDate),
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.grey, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('hh:mm a').format(eventDate),
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Venue
                        if (eventData['venue'] != null) ...[
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
                          const SizedBox(height: 8),
                        ],

                        // Club Name
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
                        const SizedBox(height: 16),

                        // Capacity
                        Row(
                          children: [
                            const Icon(Icons.people, color: Colors.grey, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Capacity: ${eventData['registeredCount'] ?? 0}/${eventData['maxCapacity'] ?? 0}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Register Button or Status
                        if (isRegistered && (status == 'upcoming' || status == 'ongoing'))
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EventQRPassScreen(
                                    eventId: eventId,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text(
                              'View Event Pass',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        else if (isRegistered)
                          Container(
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
                                  'Registered',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (status == 'completed')
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey, width: 1),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy, color: Colors.grey, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Event Completed',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ElevatedButton(
                            onPressed: () => _registerForEvent(context, eventId, userId, eventData),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B2C),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Register Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _registerForEvent(
    BuildContext context,
    String eventId,
    String userId,
    Map<String, dynamic> eventData,
  ) async {
    try {
      // Check if already registered
      final existingReg = await FirebaseFirestore.instance
          .collection('eventRegistrations')
          .doc('${eventId}_$userId')
          .get();

      if (existingReg.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are already registered for this event'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check capacity
      final registeredCount = eventData['registeredCount'] ?? 0;
      final maxCapacity = eventData['maxCapacity'] ?? 0;

      if (registeredCount >= maxCapacity) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event is full'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Create registration
      await FirebaseFirestore.instance
          .collection('eventRegistrations')
          .doc('${eventId}_$userId')
          .set({
        'eventId': eventId,
        'studentId': userId,
        'registeredAt': FieldValue.serverTimestamp(),
        'qrData': '${eventId}_$userId',
      });

      // Increment registered count
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .update({
        'registeredCount': FieldValue.increment(1),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully registered for event!'),
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
