import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

class EventQRPassScreen extends StatefulWidget {
  final String eventId;

  const EventQRPassScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<EventQRPassScreen> createState() => _EventQRPassScreenState();
}

class _EventQRPassScreenState extends State<EventQRPassScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _eventData;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _checkRegistration();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkRegistration() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    try {
      // Check registration
      final registrationDoc = await FirebaseFirestore.instance
          .collection('eventRegistrations')
          .doc('${widget.eventId}_$userId')
          .get();

      if (!registrationDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'You are not registered for this event.';
        });
        return;
      }

      // Get event data
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();

      if (!eventDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Event not found.';
        });
        return;
      }

      final eventData = eventDoc.data()!;
      final status = eventData['status'] as String?;

      // Check if event is upcoming or ongoing
      if (status != 'upcoming' && status != 'ongoing') {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Event pass is only available for upcoming or ongoing events.';
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _eventData = eventData;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load event data: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

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
          'Event Pass',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF6B2C)),
            onPressed: _checkRegistration,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
            )
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _buildPassView(userId),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B2C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassView(String userId) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Event Details Card
              _buildEventDetailsCard(),
              
              const SizedBox(height: 32),

              // QR Code Section
              _buildQRCodeSection(userId),

              const SizedBox(height: 32),

              // Attendance Status Section
              _buildAttendanceStatus(userId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventDetailsCard() {
    final title = _eventData?['title'] ?? 'Event';
    final date = (_eventData?['date'] as Timestamp?)?.toDate();
    final venue = _eventData?['venue'] ?? 'TBA';
    final status = _eventData?['status'] ?? 'upcoming';
    final clubId = _eventData?['clubId'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6B2C).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusBadge(status),
            ],
          ),
          
          const SizedBox(height: 20),

          // Date & Time
          _buildDetailRow(
            Icons.calendar_today,
            'Date & Time',
            date != null
                ? DateFormat('EEEE, MMM dd, yyyy\nhh:mm a').format(date)
                : 'TBA',
          ),

          const SizedBox(height: 16),

          // Venue
          _buildDetailRow(
            Icons.location_on,
            'Venue',
            venue,
          ),

          const SizedBox(height: 16),

          // Club Name
          if (clubId != null)
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(clubId)
                  .get(),
              builder: (context, snapshot) {
                final clubName = snapshot.hasData && snapshot.data!.data() != null
                    ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? 'Unknown Club'
                    : 'Loading...';
                return _buildDetailRow(
                  Icons.groups,
                  'Club',
                  clubName,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    String badgeText;

    switch (status.toLowerCase()) {
      case 'ongoing':
        badgeColor = Colors.green;
        badgeText = 'Ongoing';
        break;
      case 'upcoming':
        badgeColor = const Color(0xFFFF6B2C);
        badgeText = 'Upcoming';
        break;
      case 'completed':
        badgeColor = Colors.grey;
        badgeText = 'Completed';
        break;
      default:
        badgeColor = Colors.grey;
        badgeText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFFFF6B2C),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQRCodeSection(String userId) {
    final qrData = '${widget.eventId}_$userId';

    return Column(
      children: [
        // QR Code Title
        const Text(
          'Your Event Pass',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),

        // QR Code Container with Glow
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B2C).withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: const Color(0xFFFF6B2C).withOpacity(0.2),
                blurRadius: 50,
                spreadRadius: 10,
              ),
            ],
          ),
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 280,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
          ),
        ),

        const SizedBox(height: 20),

        // Instruction Text
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B2C).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFF6B2C).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_scanner,
                color: Color(0xFFFF6B2C),
                size: 20,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Show this QR to the coordinator',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceStatus(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .doc(widget.eventId)
          .collection('students')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final isCheckedIn = snapshot.hasData && snapshot.data!.exists;
        final checkInTime = (isCheckedIn && snapshot.data!.data() != null)
            ? (snapshot.data!.data() as Map<String, dynamic>)['checkInTime'] as Timestamp?
            : null;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2332),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCheckedIn
                  ? Colors.green.withOpacity(0.3)
                  : const Color(0xFFFF6B2C).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Status Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? Colors.green.withOpacity(0.2)
                      : const Color(0xFFFF6B2C).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCheckedIn ? Icons.check_circle : Icons.schedule,
                  color: isCheckedIn ? Colors.green : const Color(0xFFFF6B2C),
                  size: 48,
                ),
              ),

              const SizedBox(height: 16),

              // Status Text
              Text(
                'Attendance Status',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? Colors.green.withOpacity(0.2)
                      : const Color(0xFFFF6B2C).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCheckedIn ? Colors.green : const Color(0xFFFF6B2C),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCheckedIn ? Icons.check_circle : Icons.schedule,
                      color: isCheckedIn ? Colors.green : const Color(0xFFFF6B2C),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCheckedIn ? 'Checked-In' : 'Not Checked-In',
                      style: TextStyle(
                        color: isCheckedIn ? Colors.green : const Color(0xFFFF6B2C),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Check-in Time
              if (isCheckedIn && checkInTime != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Checked in at ${DateFormat('hh:mm a').format(checkInTime.toDate())}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
