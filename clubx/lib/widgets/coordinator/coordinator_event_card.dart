import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CoordinatorEventCard extends StatelessWidget {
  final String eventId;
  final String title;
  final String description;
  final DateTime date;
  final String venue;
  final int maxCapacity;
  final int registeredCount;
  final int attendanceCount;
  final String status; // upcoming, ongoing, completed
  final String? bannerUrl;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewRegistrations;
  final VoidCallback? onChangeStatus;

  const CoordinatorEventCard({
    super.key,
    required this.eventId,
    required this.title,
    required this.description,
    required this.date,
    required this.venue,
    required this.maxCapacity,
    required this.registeredCount,
    required this.attendanceCount,
    required this.status,
    this.bannerUrl,
    this.onEdit,
    this.onDelete,
    this.onViewRegistrations,
    this.onChangeStatus,
  });

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'upcoming':
        return Colors.blue;
      case 'ongoing':
        return const Color(0xFFFF6B2C);
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Event Banner
          if (bannerUrl != null && bannerUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Image.network(
                bannerUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderBanner();
                },
              ),
            )
          else
            _buildPlaceholderBanner(),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatusColor(),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date and Time
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Color(0xFFFF6B2C),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(date),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Venue
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Color(0xFFFF6B2C),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        venue,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats Row
                Row(
                  children: [
                    _buildStat(
                      Icons.app_registration,
                      'Registered',
                      '$registeredCount / $maxCapacity',
                    ),
                    const SizedBox(width: 24),
                    _buildStat(
                      Icons.check_circle_outline,
                      'Attended',
                      attendanceCount.toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    if (onEdit != null)
                      _buildActionButton(
                        icon: Icons.edit,
                        label: 'Edit',
                        onTap: onEdit!,
                      ),
                    if (onEdit != null) const SizedBox(width: 8),
                    if (onViewRegistrations != null)
                      _buildActionButton(
                        icon: Icons.people,
                        label: 'Registrations',
                        onTap: onViewRegistrations!,
                      ),
                    if (onViewRegistrations != null) const SizedBox(width: 8),
                    if (onDelete != null)
                      _buildActionButton(
                        icon: Icons.delete,
                        label: 'Delete',
                        onTap: onDelete!,
                        isDestructive: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderBanner() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B2C).withOpacity(0.3),
            const Color(0xFF0F1B2D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.event,
          size: 48,
          color: Color(0xFFFF6B2C),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFFFF6B2C),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : const Color(0xFFFF6B2C).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDestructive
                  ? Colors.red.withOpacity(0.3)
                  : const Color(0xFFFF6B2C).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isDestructive ? Colors.red : const Color(0xFFFF6B2C),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? Colors.red : const Color(0xFFFF6B2C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
