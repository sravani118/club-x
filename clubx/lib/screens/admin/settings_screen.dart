import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/primary_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _maxClubsController = TextEditingController();
  final _maxMembersController = TextEditingController();
  final _maxRegistrationsController = TextEditingController();
  final _qrValidityController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('systemSettings')
          .doc('limits')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _maxClubsController.text = (data['maxClubs'] ?? 20).toString();
        _maxMembersController.text = (data['maxMembersPerClub'] ?? 60).toString();
        _maxRegistrationsController.text = (data['maxEventRegistrations'] ?? 200).toString();
        _qrValidityController.text = (data['qrValidityMinutes'] ?? 5).toString();
      } else {
        // Set default values
        _maxClubsController.text = '20';
        _maxMembersController.text = '60';
        _maxRegistrationsController.text = '200';
        _qrValidityController.text = '5';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // Set defaults on error
      _maxClubsController.text = '20';
      _maxMembersController.text = '60';
      _maxRegistrationsController.text = '200';
      _qrValidityController.text = '5';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _maxClubsController.dispose();
    _maxMembersController.dispose();
    _maxRegistrationsController.dispose();
    _qrValidityController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('systemSettings')
          .doc('limits')
          .set({
        'maxClubs': int.parse(_maxClubsController.text),
        'maxMembersPerClub': int.parse(_maxMembersController.text),
        'maxEventRegistrations': int.parse(_maxRegistrationsController.text),
        'qrValidityMinutes': int.parse(_qrValidityController.text),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved successfully!'),
            backgroundColor: const Color(0xFFFF6B2C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF6B2C),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Controls',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure system limits and settings',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 32),
            _buildSettingField(
              controller: _maxClubsController,
              label: 'Maximum Clubs',
              hint: 'Enter max clubs',
              icon: Icons.groups,
            ),
            const SizedBox(height: 20),
            _buildSettingField(
              controller: _maxMembersController,
              label: 'Max Members per Club',
              hint: 'Enter max members',
              icon: Icons.people,
            ),
            const SizedBox(height: 20),
            _buildSettingField(
              controller: _maxRegistrationsController,
              label: 'Max Event Registrations',
              hint: 'Enter max registrations',
              icon: Icons.app_registration,
            ),
            const SizedBox(height: 20),
            _buildSettingField(
              controller: _qrValidityController,
              label: 'QR Validity Time (minutes)',
              hint: 'Enter validity time',
              icon: Icons.qr_code,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: 'Save Settings',
              onPressed: () => _saveSettings(),
              isLoading: _isSaving,
            ),
            const SizedBox(height: 32),
            const Divider(color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'System Information',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('App Version', '1.0.0'),
            _buildInfoRow('Database Status', 'Connected'),
            _buildInfoRow('Storage Used', '245 MB / 1 GB'),
            _buildInfoRow('Last Backup', '2 hours ago'),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            if (int.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: Icon(icon, color: Colors.grey[400]),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF6B2C), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red[700]!, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red[700]!, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
