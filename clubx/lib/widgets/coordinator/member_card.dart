import 'package:flutter/material.dart';

class MemberCard extends StatelessWidget {
  final String name;
  final String email;
  final String avatarUrl;
  final double attendanceRate;
  final VoidCallback? onRemove;

  const MemberCard({
    super.key,
    required this.name,
    required this.email,
    this.avatarUrl = '',
    required this.attendanceRate,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFFF6B2C).withOpacity(0.2),
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B2C),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          
          // Member Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: attendanceRate >= 75
                          ? Colors.green
                          : attendanceRate >= 50
                              ? Colors.orange
                              : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${attendanceRate.toStringAsFixed(0)}% attendance',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Remove Button (Optional)
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(
                Icons.remove_circle_outline,
                color: Colors.redAccent,
              ),
              tooltip: 'Remove member',
            ),
        ],
      ),
    );
  }
}
