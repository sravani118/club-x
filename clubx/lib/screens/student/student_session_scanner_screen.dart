import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class StudentSessionScannerScreen extends StatefulWidget {
  final String clubId;
  final String clubName;

  const StudentSessionScannerScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<StudentSessionScannerScreen> createState() =>
      _StudentSessionScannerScreenState();
}

class _StudentSessionScannerScreenState
    extends State<StudentSessionScannerScreen> {
  MobileScannerController? _cameraController;
  bool _isProcessing = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2332),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan Session QR',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          // Scanner
          Column(
            children: [
              // Instructions
              Container(
                padding: const EdgeInsets.all(24),
                color: const Color(0xFF1A2332),
                child: Column(
                  children: [
                    Text(
                      widget.clubName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Point your camera at the QR code displayed by your coordinator',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Camera View
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFFF6B2C),
                      width: 3,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: MobileScanner(
                      controller: _cameraController,
                      onDetect: _onQRCodeDetected,
                    ),
                  ),
                ),
              ),

              // Scanning Indicator
              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2332),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessing) ...[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF6B2C),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Validating...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.qr_code_scanner,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Align QR code within frame',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Success Overlay
          if (_isSuccess)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2332),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.green,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 80,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Attendance Marked Successfully!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your attendance has been recorded for today\'s session',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onQRCodeDetected(BarcodeCapture capture) async {
    if (_isProcessing || _isSuccess) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      await _validateAndMarkAttendance(code);
    } catch (e) {
      // Error already shown in _validateAndMarkAttendance
    } finally {
      if (mounted && !_isSuccess) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _validateAndMarkAttendance(String sessionId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showError('User not authenticated');
      return;
    }

    try {
      // 1. Fetch session document
      final sessionDoc = await FirebaseFirestore.instance
          .collection('clubSessions')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        _showError('Invalid or expired session');
        return;
      }

      final sessionData = sessionDoc.data()!;

      // 2. Validate session status
      if (sessionData['status'] != 'active') {
        _showError('Session is not active');
        return;
      }

      // 3. Validate expiry time
      final expiresAt = (sessionData['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        _showError('Session has expired');
        return;
      }

      // 4. Validate club match
      if (sessionData['clubId'] != widget.clubId) {
        _showError('This QR code is for a different club');
        return;
      }

      // 5. Verify student is member of this club
      final membershipQuery = await FirebaseFirestore.instance
          .collection('clubJoinRequests')
          .where('studentId', isEqualTo: userId)
          .where('clubId', isEqualTo: widget.clubId)
          .where('status', isEqualTo: 'approved')
          .get();

      if (membershipQuery.docs.isEmpty) {
        _showError('You are not a member of this club');
        return;
      }

      // 6. Check if attendance already marked
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('clubAttendance')
          .doc(sessionId)
          .collection('students')
          .doc(userId)
          .get();

      if (attendanceDoc.exists) {
        _showError('Attendance already marked');
        return;
      }

      // 7. Get student info
      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final studentName = studentDoc.data()?['name'] ?? 'Unknown Student';

      // 8. Mark attendance using batch write
      final batch = FirebaseFirestore.instance.batch();

      // Create attendance record
      batch.set(
        FirebaseFirestore.instance
            .collection('clubAttendance')
            .doc(sessionId)
            .collection('students')
            .doc(userId),
        {
          'studentId': userId,
          'studentName': studentName,
          'checkInTime': FieldValue.serverTimestamp(),
        },
      );

      // Increment session attendance count
      batch.update(
        FirebaseFirestore.instance
            .collection('clubSessions')
            .doc(sessionId),
        {
          'attendanceCount': FieldValue.increment(1),
        },
      );

      await batch.commit();

      // 9. Show success animation
      setState(() => _isSuccess = true);

      // 10. Close screen after delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to mark attendance: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    // Stop camera temporarily
    _cameraController?.stop();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        title: Row(
          children: const [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 12),
            Text(
              'Error',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Restart camera
              _cameraController?.start();
            },
            child: const Text(
              'Try Again',
              style: TextStyle(color: Color(0xFFFF6B2C)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close scanner screen
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
