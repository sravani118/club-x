import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/coordinator/report_card.dart';

class ReportsAnalyticsScreen extends StatelessWidget {
  final String clubId;

  const ReportsAnalyticsScreen({
    super.key,
    required this.clubId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reports & Analytics',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Insights and statistics for your club',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 32),

              // Analytics Cards
              StreamBuilder<Map<String, dynamic>>(
                stream: _getAnalyticsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6B2C),
                      ),
                    );
                  }

                  final analytics = snapshot.data ?? {
                    'totalEvents': 0,
                    'averageAttendance': 0.0,
                    'mostActiveMember': 'N/A',
                    'totalParticipations': 0,
                  };

                  return Column(
                    children: [
                      ReportCard(
                        icon: Icons.event,
                        title: 'Total Events Conducted',
                        value: analytics['totalEvents'].toString(),
                        subtitle: 'All time',
                        iconColor: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      ReportCard(
                        icon: Icons.bar_chart,
                        title: 'Average Attendance',
                        value: '${analytics['averageAttendance'].toStringAsFixed(1)}%',
                        subtitle: 'Across all events',
                        iconColor: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      ReportCard(
                        icon: Icons.star,
                        title: 'Most Active Member',
                        value: analytics['mostActiveMember'],
                        subtitle: '${analytics['mostActiveMemberCount']} events attended',
                        iconColor: Colors.purple,
                      ),
                      const SizedBox(height: 16),
                      ReportCard(
                        icon: Icons.people,
                        title: 'Total Participations',
                        value: analytics['totalParticipations'].toString(),
                        subtitle: 'Cumulative across all events',
                        iconColor: const Color(0xFFFF6B2C),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // Monthly Trend Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up,
                          color: Color(0xFFFF6B2C),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Monthly Participation Trend',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1B2D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.insert_chart,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Chart Placeholder',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Integrate charts library for visualization',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Export Options
              const Text(
                'Export Reports',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildExportButton(
                      context,
                      icon: Icons.file_download,
                      label: 'Export CSV',
                      onTap: () => _exportCSV(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildExportButton(
                      context,
                      icon: Icons.event_note,
                      label: 'Event Report',
                      onTap: () => _showEventReport(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF6B2C).withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: const Color(0xFFFF6B2C),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Stream<Map<String, dynamic>> _getAnalyticsStream() {
    return Stream.periodic(const Duration(seconds: 5), (_) async {
      try {
        // Get all completed events
        final eventsSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .where('clubId', isEqualTo: clubId)
            .where('status', isEqualTo: 'completed')
            .get();

        final totalEvents = eventsSnapshot.docs.length;

        // Calculate average attendance
        double averageAttendance = 0.0;
        int totalParticipations = 0;

        if (eventsSnapshot.docs.isNotEmpty) {
          int totalRegistered = 0;
          int totalAttended = 0;

          for (var doc in eventsSnapshot.docs) {
            final data = doc.data();
            totalRegistered += (data['registeredCount'] ?? 0) as int;
            totalAttended += (data['attendanceCount'] ?? 0) as int;
          }

          totalParticipations = totalAttended;

          if (totalRegistered > 0) {
            averageAttendance = (totalAttended / totalRegistered) * 100;
          }
        }

        // Find most active member
        final membersSnapshot = await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('members')
            .get();

        String mostActiveMember = 'N/A';
        int mostActiveMemberCount = 0;

        for (var memberDoc in membersSnapshot.docs) {
          int attendanceCount = 0;

          for (var eventDoc in eventsSnapshot.docs) {
            final attendanceDoc = await FirebaseFirestore.instance
                .collection('attendance')
                .doc(eventDoc.id)
                .collection('attendees')
                .doc(memberDoc.id)
                .get();

            if (attendanceDoc.exists) {
              attendanceCount++;
            }
          }

          if (attendanceCount > mostActiveMemberCount) {
            mostActiveMemberCount = attendanceCount;
            final memberData = memberDoc.data();
            mostActiveMember = memberData['name'] ?? 'Unknown';
          }
        }

        return {
          'totalEvents': totalEvents,
          'averageAttendance': averageAttendance,
          'mostActiveMember': mostActiveMember,
          'mostActiveMemberCount': mostActiveMemberCount,
          'totalParticipations': totalParticipations,
        };
      } catch (e) {
        return {
          'totalEvents': 0,
          'averageAttendance': 0.0,
          'mostActiveMember': 'N/A',
          'mostActiveMemberCount': 0,
          'totalParticipations': 0,
        };
      }
    }).asyncMap((event) => event);
  }

  void _exportCSV(BuildContext context) {
    // TODO: Implement CSV export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('CSV export feature coming soon'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showEventReport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _EventReportBottomSheet(clubId: clubId),
    );
  }
}

// Event Report Bottom Sheet
class _EventReportBottomSheet extends StatelessWidget {
  final String clubId;

  const _EventReportBottomSheet({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2332),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Event-wise Report',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('clubId', isEqualTo: clubId)
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF6B2C),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No events found',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final event = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final registered = event['registeredCount'] ?? 0;
                    final attended = event['attendanceCount'] ?? 0;
                    final attendanceRate = registered > 0
                        ? ((attended / registered) * 100).toStringAsFixed(1)
                        : '0.0';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1B2D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event['title'] ?? 'Untitled',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetric('Registered', registered.toString()),
                              _buildMetric('Attended', attended.toString()),
                              _buildMetric('Rate', '$attendanceRate%'),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6B2C),
          ),
        ),
      ],
    );
  }
}
