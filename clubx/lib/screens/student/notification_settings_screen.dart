import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isLoading = true;
  bool _clubUpdates = true;
  bool _eventUpdates = true;
  bool _attendanceReminders = true;
  bool _newClubAlerts = false;
  bool _sessionReminders = true;
  bool _emailNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['notificationSettings'] != null) {
          final settings = data['notificationSettings'] as Map<String, dynamic>;
          setState(() {
            _clubUpdates = settings['clubUpdates'] ?? true;
            _eventUpdates = settings['eventUpdates'] ?? true;
            _attendanceReminders = settings['attendanceReminders'] ?? true;
            _newClubAlerts = settings['newClubAlerts'] ?? false;
            _sessionReminders = settings['sessionReminders'] ?? true;
            _emailNotifications = settings['emailNotifications'] ?? false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'notificationSettings': {
          'clubUpdates': _clubUpdates,
          'eventUpdates': _eventUpdates,
          'attendanceReminders': _attendanceReminders,
          'newClubAlerts': _newClubAlerts,
          'sessionReminders': _sessionReminders,
          'emailNotifications': _emailNotifications,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Color(0xFFFF6B2C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1B2D),
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B2C)))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2840).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF6B2C).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                color: Color(0xFFFF6B2C),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Manage your notification preferences',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Push Notifications Section
                        const Text(
                          'Push Notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildNotificationTile(
                          title: 'Club Updates',
                          subtitle: 'Get notified about club announcements',
                          value: _clubUpdates,
                          onChanged: (value) {
                            setState(() => _clubUpdates = value);
                            _saveSettings();
                          },
                        ),
                        const SizedBox(height: 12),

                        _buildNotificationTile(
                          title: 'Event Updates',
                          subtitle: 'Receive updates about registered events',
                          value: _eventUpdates,
                          onChanged: (value) {
                            setState(() => _eventUpdates = value);
                            _saveSettings();
                          },
                        ),
                        const SizedBox(height: 12),

                        _buildNotificationTile(
                          title: 'Session Reminders',
                          subtitle: 'Reminders for upcoming club sessions',
                          value: _sessionReminders,
                          onChanged: (value) {
                            setState(() => _sessionReminders = value);
                            _saveSettings();
                          },
                        ),
                        const SizedBox(height: 12),

                        _buildNotificationTile(
                          title: 'Attendance Reminders',
                          subtitle: 'Reminders to mark your attendance',
                          value: _attendanceReminders,
                          onChanged: (value) {
                            setState(() => _attendanceReminders = value);
                            _saveSettings();
                          },
                        ),
                        const SizedBox(height: 12),

                        _buildNotificationTile(
                          title: 'New Club Alerts',
                          subtitle: 'Get notified when new clubs are created',
                          value: _newClubAlerts,
                          onChanged: (value) {
                            setState(() => _newClubAlerts = value);
                            _saveSettings();
                          },
                        ),
                        const SizedBox(height: 32),

                        // Email Notifications Section
                        const Text(
                          'Email Notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildNotificationTile(
                          title: 'Email Notifications',
                          subtitle: 'Receive important updates via email',
                          value: _emailNotifications,
                          onChanged: (value) {
                            setState(() => _emailNotifications = value);
                            _saveSettings();
                          },
                        ),
                        const SizedBox(height: 24),

                        // Note
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
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFFFF6B2C),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Settings are saved automatically when you toggle options.',
                                  style: TextStyle(
                                    color: Color(0xFFFF6B2C),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNotificationTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF6B2C),
            activeTrackColor: const Color(0xFFFF6B2C).withOpacity(0.5),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}
