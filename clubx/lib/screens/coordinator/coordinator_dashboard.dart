import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'overview_screen.dart';
import 'join_requests_screen.dart';
import 'members_management_screen.dart';
import 'event_management_screen.dart';
import 'attendance_qr_screen.dart';
import 'reports_analytics_screen.dart';
import 'edit_profile_screen.dart';

class CoordinatorDashboard extends StatefulWidget {
  const CoordinatorDashboard({super.key});

  @override
  State<CoordinatorDashboard> createState() => _CoordinatorDashboardState();
}

class _CoordinatorDashboardState extends State<CoordinatorDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkUserAuth();
  }

  Future<void> _checkUserAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _navigateToLanding();
    }
  }

  Stream<Map<String, dynamic>?> _getUserDataStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .map((doc) {
      if (doc.metadata.hasPendingWrites) {
        debugPrint('⏳ [COORDINATOR] Pending writes');
      }
      if (doc.metadata.isFromCache) {
        debugPrint('💾 [COORDINATOR] Data from cache');
      } else {
        debugPrint('🌐 [COORDINATOR] Data from server');
      }
      
      if (!doc.exists) return null;
      
      final userData = doc.data()!;
      final userRole = (userData['role'] ?? '').toString().trim().toLowerCase();
      
      // Verify user is a coordinator
      if (userRole != 'coordinator') {
        return null;
      }
      
      debugPrint('✅ [COORDINATOR] User data updated: clubId=${userData['clubId']}');
      
      return userData;
    });
  }

  void _navigateToLanding() {
    if (mounted) {
      context.go('/landing');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildErrorScreen(String title, String error, VoidCallback onRetry) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Error Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Error Message
                Text(
                  'Something went wrong while loading data.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[400],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Error Details (collapsible)
                ExpansionTile(
                  title: Text(
                    'Error Details',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                  iconColor: Colors.grey[500],
                  collapsedIconColor: Colors.grey[500],
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Try Again Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B2C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          context.go('/landing');
                        }
                      } catch (e) {
                        _showError('Logout failed: \${e.toString()}');
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                      side: BorderSide(color: Colors.grey[700]!, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      Future.microtask(() => _navigateToLanding());
      return const Scaffold(
        backgroundColor: Color(0xFF0F1B2D),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF6B2C),
          ),
        ),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _getUserDataStream(),
      builder: (context, snapshot) {
        // Handle errors with retry option
        if (snapshot.hasError) {
          debugPrint('❌ [COORDINATOR] Stream error: ${snapshot.error}');
          return _buildErrorScreen(
            'Unable to load coordinator data',
            snapshot.error.toString(),
            () => setState(() {}), // Retry by rebuilding widget
          );
        }

        // Show loading while waiting for data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F1B2D),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B2C),
              ),
            ),
          );
        }

        // If user data is null or user is not a coordinator, navigate away
        if (snapshot.data == null) {
          Future.microtask(() => _navigateToLanding());
          return const Scaffold(
            backgroundColor: Color(0xFF0F1B2D),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B2C),
              ),
            ),
          );
        }

        final userData = snapshot.data!;
        final coordinatorName = userData['name'] ?? 'Coordinator';
        final coordinatorEmail = userData['email'] ?? user.email ?? '';
        final clubId = userData['clubId'];

        // Comprehensive debug logging
        debugPrint('═══════════════════════════════════════');
        debugPrint('👤 [COORDINATOR] User data received');
        debugPrint('📧 [COORDINATOR] Email: $coordinatorEmail');
        debugPrint('👔 [COORDINATOR] Name: $coordinatorName');
        debugPrint('📋 [COORDINATOR] clubId RAW value: "$clubId"');
        debugPrint('🔍 [COORDINATOR] clubId type: ${clubId.runtimeType}');
        debugPrint('❓ [COORDINATOR] clubId is null: ${clubId == null}');
        if (clubId != null) {
          debugPrint('📏 [COORDINATOR] clubId toString: "${clubId.toString()}"');
          debugPrint('📏 [COORDINATOR] clubId length: ${clubId.toString().length}');
          debugPrint('📏 [COORDINATOR] clubId trimmed length: ${clubId.toString().trim().length}');
          debugPrint('❌ [COORDINATOR] clubId isEmpty: ${clubId.toString().isEmpty}');
          debugPrint('❌ [COORDINATOR] clubId trim isEmpty: ${clubId.toString().trim().isEmpty}');
        }
        debugPrint('═══════════════════════════════════════');

        // If no club assigned yet, show waiting screen
        if (clubId == null || clubId.toString().trim().isEmpty) {
          debugPrint('⚠️ [COORDINATOR] ❌ NO CLUB ASSIGNED - Showing waiting screen');
          return _buildWaitingScreen(coordinatorName);
        }

        // User has a club assigned, load club data and show dashboard
        debugPrint('✅ [COORDINATOR] ✅ CLUB ASSIGNED: $clubId - Loading dashboard');
        return _buildDashboardWithClub(clubId.toString(), coordinatorName, coordinatorEmail);
      },
    );
  }

  Widget _buildWaitingScreen(String coordinatorName) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header with logo and profile
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Logo
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Coordinator Dashboard',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _showProfileBottomSheet(coordinatorName, 'Not Assigned'),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final profileImageUrl = snapshot.data?.data() != null
                            ? (snapshot.data!.data() as Map<String, dynamic>)['profileImage'] as String?
                            : null;
                        
                        return CircleAvatar(
                          backgroundColor: const Color(0xFFFF6B2C).withOpacity(0.2),
                          radius: 20,
                          backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                              ? NetworkImage(profileImageUrl)
                              : null,
                          child: profileImageUrl == null || profileImageUrl.isEmpty
                              ? Text(
                                  coordinatorName.isNotEmpty
                                      ? coordinatorName[0].toUpperCase()
                                      : 'C',
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B2C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
              
              // Waiting message
              Expanded(
                child: Center(
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
                          Icons.pending_actions,
                          size: 60,
                          color: Color(0xFFFF6B2C),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Waiting for Club Assignment',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your coordinator account has been created.\nPlease contact the admin to assign you to a club.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[400],
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      // Auto-refresh message
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B2C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF6B2C).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Color(0xFFFF6B2C),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'This page updates automatically',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Check Again Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            debugPrint('🔄 [COORDINATOR] Manual refresh triggered');
                            setState(() {}); // Force rebuild to fetch latest data
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'Check Again',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B2C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Logout button
                      TextButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardWithClub(
    String clubId,
    String coordinatorName,
    String coordinatorEmail,
  ) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('clubs').doc(clubId).get(),
      builder: (context, clubSnapshot) {
        // Handle errors with retry option
        if (clubSnapshot.hasError) {
          debugPrint('❌ [COORDINATOR] Club load error: ${clubSnapshot.error}');
          return _buildErrorScreen(
            'Unable to load club data',
            clubSnapshot.error.toString(),
            () => setState(() {}), // Retry by rebuilding widget
          );
        }

        if (!clubSnapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F1B2D),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B2C),
              ),
            ),
          );
        }

        String clubName = 'Unknown Club';
        if (clubSnapshot.data?.exists == true) {
          final clubData = clubSnapshot.data?.data() as Map<String, dynamic>?;
          clubName = clubData?['name'] ?? 'Unknown Club';
        } else {
          debugPrint('⚠️ [COORDINATOR] Club document does not exist: $clubId');
        }

        return _buildMainDashboard(clubId, clubName, coordinatorName);
      },
    );
  }

  Widget _buildMainDashboard(
    String clubId,
    String clubName,
    String coordinatorName,
  ) {
    final screens = [
      CoordinatorOverviewScreen(
        clubId: clubId,
        coordinatorName: coordinatorName,
      ),
      JoinRequestsScreen(clubId: clubId),
      MembersManagementScreen(clubId: clubId),
      EventManagementScreen(clubId: clubId),
      AttendanceQRScreen(clubId: clubId),
      ReportsAnalyticsScreen(clubId: clubId),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: _currentIndex == 0 ? _buildAppBar(clubName, coordinatorName) : null,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar(String clubName, String coordinatorName) {
    return AppBar(
      backgroundColor: const Color(0xFF0F1B2D),
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'images/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coordinator Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            clubName,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () => _showProfileBottomSheet(coordinatorName, clubName),
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final profileImageUrl = snapshot.data?.data() != null
                    ? (snapshot.data!.data() as Map<String, dynamic>)['profileImage'] as String?
                    : null;
                
                return CircleAvatar(
                  backgroundColor: const Color(0xFFFF6B2C).withOpacity(0.2),
                  radius: 20,
                  backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? NetworkImage(profileImageUrl)
                      : null,
                  child: profileImageUrl == null || profileImageUrl.isEmpty
                      ? Text(
                          coordinatorName.isNotEmpty
                              ? coordinatorName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            color: Color(0xFFFF6B2C),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A2332),
        selectedItemColor: const Color(0xFFFF6B2C),
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
        ),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'Members',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
        ],
      ),
    );
  }

  void _showProfileBottomSheet(String coordinatorName, String clubName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Load user profile image
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    final profileImageUrl = userDoc.data()?['profileImage'] as String?;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A2332),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Profile Avatar
              CircleAvatar(
                backgroundColor: const Color(0xFFFF6B2C).withOpacity(0.2),
                radius: 40,
                backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
                child: profileImageUrl == null || profileImageUrl.isEmpty
                    ? Text(
                        coordinatorName.isNotEmpty
                            ? coordinatorName[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: Color(0xFFFF6B2C),
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),

              // Coordinator Name
              Text(
                coordinatorName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              // Email
              Text(
                user.email ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),

              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B2C).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF6B2C),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'COORDINATOR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B2C),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Club Information
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1B2D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Club',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      clubName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Edit Profile Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CoordinatorEditProfileScreen(),
                      ),
                    );
                    // Refresh if profile was updated
                    if (result == true && mounted) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
              const SizedBox(height: 12),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // Clear navigation stack and go to landing
        context.go('/landing');
      }
    } catch (e) {
      _showError('Logout failed: ${e.toString()}');
    }
  }
}
