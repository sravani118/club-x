import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum AttendanceMode { clubSession, eventAttendance }

class AttendanceQRScreen extends StatefulWidget {
  final String clubId;

  const AttendanceQRScreen({
    super.key,
    required this.clubId,
  });

  @override
  State<AttendanceQRScreen> createState() => _AttendanceQRScreenState();
}

class _AttendanceQRScreenState extends State<AttendanceQRScreen> {
  AttendanceMode _currentMode = AttendanceMode.clubSession;
  
  // Club Session variables
  String? _activeSessionId;
  bool _isSessionActive = false;
  
  // Event Attendance variables
  String? _selectedEventId;
  List<Map<String, dynamic>> _ongoingEvents = [];
  
  // Scanner variables
  MobileScannerController? _cameraController;
  bool _isScanning = false;
  
  // Shared variables
  String? _lastScannedStudent;
  int _attendanceCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOngoingEvents();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _loadOngoingEvents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('clubId', isEqualTo: widget.clubId)
          .where('status', isEqualTo: 'ongoing')
          .get();

      setState(() {
        _ongoingEvents = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'title': doc.data()['title'] ?? 'Unknown Event',
                })
            .toList();
      });
    } catch (e) {
      // Handle error silently
    }
  }


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
                    'QR Attendance',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Mode Toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2332),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildModeButton(
                            'Club Session',
                            AttendanceMode.clubSession,
                          ),
                        ),
                        Expanded(
                          child: _buildModeButton(
                            'Event Attendance',
                            AttendanceMode.eventAttendance,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Stats Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(
                      Icons.check_circle,
                      'Attendance Count',
                      _attendanceCount.toString(),
                      Colors.green,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[800],
                    ),
                    _buildStat(
                      Icons.person,
                      'Last Scanned',
                      _lastScannedStudent ?? 'None',
                      const Color(0xFFFF6B2C),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Content Area
            Expanded(
              child: _currentMode == AttendanceMode.clubSession
                  ? _buildClubSessionMode()
                  : _buildEventAttendanceMode(),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, AttendanceMode mode) {
    final isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () {
        if (_isScanning) {
          _showError('Stop scanning before switching modes');
          return;
        }
        setState(() {
          _currentMode = mode;
          _lastScannedStudent = null;
          _attendanceCount = 0;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B2C) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  // ============ CLUB SESSION MODE ============

  Widget _buildClubSessionMode() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _isSessionActive
          ? _buildActiveSession()
          : _buildStartSessionButton(),
    );
  }

  Widget _buildStartSessionButton() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 80,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 24),
          Text(
            'No Active Session',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _startClubSession,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_isLoading ? 'Starting...' : 'Start Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B2C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSession() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubSessions')
          .doc(_activeSessionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sessionData = snapshot.data?.data() as Map<String, dynamic>?;
        if (sessionData == null) {
          return const Center(child: Text('Session not found'));
        }

        final attendanceCount = sessionData['attendanceCount'] ?? 0;
        
        // Update local count
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _attendanceCount != attendanceCount) {
            setState(() {
              _attendanceCount = attendanceCount;
            });
          }
        });

        return Column(
          children: [
            // Content Area (QR Display or Scanner)
            Expanded(
              child: _isScanning
                  ? _buildScanner()
                  : Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B2C).withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            QrImageView(
                              data: _activeSessionId!,
                              version: QrVersions.auto,
                              size: 250,
                              backgroundColor: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B2C),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Active Club Session',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            
            // Action Buttons Row
            if (!_isScanning) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _startEventScanning,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan Student QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B2C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _endClubSession,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.stop),
                      label: Text(_isLoading ? 'Ending...' : 'End Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _startClubSession() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showError('User not authenticated');
        return;
      }

      final sessionId = FirebaseFirestore.instance
          .collection('clubSessions')
          .doc()
          .id;

      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 15));

      await FirebaseFirestore.instance
          .collection('clubSessions')
          .doc(sessionId)
          .set({
        'clubId': widget.clubId,
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'status': 'active',
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'attendanceCount': 0,
      });

      setState(() {
        _activeSessionId = sessionId;
        _isSessionActive = true;
        _attendanceCount = 0;
        _lastScannedStudent = null;
      });

      _showSuccess('Session started successfully');
    } catch (e) {
      _showError('Failed to start session: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _endClubSession() async {
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('clubSessions')
          .doc(_activeSessionId)
          .update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _activeSessionId = null;
        _isSessionActive = false;
        _attendanceCount = 0;
        _lastScannedStudent = null;
      });

      _showSuccess('Session ended successfully');
    } catch (e) {
      _showError('Failed to end session: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============ EVENT ATTENDANCE MODE ============

  Widget _buildEventAttendanceMode() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Event Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[800]!,
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedEventId,
                hint: Text(
                  'Select Ongoing Event',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                dropdownColor: const Color(0xFF1A2332),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                items: _ongoingEvents.map((event) {
                  return DropdownMenuItem<String>(
                    value: event['id'] as String,
                    child: Text(event['title'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEventId = value;
                    _attendanceCount = 0;
                    _lastScannedStudent = null;
                  });
                  if (value != null) {
                    _loadEventAttendance(value);
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Scanner or Start Button
          Expanded(
            child: _isScanning
                ? _buildScanner()
                : _buildEventScanButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventScanButton() {
    final canScan = _selectedEventId != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: canScan
                    ? [
                        const Color(0xFFFF6B2C).withOpacity(0.3),
                        const Color(0xFFFF6B2C).withOpacity(0.1),
                      ]
                    : [
                        Colors.grey.withOpacity(0.3),
                        Colors.grey.withOpacity(0.1),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(100),
              boxShadow: canScan
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF6B2C).withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ]
                  : [],
            ),
            child: InkWell(
              onTap: canScan ? _startEventScanning : null,
              borderRadius: BorderRadius.circular(100),
              child: Center(
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: canScan ? const Color(0xFFFF6B2C) : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            canScan ? 'Tap to Start Scanning' : 'Select an event first',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: canScan ? Colors.white : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canScan
                ? 'Scan student QR codes for attendance'
                : 'Choose an ongoing event from the dropdown above',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  void _startEventScanning() {
    setState(() {
      _isScanning = true;
      _cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    });
  }

  Future<void> _loadEventAttendance(String eventId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(eventId)
          .collection('students')
          .get();

      setState(() {
        _attendanceCount = snapshot.docs.length;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                MobileScanner(
                  controller: _cameraController,
                  onDetect: _onQRCodeDetected,
                ),
                // Scanner overlay
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF6B2C),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                // Mode indicator
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _currentMode == AttendanceMode.clubSession
                          ? 'Scanning for Club Session'
                          : 'Scanning for Event Attendance',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _isScanning = false;
              _cameraController?.dispose();
              _cameraController = null;
            });
          },
          icon: const Icon(Icons.close),
          label: const Text('Stop Scanning'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onQRCodeDetected(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Prevent rapid scanning
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      if (_currentMode == AttendanceMode.clubSession) {
        // Club Session: code format is "sessionId_studentId"
        await _handleClubSessionScan(code);
      } else {
        // Event Attendance: code format is "eventId_studentId"
        await _handleEventAttendanceScan(code);
      }
    } finally {
      setState(() => _isLoading = false);
      // Small delay to prevent double scans
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _handleClubSessionScan(String code) async {
    try {
      // Parse QR code: sessionId_studentId
      final parts = code.split('_');
      if (parts.length != 2) {
        _showError('Invalid QR code format');
        return;
      }

      final scannedSessionId = parts[0];
      final studentId = parts[1];

      // Verify session matches active session
      if (scannedSessionId != _activeSessionId) {
        _showError('Invalid session QR code');
        return;
      }

      // Get session details
      final sessionDoc = await FirebaseFirestore.instance
          .collection('clubSessions')
          .doc(_activeSessionId)
          .get();

      if (!sessionDoc.exists) {
        _showError('Session not found');
        return;
      }

      final sessionData = sessionDoc.data()!;
      
      // Validate session status
      if (sessionData['status'] != 'active') {
        _showError('Session is not active');
        return;
      }

      // Check if expired
      final expiresAt = (sessionData['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        _showError('Session has expired');
        return;
      }

      // Verify student is member of club
      final membershipQuery = await FirebaseFirestore.instance
          .collection('clubJoinRequests')
          .where('studentId', isEqualTo: studentId)
          .where('clubId', isEqualTo: widget.clubId)
          .where('status', isEqualTo: 'approved')
          .get();

      if (membershipQuery.docs.isEmpty) {
        _showError('Student is not a member of this club');
        return;
      }

      // Check if attendance already marked
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('clubAttendance')
          .doc(_activeSessionId)
          .collection('students')
          .doc(studentId)
          .get();

      if (attendanceDoc.exists) {
        _showError('Attendance already marked for this student');
        return;
      }

      // Get student info
      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();

      final studentName = studentDoc.data()?['name'] ?? 'Unknown Student';

      // Mark attendance
      final batch = FirebaseFirestore.instance.batch();

      // Create attendance record
      batch.set(
        FirebaseFirestore.instance
            .collection('clubAttendance')
            .doc(_activeSessionId)
            .collection('students')
            .doc(studentId),
        {
          'checkInTime': FieldValue.serverTimestamp(),
          'studentId': studentId,
          'studentName': studentName,
        },
      );

      // Increment session attendance count
      batch.update(
        FirebaseFirestore.instance
            .collection('clubSessions')
            .doc(_activeSessionId),
        {
          'attendanceCount': FieldValue.increment(1),
        },
      );

      await batch.commit();

      // Update local state
      setState(() {
        _lastScannedStudent = studentName;
      });

      _showSuccess('✓ Attendance marked for $studentName');
    } catch (e) {
      _showError('Failed to mark attendance: $e');
    }
  }

  Future<void> _handleEventAttendanceScan(String code) async {
    try {
      // Parse QR code: eventId_studentId
      final parts = code.split('_');
      if (parts.length != 2) {
        _showError('Invalid QR code format');
        return;
      }

      final scannedEventId = parts[0];
      final studentId = parts[1];

      // Verify event matches selected event
      if (scannedEventId != _selectedEventId) {
        _showError('QR code is for a different event');
        return;
      }

      // Verify event exists and is ongoing
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventId)
          .get();

      if (!eventDoc.exists) {
        _showError('Event not found');
        return;
      }

      final eventData = eventDoc.data()!;
      
      if (eventData['status'] != 'ongoing') {
        _showError('Event is not currently ongoing');
        return;
      }

      if (eventData['clubId'] != widget.clubId) {
        _showError('Event does not belong to this club');
        return;
      }

      // Check if student is registered for event
      final registrationDoc = await FirebaseFirestore.instance
          .collection('eventRegistrations')
          .doc('${_selectedEventId}_$studentId')
          .get();

      if (!registrationDoc.exists) {
        _showError('Student is not registered for this event');
        return;
      }

      // Check if attendance already marked
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(_selectedEventId)
          .collection('students')
          .doc(studentId)
          .get();

      if (attendanceDoc.exists) {
        _showError('Attendance already marked for this student');
        return;
      }

      // Get student info
      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();

      final studentName = studentDoc.data()?['name'] ?? 'Unknown Student';

      // Mark attendance
      final batch = FirebaseFirestore.instance.batch();

      // Create attendance record
      batch.set(
        FirebaseFirestore.instance
            .collection('attendance')
            .doc(_selectedEventId)
            .collection('students')
            .doc(studentId),
        {
          'checkInTime': FieldValue.serverTimestamp(),
          'studentId': studentId,
          'studentName': studentName,
        },
      );

      // Increment event attendance count
      batch.update(
        FirebaseFirestore.instance.collection('events').doc(_selectedEventId),
        {
          'attendanceCount': FieldValue.increment(1),
        },
      );

      await batch.commit();

      // Update local state
      setState(() {
        _lastScannedStudent = studentName;
        _attendanceCount++;
      });

      _showSuccess('✓ Attendance marked for $studentName');
    } catch (e) {
      _showError('Failed to mark attendance: $e');
    }
  }


  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
