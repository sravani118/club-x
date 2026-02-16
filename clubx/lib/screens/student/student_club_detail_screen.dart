import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'student_session_scanner_screen.dart';

class StudentClubDetailScreen extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> clubData;

  const StudentClubDetailScreen({
    super.key,
    required this.clubId,
    required this.clubData,
  });

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2332),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Club Details',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Club Header
            _buildClubHeader(),

            const SizedBox(height: 24),

            // Attendance Stats
            _buildAttendanceStats(userId),

            const SizedBox(height: 24),

            // Mark Attendance Section
            _buildMarkAttendanceSection(context, userId),

            const SizedBox(height: 32),

            // Attendance History
            _buildAttendanceHistory(userId),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildClubHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF6B2C).withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Club Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B2C).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF6B2C),
                width: 2,
              ),
            ),
            child: clubData['logoUrl'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      clubData['logoUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.groups,
                          color: Color(0xFFFF6B2C),
                          size: 40,
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.groups,
                    color: Color(0xFFFF6B2C),
                    size: 40,
                  ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubData['name'] ?? 'Club',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B2C).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    clubData['category'] ?? 'General',
                    style: const TextStyle(
                      color: Color(0xFFFF6B2C),
                      fontSize: 14,
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
  }

  Widget _buildAttendanceStats(String userId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('students')
            .where('studentId', isEqualTo: userId)
            .snapshots(),
        builder: (context, attendanceSnapshot) {
          // Calculate attendance stats
          int totalSessions = 0;
          int attendedSessions = 0;
          DateTime? lastAttendedDate;

          if (attendanceSnapshot.hasData) {
            // Get all sessions for this club
            FirebaseFirestore.instance
                .collection('clubSessions')
                .where('clubId', isEqualTo: clubId)
                .where('status', isEqualTo: 'closed')
                .get()
                .then((sessionsSnapshot) {
              totalSessions = sessionsSnapshot.docs.length;
            });

            // Filter attendance for this club's sessions
            final attendanceRecords = attendanceSnapshot.data!.docs;
            
            for (var record in attendanceRecords) {
              final sessionId = record.reference.parent.parent?.id;
              if (sessionId != null) {
                FirebaseFirestore.instance
                    .collection('clubSessions')
                    .doc(sessionId)
                    .get()
                    .then((sessionDoc) {
                  if (sessionDoc.exists && 
                      sessionDoc.data()?['clubId'] == clubId) {
                    attendedSessions++;
                    
                    final checkInTime = record.data() as Map<String, dynamic>?;
                    final timestamp = checkInTime?['checkInTime'] as Timestamp?;
                    if (timestamp != null) {
                      final date = timestamp.toDate();
                      if (lastAttendedDate == null || date.isAfter(lastAttendedDate!)) {
                        lastAttendedDate = date;
                      }
                    }
                  }
                });
              }
            }
          }

          final attendancePercentage = totalSessions > 0 
              ? ((attendedSessions / totalSessions) * 100).toInt()
              : 0;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF6B2C).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    Icons.percent,
                    '$attendancePercentage%',
                    'Attendance',
                    Colors.green,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Colors.grey[800],
                ),
                Expanded(
                  child: _buildStatCard(
                    Icons.calendar_today,
                    lastAttendedDate != null
                        ? DateFormat('MMM dd').format(lastAttendedDate!)
                        : 'Never',
                    'Last Attended',
                    const Color(0xFFFF6B2C),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMarkAttendanceSection(BuildContext context, String userId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubSessions')
            .where('clubId', isEqualTo: clubId)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, sessionSnapshot) {
          final now = DateTime.now();
          DocumentSnapshot? activeSession;

          // Find a valid active session
          if (sessionSnapshot.hasData && sessionSnapshot.data!.docs.isNotEmpty) {
            for (var doc in sessionSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
              
              if (expiresAt != null && now.isBefore(expiresAt)) {
                activeSession = doc;
                break;
              }
            }
          }

          final hasActiveSession = activeSession != null;

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasActiveSession
                    ? [
                        const Color(0xFFFF6B2C).withOpacity(0.2),
                        const Color(0xFFFF6B2C).withOpacity(0.05),
                      ]
                    : [
                        Colors.grey.withOpacity(0.2),
                        Colors.grey.withOpacity(0.05),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasActiveSession
                    ? const Color(0xFFFF6B2C).withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  hasActiveSession ? Icons.qr_code_scanner : Icons.access_time,
                  size: 64,
                  color: hasActiveSession 
                      ? const Color(0xFFFF6B2C)
                      : Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  hasActiveSession
                      ? 'Active Session Available'
                      : 'No Active Session',
                  style: TextStyle(
                    color: hasActiveSession ? Colors.white : Colors.grey[400],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasActiveSession
                      ? 'Scan the QR code shown by your coordinator'
                      : 'No active session right now',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: hasActiveSession
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentSessionScannerScreen(
                                  clubId: clubId,
                                  clubName: clubData['name'] ?? 'Club',
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: Icon(
                      hasActiveSession ? Icons.qr_code_scanner : Icons.lock,
                    ),
                    label: Text(
                      hasActiveSession
                          ? 'Mark Today\'s Attendance'
                          : 'Session Not Available',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasActiveSession
                          ? const Color(0xFFFF6B2C)
                          : Colors.grey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: hasActiveSession ? 8 : 0,
                      shadowColor: hasActiveSession
                          ? const Color(0xFFFF6B2C).withOpacity(0.5)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttendanceHistory(String userId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('clubSessions')
                .where('clubId', isEqualTo: clubId)
                .orderBy('date', descending: true)
                .limit(30)
                .snapshots(),
            builder: (context, sessionsSnapshot) {
              if (sessionsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
                );
              }

              if (!sessionsSnapshot.hasData || sessionsSnapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2332),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No session history yet',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessionsSnapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final sessionDoc = sessionsSnapshot.data!.docs[index];
                  final sessionData = sessionDoc.data() as Map<String, dynamic>;
                  final sessionId = sessionDoc.id;
                  final date = (sessionData['date'] as Timestamp?)?.toDate();
                  final status = sessionData['status'];

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('clubAttendance')
                        .doc(sessionId)
                        .collection('students')
                        .doc(userId)
                        .get(),
                    builder: (context, attendanceDoc) {
                      final isPresent = attendanceDoc.hasData && 
                                       attendanceDoc.data!.exists;
                      final checkInTime = (isPresent && attendanceDoc.data!.data() != null)
                          ? (attendanceDoc.data!.data() as Map<String, dynamic>)['checkInTime'] as Timestamp?
                          : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2332),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPresent
                                ? Colors.green.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isPresent
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isPresent ? Icons.check_circle : Icons.cancel,
                                color: isPresent ? Colors.green : Colors.grey[600],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    date != null
                                        ? DateFormat('EEEE, MMM dd, yyyy').format(date)
                                        : 'Unknown Date',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isPresent
                                        ? checkInTime != null
                                            ? 'Marked at ${DateFormat('hh:mm a').format(checkInTime.toDate())}'
                                            : 'Present'
                                        : status == 'active' 
                                            ? 'Session Ongoing'
                                            : 'Absent',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isPresent
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isPresent ? 'Present' : 'Absent',
                                style: TextStyle(
                                  color: isPresent ? Colors.green : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
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
          ),
        ],
      ),
    );
  }
}
