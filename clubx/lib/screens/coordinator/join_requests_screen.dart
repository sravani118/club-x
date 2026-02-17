import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class JoinRequestsScreen extends StatefulWidget {
  final String clubId;

  const JoinRequestsScreen({
    super.key,
    required this.clubId,
  });

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  bool _isProcessing = false;

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
                    'Join Requests',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Approve or reject student requests to join your club',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),

            // Requests List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubJoinRequests')
                    .where('clubId', isEqualTo: widget.clubId)
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6B2C),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    debugPrint('❌ Join Requests Error: ${snapshot.error}');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading requests',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please try again later',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {});
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B2C),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B2C).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.inbox_outlined,
                                size: 60,
                                color: Color(0xFFFF6B2C),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'No pending join requests',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'New requests will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Sort requests by requestedAt (newest first)
                  final requests = snapshot.data!.docs.toList()
                    ..sort((a, b) {
                      final aTime = (a.data() as Map<String, dynamic>)['requestedAt'] as Timestamp?;
                      final bTime = (b.data() as Map<String, dynamic>)['requestedAt'] as Timestamp?;
                      
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      
                      return bTime.compareTo(aTime); // Descending order
                    });

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final requestDoc = requests[index];
                      final requestData = requestDoc.data() as Map<String, dynamic>;
                      return _buildRequestCard(
                        context,
                        requestDoc.id,
                        requestData,
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

  Widget _buildRequestCard(
    BuildContext context,
    String requestId,
    Map<String, dynamic> requestData,
  ) {
    final studentId = requestData['studentId'] as String;
    final studentName = requestData['studentName'] ?? 'Student';
    final requestedAt = requestData['requestedAt'] as Timestamp?;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get(),
      builder: (context, userSnapshot) {
        String email = 'Loading...';
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          email = userData?['email'] ?? 'No email';
        }

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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student Info Row
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B2C).withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF6B2C),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        studentName.isNotEmpty
                            ? studentName[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          color: Color(0xFFFF6B2C),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Student Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Requested Date
              if (requestedAt != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B2C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Color(0xFFFF6B2C),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Requested ${_getTimeAgo(requestedAt.toDate())}',
                        style: const TextStyle(
                          color: Color(0xFFFF6B2C),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  // Approve Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _handleApprove(requestId, studentId, studentName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B2C),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle, size: 20),
                      label: Text(
                        _isProcessing ? 'Processing...' : 'Approve',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Reject Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _handleReject(requestId, studentName),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        disabledForegroundColor: Colors.grey[700],
                        side: BorderSide(
                          color: _isProcessing ? Colors.grey[700]! : Colors.red,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.cancel, size: 20),
                      label: const Text(
                        'Reject',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _handleApprove(
    String requestId,
    String studentId,
    String studentName,
  ) async {
    setState(() => _isProcessing = true);

    try {
      // 1. Get club data to check capacity
      final clubDoc = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .get();

      if (!clubDoc.exists) {
        throw Exception('Club not found');
      }

      final clubData = clubDoc.data()!;
      final currentMembers = clubData['currentMembers'] ?? 0;
      final maxMembers = clubData['maxMembers'] ?? 0;

      // 2. Check club capacity
      if (currentMembers >= maxMembers) {
        if (mounted) {
          _showSnackBar(
            'Club is at full capacity ($maxMembers members)',
            Colors.red,
          );
        }
        return;
      }

      // 3. Check if student is already a member
      final existingMember = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('members')
          .doc(studentId)
          .get();

      if (existingMember.exists) {
        if (mounted) {
          _showSnackBar(
            '$studentName is already a member',
            Colors.orange,
          );
        }
        return;
      }

      // 4. Fetch full user details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;

      // 5. Perform batch write for consistency
      final batch = FirebaseFirestore.instance.batch();

      // Add student to club members subcollection with full details
      final memberRef = FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('members')
          .doc(studentId);
      batch.set(memberRef, {
        'studentId': studentId,
        'name': userData['name'] ?? studentName,
        'email': userData['email'] ?? '',
        'studentId_field': userData['studentId'] ?? '',
        'department': userData['department'] ?? '',
        'photoUrl': userData['photoUrl'],
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Increment club currentMembers
      final clubRef = FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId);
      batch.update(clubRef, {
        'currentMembers': FieldValue.increment(1),
      });

      // Update join request status
      final requestRef = FirebaseFirestore.instance
          .collection('clubJoinRequests')
          .doc(requestId);
      batch.update(requestRef, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Commit batch
      await batch.commit();

      if (mounted) {
        _showSnackBar(
          '✓ $studentName approved successfully!',
          Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Error: ${e.toString()}',
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleReject(String requestId, String studentName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2840),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Reject Request?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to reject $studentName\'s request to join?',
          style: TextStyle(
            color: Colors.grey[400],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Reject',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      // Update request status to rejected
      await FirebaseFirestore.instance
          .collection('clubJoinRequests')
          .doc(requestId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnackBar(
          'Request rejected',
          Colors.orange,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Error: ${e.toString()}',
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
