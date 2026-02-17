import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

enum AttendanceMode { clubSession, eventAttendance, viewSessions }

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
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('clubSessions')
          .where('clubId', isEqualTo: widget.clubId)
          .where('status', isEqualTo: 'active')
          .get();

      // Find active session from today
      DocumentSnapshot? todaySession;
      for (var doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final sessionDate = (data['date'] as Timestamp?)?.toDate();
        
        if (sessionDate != null) {
          final sessionDay = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
          if (sessionDay.isAtSameMomentAs(startOfDay)) {
            todaySession = doc;
            break;
          }
        }
      }

      if (todaySession != null && mounted) {
        final sessionData = todaySession.data() as Map<String, dynamic>;
        final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();
        
        // Check if session is actually expired
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          // Close expired session
          await FirebaseFirestore.instance
              .collection('clubSessions')
              .doc(todaySession.id)
              .update({
            'status': 'closed',
            'closedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Load the existing active session
          setState(() {
            _activeSessionId = todaySession!.id;
            _isSessionActive = true;
            _attendanceCount = sessionData['attendanceCount'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking existing session: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

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
      debugPrint('❌ [EVENT STATUS ERROR] ${eventData['title']}: $e');
      return eventData['status'] ?? 'upcoming';
    }
  }

  Future<void> _loadOngoingEvents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('clubId', isEqualTo: widget.clubId)
          .get();

      // Filter events by actual status calculated from date/time
      final ongoingEvents = snapshot.docs.where((doc) {
        final data = doc.data();
        final actualStatus = _getActualEventStatus(data);
        return actualStatus == 'ongoing';
      }).toList();

      setState(() {
        _ongoingEvents = ongoingEvents
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
                            'Sessions',
                            AttendanceMode.clubSession,
                          ),
                        ),
                        Expanded(
                          child: _buildModeButton(
                            'Events',
                            AttendanceMode.eventAttendance,
                          ),
                        ),
                        Expanded(
                          child: _buildModeButton(
                            'History',
                            AttendanceMode.viewSessions,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Stats Card (only show for active attendance modes)
            if (_currentMode != AttendanceMode.viewSessions) ...[
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
            ],

            // Content Area
            Expanded(
              child: _currentMode == AttendanceMode.clubSession
                  ? _buildClubSessionMode()
                  : _currentMode == AttendanceMode.eventAttendance
                      ? _buildEventAttendanceMode()
                      : _buildSessionsHistoryView(),
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
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sessionData = snapshot.data?.data() as Map<String, dynamic>?;
        if (sessionData == null) {
          return const Center(child: Text('Session not found'));
        }

        // Check if session has expired
        final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();
        final isExpired = expiresAt != null && DateTime.now().isAfter(expiresAt);
        final status = sessionData['status'] ?? 'active';

        // Auto-close expired sessions
        if (isExpired && status == 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _autoCloseExpiredSession();
          });
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

      // Check if there's already an active session for this club
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final existingSessionsSnapshot = await FirebaseFirestore.instance
          .collection('clubSessions')
          .where('clubId', isEqualTo: widget.clubId)
          .where('status', isEqualTo: 'active')
          .get();

      // Check if any active session is from today
      for (var doc in existingSessionsSnapshot.docs) {
        final data = doc.data();
        final sessionDate = (data['date'] as Timestamp?)?.toDate();
        
        if (sessionDate != null) {
          final sessionDay = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
          if (sessionDay.isAtSameMomentAs(startOfDay)) {
            _showError('A session is already active today. Please end it first.');
            setState(() => _isLoading = false);
            return;
          }
        }
      }

      final sessionId = FirebaseFirestore.instance
          .collection('clubSessions')
          .doc()
          .id;

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

  Future<void> _autoCloseExpiredSession() async {
    if (_activeSessionId == null || !mounted) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('clubSessions')
          .doc(_activeSessionId)
          .update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _activeSessionId = null;
          _isSessionActive = false;
          _attendanceCount = 0;
          _lastScannedStudent = null;
        });

        _showError('Session has expired and was automatically closed');
      }
    } catch (e) {
      debugPrint('Failed to auto-close session: $e');
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
      
      // Calculate actual event status dynamically
      final actualStatus = _getActualEventStatus(eventData);
      if (actualStatus != 'ongoing') {
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

  // ============ SESSIONS HISTORY VIEW ============

  Widget _buildSessionsHistoryView() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubSessions')
            .where('clubId', isEqualTo: widget.clubId)
            .snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          // Debug logging
          debugPrint('📊 [SESSIONS HISTORY] Connection: ${snapshot.connectionState}');
          debugPrint('📊 [SESSIONS HISTORY] Has data: ${snapshot.hasData}');
          debugPrint('📊 [SESSIONS HISTORY] Has error: ${snapshot.hasError}');
          if (snapshot.hasData) {
            debugPrint('📊 [SESSIONS HISTORY] Docs count: ${snapshot.data!.docs.length}');
          }
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B2C)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error Loading Sessions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey[600],
                  ),
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
                    'Sessions will appear here once created.\nGo to "Sessions" tab to start a new session.',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentMode = AttendanceMode.clubSession;
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Start Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B2C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Sort sessions by date (most recent first)
          final sessions = snapshot.data!.docs.toList();
          sessions.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            
            final aDate = (aData['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final bDate = (bData['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
            
            return bDate.compareTo(aDate); // Descending order
          });

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final sessionDoc = sessions[index];
              final sessionData = sessionDoc.data() as Map<String, dynamic>;
              final sessionId = sessionDoc.id;
              final status = sessionData['status'] ?? 'unknown';
              final date = (sessionData['date'] as Timestamp?)?.toDate();
              final createdAt = (sessionData['createdAt'] as Timestamp?)?.toDate();
              final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();
              final attendanceCount = sessionData['attendanceCount'] ?? 0;

              final isActive = status == 'active' && 
                             expiresAt != null && 
                             DateTime.now().isBefore(expiresAt);

              return Card(
                color: const Color(0xFF1A2332),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isActive 
                        ? const Color(0xFFFF6B2C) 
                        : Colors.grey.withOpacity(0.2),
                    width: isActive ? 2 : 1,
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFFFF6B2C).withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isActive ? Icons.radio_button_checked : Icons.history,
                              color: isActive ? const Color(0xFFFF6B2C) : Colors.grey,
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
                                    Text(
                                      date != null
                                          ? DateFormat('MMM dd, yyyy').format(date)
                                          : 'Unknown Date',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.grey.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isActive ? Colors.green : Colors.grey,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        isActive ? 'ACTIVE' : status.toUpperCase(),
                                        style: TextStyle(
                                          color: isActive ? Colors.green : Colors.grey,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (createdAt != null)
                                  Text(
                                    'Started: ${DateFormat('hh:mm a').format(createdAt)}',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSessionStat(
                              Icons.people,
                              'Attendance',
                              attendanceCount.toString(),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[800],
                          ),
                          Expanded(
                            child: _buildSessionStat(
                              Icons.timer,
                              'Expires',
                              expiresAt != null
                                  ? DateFormat('hh:mm a').format(expiresAt)
                                  : 'N/A',
                            ),
                          ),
                        ],
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _activeSessionId = sessionId;
                                _isSessionActive = true;
                                _attendanceCount = attendanceCount;
                                _currentMode = AttendanceMode.clubSession;
                              });
                            },
                            icon: const Icon(Icons.qr_code),
                            label: const Text('Open Session'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B2C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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
      ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFF6B2C), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 11,
          ),
        ),
      ],
    );
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
