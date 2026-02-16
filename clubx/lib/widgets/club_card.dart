import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClubCard extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String category;
  final int currentMembers;
  final int maxMembers;
  final String status;
  final String? logoUrl;
  final String mainCoordinatorId;
  final List<String> subCoordinatorIds;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const ClubCard({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.category,
    required this.currentMembers,
    required this.maxMembers,
    required this.status,
    this.logoUrl,
    required this.mainCoordinatorId,
    required this.subCoordinatorIds,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  State<ClubCard> createState() => _ClubCardState();
}

class _ClubCardState extends State<ClubCard> {
  String _mainCoordinatorName = 'Loading...';
  List<String> _subCoordinatorNames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCoordinatorNames();
  }

  @override
  void didUpdateWidget(ClubCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if coordinator IDs changed
    if (oldWidget.mainCoordinatorId != widget.mainCoordinatorId ||
        oldWidget.subCoordinatorIds != widget.subCoordinatorIds) {
      _loadCoordinatorNames();
    }
  }

  Future<void> _loadCoordinatorNames() async {
    try {
      // Fetch main coordinator name
      final mainDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.mainCoordinatorId)
          .get();

      String mainName = 'Unknown';
      if (mainDoc.exists) {
        mainName = mainDoc.data()?['name'] ?? 'Unknown';
      }

      // Fetch sub-coordinator names
      List<String> subNames = [];
      for (String subId in widget.subCoordinatorIds) {
        if (subId.isNotEmpty) {
          final subDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(subId)
              .get();
          if (subDoc.exists) {
            subNames.add(subDoc.data()?['name'] ?? 'Unknown');
          }
        }
      }

      if (mounted) {
        setState(() {
          _mainCoordinatorName = mainName;
          _subCoordinatorNames = subNames;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mainCoordinatorName = 'Error loading';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF162A45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Club Logo
          _buildClubLogo(),
          const SizedBox(width: 16),

          // Club Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Club Name
                Text(
                  widget.clubName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Category
                Text(
                  widget.category,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // Members Count
                Row(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.currentMembers} / ${widget.maxMembers}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Coordinators Section
                if (_isLoading)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF6B2C),
                    ),
                  )
                else
                  _buildCoordinatorsSection(),
              ],
            ),
          ),

          // Actions Column
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Status Toggle
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: isActive,
                  onChanged: (_) => widget.onToggle(),
                  activeColor: const Color(0xFFFF6B2C),
                  activeTrackColor: const Color(0xFFFF6B2C).withOpacity(0.4),
                  inactiveThumbColor: Colors.grey[600],
                  inactiveTrackColor: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),

              // Edit Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onEdit,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B2C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFFFF6B2C),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClubLogo() {
    if (widget.logoUrl != null && widget.logoUrl!.isNotEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B2C).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            widget.logoUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultLogo(),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildDefaultLogo();
            },
          ),
        ),
      );
    }
    return _buildDefaultLogo();
  }

  Widget _buildDefaultLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B2C).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.groups_rounded,
        color: Color(0xFFFF6B2C),
        size: 32,
      ),
    );
  }

  Widget _buildCoordinatorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Coordinator
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B2C).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'MAIN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF6B2C),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _mainCoordinatorName,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Sub-Coordinators
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'SUB',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[300],
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _subCoordinatorNames.isEmpty
                    ? 'No sub-coordinators'
                    : _subCoordinatorNames.join(', '),
                style: TextStyle(
                  fontSize: 13,
                  color: _subCoordinatorNames.isEmpty
                      ? Colors.grey[600]
                      : Colors.grey[300],
                  fontWeight: FontWeight.w500,
                  fontStyle: _subCoordinatorNames.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
