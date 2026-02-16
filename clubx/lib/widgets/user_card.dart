import 'package:flutter/material.dart';

class UserCard extends StatelessWidget {
  final String name;
  final String email;
  final String currentRole;
  final Function(String) onRoleChange;
  final VoidCallback onRemove;

  const UserCard({
    super.key,
    required this.name,
    required this.email,
    required this.currentRole,
    required this.onRoleChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFFF6B2C).withOpacity(0.2),
                child: Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFFF6B2C),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              _buildRoleBadge(currentRole),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1B2D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentRole,
                      dropdownColor: const Color(0xFF1A2332),
                      style: const TextStyle(color: Colors.white),
                      items: ['student', 'coordinator', 'subCoordinator', 'admin']
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Text(
                                  _formatRoleName(role),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onRoleChange(value);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRoleName(String role) {
    switch (role) {
      case 'student':
        return 'Student';
      case 'coordinator':
        return 'Coordinator';
      case 'subCoordinator':
        return 'Sub Coordinator';
      case 'admin':
        return 'Admin';
      default:
        return role[0].toUpperCase() + role.substring(1);
    }
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    switch (role.toLowerCase()) {
      case 'admin':
        badgeColor = Colors.red;
        break;
      case 'coordinator':
        badgeColor = const Color(0xFFFF6B2C);
        break;
      case 'subcoordinator':
        badgeColor = Colors.blue;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Text(
        _formatRoleName(role),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }
}
