import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'event_qr_pass_screen.dart';
import 'student_session_scanner_screen.dart';

class StudentActivityScreen extends StatefulWidget {
  const StudentActivityScreen({super.key});

  @override
  State<StudentActivityScreen> createState() => _StudentActivityScreenState();
}

class _StudentActivityScreenState extends State<StudentActivityScreen> {
  int _selectedTab = 0;

  /// Calculate actual event status based on date and time
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
                    'My Activity',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Track your club memberships and events',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Tab Selector
                  _buildTabSelector(),
                ],
              ),
            ),

            // Content based on selected tab
            Expanded(
              child: _buildTabContent(user.uid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    final tabs = ['Clubs', 'Events', 'Sessions', 'Attendance', 'Requests'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2840),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedTab == index;
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF6B2C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabContent(String userId) {
    switch (_selectedTab) {
      case 0:
        return _buildJoinedClubs(userId);
      case 1:
        return _buildRegisteredEvents(userId);
      case 2:
        return _buildClubSessions(userId);
      case 3:
        return _buildAttendanceHistory(userId);
      case 4:
        return _buildJoinRequests(userId);
      default:
        return const SizedBox();
    }
  }

  Widget _buildJoinedClubs(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubJoinRequests')
          .where('studentId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'You haven\'t joined any clubs yet',
                style: TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final requestData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final clubId = requestData['clubId'];
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('clubs').doc(clubId).get(),
              builder: (context, clubSnapshot) {
                if (!clubSnapshot.hasData) {
                  return const SizedBox();
                }

                final clubData = clubSnapshot.data!.data() as Map<String, dynamic>?;
                if (clubData == null) return const SizedBox();

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
                  child: Row(
                    children: [
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
                            Text(
                              clubData['category'] ?? 'General',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 24,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRegisteredEvents(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventRegistrations')
          .where('studentId', isEqualTo: userId)
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No registered events yet',
                style: TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final regDoc = snapshot.data!.docs[index];
            final regData = regDoc.data() as Map<String, dynamic>;
            final eventId = regData['eventId'];
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('events').doc(eventId).get(),
              builder: (context, eventSnapshot) {
                if (!eventSnapshot.hasData) {
                  return const SizedBox();
                }

                final eventData = eventSnapshot.data!.data() as Map<String, dynamic>?;
                if (eventData == null) return const SizedBox();

                final DateTime eventDate = (eventData['date'] as Timestamp).toDate();
                final String actualStatus = _getActualEventStatus(eventData);
                final bool isUpcoming = actualStatus == 'upcoming' || actualStatus == 'ongoing';
                final int attendanceCount = eventData['attendanceCount'] ?? 0;

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('attendance')
                      .doc(eventId)
                      .collection('students')
                      .doc(userId)
                      .snapshots(includeMetadataChanges: true),
                  builder: (context, attendanceSnapshot) {
                    final hasAttended = attendanceSnapshot.hasData && 
                                        attendanceSnapshot.data!.exists;

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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eventData['title'] ?? 'Event',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, color: Colors.grey, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(eventDate),
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.people,
                                      size: 14,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$attendanceCount attending',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (hasAttended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Attended',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isUpcoming && !hasAttended)
                            IconButton(
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
                              icon: const Icon(
                                Icons.qr_code_2,
                                color: Color(0xFFFF6B2C),
                                size: 28,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildClubSessions(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubJoinRequests')
          .where('studentId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .snapshots(includeMetadataChanges: true),
      builder: (context, clubsSnapshot) {
        if (clubsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
          );
        }

        if (!clubsSnapshot.hasData || clubsSnapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Join a club to view sessions',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Get all club IDs the student is a member of
        final clubIds = clubsSnapshot.data!.docs
            .map((doc) => (doc.data() as Map<String, dynamic>)['clubId'] as String)
            .toList();

        if (clubIds.isEmpty) {
          return const Center(
            child: Text('No clubs found', style: TextStyle(color: Colors.grey)),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clubSessions')
              .where('clubId', whereIn: clubIds)
              .snapshots(includeMetadataChanges: true),
          builder: (context, sessionsSnapshot) {
            if (sessionsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
              );
            }

            if (!sessionsSnapshot.hasData || sessionsSnapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      const Text(
                        'No Sessions Yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your clubs haven\'t created any sessions yet',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Sort sessions by date (most recent first)
            final allSessions = sessionsSnapshot.data!.docs.toList();
            allSessions.sort((a, b) {
              final aDate = ((a.data() as Map<String, dynamic>)['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
              final bDate = ((b.data() as Map<String, dynamic>)['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
              return bDate.compareTo(aDate);
            });

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              itemCount: allSessions.length,
              itemBuilder: (context, index) {
                final sessionDoc = allSessions[index];
                final sessionData = sessionDoc.data() as Map<String, dynamic>;
                final sessionId = sessionDoc.id;
                final clubId = sessionData['clubId'];
                final status = sessionData['status'] ?? '';
                final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();
                final sessionDate = (sessionData['date'] as Timestamp?)?.toDate();
                final attendanceCount = sessionData['attendanceCount'] ?? 0;
                
                // Check if session is active and not expired
                final isActive = status == 'active' && 
                                (expiresAt == null || DateTime.now().isBefore(expiresAt));

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(clubId)
                      .get(),
                  builder: (context, clubSnapshot) {
                    if (!clubSnapshot.hasData) {
                      return const SizedBox();
                    }

                    final clubData = clubSnapshot.data!.data() as Map<String, dynamic>?;
                    if (clubData == null) return const SizedBox();

                    final clubName = clubData['name'] ?? 'Unknown Club';

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('clubAttendance')
                          .doc(sessionId)
                          .collection('students')
                          .doc(userId)
                          .snapshots(includeMetadataChanges: true),
                      builder: (context, attendanceSnapshot) {
                        final hasMarkedAttendance = attendanceSnapshot.hasData && 
                                                     attendanceSnapshot.data!.exists;

                        return Card(
                          color: const Color(0xFF1A2332),
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isActive 
                                  ? const Color(0xFFFF6B2C).withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B2C).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.group,
                                        color: Color(0xFFFF6B2C),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            clubName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 14,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  sessionDate != null
                                                      ? DateFormat('MMM dd, yyyy').format(sessionDate)
                                                      : 'Date not set',
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontSize: 12,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.people,
                                                size: 14,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$attendanceCount present',
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Status badge
                                    if (isActive && hasMarkedAttendance)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.green,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Present',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (!isActive && hasMarkedAttendance)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.green,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Present',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (!isActive && !hasMarkedAttendance)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.red,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(
                                              Icons.cancel,
                                              color: Colors.red,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Absent',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                if (isActive) ...[
                                  if (expiresAt != null) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Expires at ${DateFormat('hh:mm a').format(expiresAt)}',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: hasMarkedAttendance
                                          ? null
                                          : () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => StudentSessionScannerScreen(
                                                    clubId: clubId,
                                                    clubName: clubName,
                                                  ),
                                                ),
                                              );
                                            },
                                      icon: Icon(
                                        hasMarkedAttendance
                                            ? Icons.check
                                            : Icons.qr_code_scanner,
                                      ),
                                      label: Text(
                                        hasMarkedAttendance
                                            ? 'Attendance Marked'
                                            : 'Mark Attendance',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: hasMarkedAttendance
                                            ? Colors.grey[700]
                                            : const Color(0xFFFF6B2C),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 16,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          status == 'closed' ? 'Session Closed' : 'Session Ended',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceHistory(String userId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAllAttendanceRecords(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No attendance records yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your attendance will appear here',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final records = snapshot.data!;
        
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final type = record['type'] as String; // 'session' or 'event'
            final checkInTime = record['checkInTime'] as DateTime;
            final title = record['title'] as String;
            final subtitle = record['subtitle'] as String;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2840),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      type == 'session' ? Icons.group : Icons.event,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: type == 'session'
                                    ? const Color(0xFFFF6B2C).withOpacity(0.2)
                                    : Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: type == 'session'
                                      ? const Color(0xFFFF6B2C)
                                      : Colors.blue,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                type == 'session' ? 'SESSION' : 'EVENT',
                                style: TextStyle(
                                  color: type == 'session'
                                      ? const Color(0xFFFF6B2C)
                                      : Colors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Checked in: ${DateFormat('MMM dd, yyyy • hh:mm a').format(checkInTime)}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
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

  Future<List<Map<String, dynamic>>> _fetchAllAttendanceRecords(String userId) async {
    List<Map<String, dynamic>> allRecords = [];

    try {
      debugPrint('===== FETCHING ATTENDANCE FOR USER: $userId =====');
      
      // Fetch session attendance from clubAttendance
      final clubSessionsQuery = await FirebaseFirestore.instance
          .collection('clubSessions')
          .get();
      
      debugPrint('Found ${clubSessionsQuery.docs.length} club sessions');
      
      for (var sessionDoc in clubSessionsQuery.docs) {
        final sessionId = sessionDoc.id;
        final sessionData = sessionDoc.data();
        
        // Check if this user attended this session
        final attendanceDoc = await FirebaseFirestore.instance
            .collection('clubAttendance')
            .doc(sessionId)
            .collection('students')
            .doc(userId)
            .get();
        
        if (attendanceDoc.exists) {
          debugPrint('Found session attendance in session: $sessionId');
          final attendanceData = attendanceDoc.data()!;
          final checkInTime = (attendanceData['checkInTime'] as Timestamp?)?.toDate();
          
          if (checkInTime != null) {
            final clubId = sessionData['clubId'];
            
            // Fetch club details
            final clubDoc = await FirebaseFirestore.instance
                .collection('clubs')
                .doc(clubId)
                .get();
            
            final clubName = clubDoc.exists ? (clubDoc.data()?['name'] ?? 'Unknown Club') : 'Unknown Club';
            final sessionDate = (sessionData['date'] as Timestamp?)?.toDate();
            
            debugPrint('Adding session: $clubName at $checkInTime');
            
            allRecords.add({
              'type': 'session',
              'checkInTime': checkInTime,
              'title': clubName,
              'subtitle': sessionDate != null
                  ? 'Session on ${DateFormat('MMM dd, yyyy').format(sessionDate)}'
                  : 'Club Session',
            });
          }
        }
      }
      
      debugPrint('Found ${allRecords.length} session attendance records');
      
      // Fetch event attendance from attendance collection
      final eventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .get();
      
      debugPrint('Found ${eventsQuery.docs.length} events');
      
      for (var eventDoc in eventsQuery.docs) {
        final eventId = eventDoc.id;
        final eventData = eventDoc.data();
        
        // Check if this user attended this event
        final attendanceDoc = await FirebaseFirestore.instance
            .collection('attendance')
            .doc(eventId)
            .collection('students')
            .doc(userId)
            .get();
        
        if (attendanceDoc.exists) {
          debugPrint('Found event attendance in event: $eventId');
          final attendanceData = attendanceDoc.data()!;
          final checkInTime = (attendanceData['checkInTime'] as Timestamp?)?.toDate();
          
          if (checkInTime != null) {
            final eventTitle = eventData['title'] ?? 'Unknown Event';
            final eventDate = (eventData['date'] as Timestamp?)?.toDate();
            
            debugPrint('Adding event: $eventTitle at $checkInTime');
            
            allRecords.add({
              'type': 'event',
              'checkInTime': checkInTime,
              'title': eventTitle,
              'subtitle': eventDate != null
                  ? DateFormat('MMM dd, yyyy').format(eventDate)
                  : 'Event',
            });
          }
        }
      }

      // Sort by check-in time (most recent first)
      allRecords.sort((a, b) {
        final aTime = a['checkInTime'] as DateTime;
        final bTime = b['checkInTime'] as DateTime;
        return bTime.compareTo(aTime);
      });

      debugPrint('===== TOTAL ATTENDANCE RECORDS: ${allRecords.length} =====');

    } catch (e) {
      debugPrint('===== ERROR FETCHING ATTENDANCE: $e =====');
      debugPrint('Stack trace: ${StackTrace.current}');
    }

    return allRecords;
  }

  Widget _buildJoinRequests(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubJoinRequests')
          .where('studentId', isEqualTo: userId)
          .orderBy('requestedAt', descending: true)
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No join requests yet',
                style: TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final requestData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final clubId = requestData['clubId'];
            final status = requestData['status'] ?? 'pending';
            
            Color statusColor;
            IconData statusIcon;
            
            switch (status) {
              case 'approved':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                break;
              case 'rejected':
                statusColor = Colors.red;
                statusIcon = Icons.cancel;
                break;
              default:
                statusColor = Colors.orange;
                statusIcon = Icons.hourglass_empty;
            }
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('clubs').doc(clubId).get(),
              builder: (context, clubSnapshot) {
                if (!clubSnapshot.hasData) {
                  return const SizedBox();
                }

                final clubData = clubSnapshot.data!.data() as Map<String, dynamic>?;
                if (clubData == null) return const SizedBox();

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2840),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          statusIcon,
                          color: statusColor,
                          size: 24,
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
      },
    );
  }
}
