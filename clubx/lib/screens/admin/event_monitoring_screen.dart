import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../widgets/event_card.dart';

class EventMonitoringScreen extends StatelessWidget {
  const EventMonitoringScreen({super.key});

  String _getActualEventStatus(Map<String, dynamic> eventData) {
    try {
      final eventDate = (eventData['date'] as Timestamp).toDate();
      final eventTime = eventData['time'] as String?;
      final eventDuration = eventData['duration'] as int? ?? 60;

      // If time is missing, fall back to date-only comparison
      if (eventTime == null || eventTime.isEmpty) {
        final now = DateTime.now();
        final eventEndOfDay = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
          23,
          59,
          59,
        );
        
        if (now.isAfter(eventEndOfDay)) {
          return 'completed';
        } else if (now.year == eventDate.year && 
                   now.month == eventDate.month && 
                   now.day == eventDate.day) {
          return 'ongoing';
        } else {
          return 'upcoming';
        }
      }

      // Parse time - handle both "HH:mm" and "HH:mm AM/PM" formats
      String cleanTime = eventTime.replaceAll(RegExp(r'\s*(AM|PM|am|pm)\s*'), '').trim();
      final timeParts = cleanTime.split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Adjust for 12-hour format if AM/PM is present
      if (eventTime.toUpperCase().contains('PM') && hour < 12) {
        hour += 12;
      } else if (eventTime.toUpperCase().contains('AM') && hour == 12) {
        hour = 0;
      }

      final eventDateTime = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
        hour,
        minute,
      );

      final eventEndTime = eventDateTime.add(Duration(minutes: eventDuration));
      final now = DateTime.now();

      if (now.isBefore(eventDateTime)) {
        return 'upcoming';
      } else if (now.isAfter(eventEndTime)) {
        return 'completed';
      } else {
        return 'ongoing';
      }
    } catch (e) {
      return eventData['status'] ?? 'upcoming';
    }
  }

  void _showEventDetails(BuildContext context, String eventId, Map<String, dynamic> eventData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventDetailsSheet(eventId: eventId, eventData: eventData),
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
            'Event Monitoring',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .snapshots(includeMetadataChanges: true),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('❌ [ADMIN_EVENTS] Error: ${snapshot.error}');
                final errorString = snapshot.error.toString().toLowerCase();
                final isIndexBuilding = errorString.contains('index is currently building') || 
                                      errorString.contains('cannot be used yet');
                
                if (isIndexBuilding) {
                  // Index is building - show friendly message
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFFFF6B2C),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Setting up database...',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This may take a few minutes.\nThe app will load automatically.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                return Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
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

              debugPrint('📊 [ADMIN_EVENTS] Loaded ${snapshot.data?.docs.length ?? 0} events');

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 80,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No events found',
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
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final actualStatus = _getActualEventStatus(data);

                  return EventCard(
                    eventName: data['title'] ?? data['name'] ?? 'Unnamed Event',
                    clubName: data['clubName'] ?? 'Unknown Club',
                    registrationCount: data['registeredCount'] ?? data['registrationCount'] ?? 0,
                    attendanceCount: data['attendanceCount'] ?? 0,
                    status: actualStatus,
                    onViewDetails: () => _showEventDetails(context, doc.id, data),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EventDetailsSheet extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const _EventDetailsSheet({
    required this.eventId,
    required this.eventData,
  });

  String _getActualEventStatus(Map<String, dynamic> eventData) {
    try {
      final eventDate = (eventData['date'] as Timestamp).toDate();
      final eventTime = eventData['time'] as String?;
      final eventDuration = eventData['duration'] as int? ?? 60;

      // If time is missing, fall back to date-only comparison
      if (eventTime == null || eventTime.isEmpty) {
        final now = DateTime.now();
        final eventEndOfDay = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
          23,
          59,
          59,
        );
        
        if (now.isAfter(eventEndOfDay)) {
          return 'completed';
        } else if (now.year == eventDate.year && 
                   now.month == eventDate.month && 
                   now.day == eventDate.day) {
          return 'ongoing';
        } else {
          return 'upcoming';
        }
      }

      // Parse time - handle both "HH:mm" and "HH:mm AM/PM" formats
      String cleanTime = eventTime.replaceAll(RegExp(r'\s*(AM|PM|am|pm)\s*'), '').trim();
      final timeParts = cleanTime.split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Adjust for 12-hour format if AM/PM is present
      if (eventTime.toUpperCase().contains('PM') && hour < 12) {
        hour += 12;
      } else if (eventTime.toUpperCase().contains('AM') && hour == 12) {
        hour = 0;
      }

      final eventDateTime = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
        hour,
        minute,
      );

      final eventEndTime = eventDateTime.add(Duration(minutes: eventDuration));
      final now = DateTime.now();

      if (now.isBefore(eventDateTime)) {
        return 'upcoming';
      } else if (now.isAfter(eventEndTime)) {
        return 'completed';
      } else {
        return 'ongoing';
      }
    } catch (e) {
      return eventData['status'] ?? 'upcoming';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateTime = eventData['date'] != null 
        ? (eventData['date'] as Timestamp).toDate()
        : null;
    final actualStatus = _getActualEventStatus(eventData);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1A2332),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    eventData['title'] ?? eventData['name'] ?? 'Event Details',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event banner
                  if (eventData['imageUrl'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        eventData['imageUrl'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: const Color(0xFF0F1B2D),
                          child: const Icon(Icons.event, size: 60, color: Colors.grey),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Basic Info Section
                  _buildSection(
                    'Basic Information',
                    [
                      _buildInfoRow(Icons.event, 'Event Name', eventData['title'] ?? eventData['name'] ?? 'N/A'),
                      _buildInfoRow(Icons.group, 'Club', eventData['clubName'] ?? 'N/A'),
                      _buildInfoRow(Icons.calendar_today, 'Date', 
                        dateTime != null ? DateFormat('MMM dd, yyyy').format(dateTime) : 'N/A'),
                      _buildInfoRow(Icons.access_time, 'Time', eventData['time'] ?? 'N/A'),
                      _buildInfoRow(Icons.location_on, 'Venue', eventData['venue'] ?? 'N/A'),
                      _buildInfoRow(Icons.timer, 'Duration', '${eventData['duration'] ?? 'N/A'} minutes'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Description
                  if (eventData['description'] != null) ...[
                    _buildSection(
                      'Description',
                      [
                        Text(
                          eventData['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[300],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Statistics Section
                  _buildSection(
                    'Statistics',
                    [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Max Capacity',
                              eventData['maxCapacity']?.toString() ?? '0',
                              Icons.people,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Registered',
                              eventData['registeredCount']?.toString() ?? '0',
                              Icons.app_registration,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Attended',
                              eventData['attendanceCount']?.toString() ?? '0',
                              Icons.check_circle,
                              const Color(0xFFFF6B2C),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Status',
                              actualStatus.toUpperCase(),
                              Icons.info,
                              actualStatus == 'completed' ? Colors.grey : 
                              actualStatus == 'ongoing' ? Colors.green :
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Suspicious Activity Alert
                  if ((eventData['attendanceCount'] ?? 0) > (eventData['registeredCount'] ?? 0))
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Suspicious Activity Detected',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Attendance exceeds registrations',
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFF6B2C)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
