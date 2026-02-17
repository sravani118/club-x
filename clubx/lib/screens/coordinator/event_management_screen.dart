import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/coordinator/coordinator_event_card.dart';
import '../../utils/cloudinary_service.dart';

class EventManagementScreen extends StatefulWidget {
  final String clubId;

  const EventManagementScreen({
    super.key,
    required this.clubId,
  });

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  String _selectedFilter = 'all'; // all, upcoming, ongoing, completed

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
        
        debugPrint('🕐 [EVENT STATUS - DATE ONLY] ${eventData['title']}: EventDate=$eventDate, Now=$now');
        
        if (now.isAfter(eventEndOfDay)) {
          debugPrint('  → Status: completed (date passed)');
          return 'completed';
        } else if (now.year == eventDate.year && 
                   now.month == eventDate.month && 
                   now.day == eventDate.day) {
          debugPrint('  → Status: ongoing (today)');
          return 'ongoing';
        } else {
          debugPrint('  → Status: upcoming (future date)');
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

      debugPrint('🕐 [EVENT STATUS] ${eventData['title']}: Event=$eventDateTime, End=$eventEndTime, Now=$now');

      if (now.isBefore(eventDateTime)) {
        debugPrint('  → Status: upcoming');
        return 'upcoming';
      } else if (now.isAfter(eventEndTime)) {
        debugPrint('  → Status: completed');
        return 'completed';
      } else {
        debugPrint('  → Status: ongoing');
        return 'ongoing';
      }
    } catch (e) {
      debugPrint('❌ [EVENT STATUS ERROR] ${eventData['title']}: $e');
      debugPrint('   Event data: date=${eventData['date']}, time=${eventData['time']}, duration=${eventData['duration']}');
      // If there's an error, fall back to stored status
      return eventData['status'] ?? 'upcoming';
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
                    'Event Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Upcoming', 'upcoming'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Ongoing', 'ongoing'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Completed', 'completed'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Events List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getEventsStream(),
                builder: (context, snapshot) {
                  // Handle errors
                  if (snapshot.hasError) {
                    debugPrint('❌ [EVENTS] Stream error: ${snapshot.error}');
                    final errorString = snapshot.error.toString().toLowerCase();
                    final isIndexBuilding = errorString.contains('index is currently building') || 
                                          errorString.contains('cannot be used yet');
                    
                    if (isIndexBuilding) {
                      // Index is building - show friendly message and auto-retry
                      Future.delayed(const Duration(seconds: 5), () {
                        if (mounted) setState(() {});
                      });
                      
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFFFF6B2C),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Setting up database...',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This may take a few minutes.\nThe app will load automatically.',
                              style: TextStyle(color: Colors.grey[500], fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Auto-retrying...',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    // Other errors - show error with retry button
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading events',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              snapshot.error.toString(),
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6B2C),
                      ),
                    );
                  }

                  debugPrint('📊 [EVENTS] Received ${snapshot.data?.docs.length ?? 0} events');
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    debugPrint('⚠️ [EVENTS] No events found for clubId: ${widget.clubId}');
                    return _buildEmptyState();
                  }

                  final events = snapshot.data!.docs;
                  debugPrint('✅ [EVENTS] Received ${events.length} total events');

                  // Filter events by actual status calculated from date/time
                  final filteredEvents = events.where((eventDoc) {
                    if (_selectedFilter == 'all') return true;
                    
                    final event = eventDoc.data() as Map<String, dynamic>;
                    final actualStatus = _getActualEventStatus(event);
                    return actualStatus == _selectedFilter;
                  }).toList();

                  debugPrint('✅ [EVENTS] Displaying ${filteredEvents.length} events after filtering by $_selectedFilter');

                  if (filteredEvents.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 100, // Add space for FAB and last item
                    ),
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      final eventDoc = filteredEvents[index];
                      final event = eventDoc.data() as Map<String, dynamic>;
                      final actualStatus = _getActualEventStatus(event);

                      return CoordinatorEventCard(
                        eventId: eventDoc.id,
                        title: event['title'] ?? 'Untitled Event',
                        description: event['description'] ?? '',
                        date: (event['date'] as Timestamp).toDate(),
                        venue: event['venue'] ?? 'TBA',
                        maxCapacity: event['maxCapacity'] ?? 0,
                        registeredCount: event['registeredCount'] ?? 0,
                        attendanceCount: event['attendanceCount'] ?? 0,
                        status: actualStatus,
                        bannerUrl: event['imageUrl'],
                        onEdit: () => _editEvent(eventDoc.id, event),
                        onDelete: () => _deleteEvent(eventDoc.id, event['title']),
                        onViewRegistrations: () => _viewRegistrations(eventDoc.id, event['title']),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createEvent,
        backgroundColor: const Color(0xFFFF6B2C),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Event',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[400],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: const Color(0xFF1A2332),
      selectedColor: const Color(0xFFFF6B2C),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFFFF6B2C) : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 24),
            Text(
              'No Events Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first event to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createEvent,
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
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
      ),
    );
  }

  Stream<QuerySnapshot> _getEventsStream() {
    debugPrint('🔍 [EVENTS] Setting up stream for clubId: ${widget.clubId}');
    
    // Fetch all events for the club - filter by calculated status in memory
    return FirebaseFirestore.instance
        .collection('events')
        .where('clubId', isEqualTo: widget.clubId)
        .orderBy('date', descending: false)
        .snapshots(includeMetadataChanges: true);
  }

  void _createEvent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateEventBottomSheet(clubId: widget.clubId),
    );
  }

  void _editEvent(String eventId, Map<String, dynamic> eventData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateEventBottomSheet(
        clubId: widget.clubId,
        eventId: eventId,
        existingData: eventData,
      ),
    );
  }

  void _deleteEvent(String eventId, String eventTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2332),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Event',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "$eventTitle"? This action cannot be undone.',
            style: TextStyle(color: Colors.grey[400]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('events')
                    .doc(eventId)
                    .delete();
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Event deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  void _viewRegistrations(String eventId, String eventTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _EventRegistrationsScreen(
          eventId: eventId,
          eventTitle: eventTitle,
        ),
      ),
    );
  }
}

// Create/Edit Event Bottom Sheet
class _CreateEventBottomSheet extends StatefulWidget {
  final String clubId;
  final String? eventId;
  final Map<String, dynamic>? existingData;

  const _CreateEventBottomSheet({
    required this.clubId,
    this.eventId,
    this.existingData,
  });

  @override
  State<_CreateEventBottomSheet> createState() => _CreateEventBottomSheetState();
}

class _CreateEventBottomSheetState extends State<_CreateEventBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _capacityController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;
  
  // Image upload
  File? _eventImage;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _titleController.text = widget.existingData!['title'] ?? '';
      _descriptionController.text = widget.existingData!['description'] ?? '';
      _venueController.text = widget.existingData!['venue'] ?? '';
      _capacityController.text = (widget.existingData!['maxCapacity'] ?? '').toString();
      _durationController.text = (widget.existingData!['duration'] ?? 60).toString();
      
      if (widget.existingData!['date'] != null) {
        _selectedDate = (widget.existingData!['date'] as Timestamp).toDate();
        _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
      }
      
      // Load existing image URL
      final imageUrl = widget.existingData!['imageUrl'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        _existingImageUrl = imageUrl;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _capacityController.dispose();
    _durationController.dispose();
    super.dispose();
  }
  
  Future<void> _pickEventImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return;
      
      final file = File(pickedFile.path);
      final fileExists = await file.exists();
      
      if (!fileExists) {
        _showError('Selected image file not found');
        return;
      }
      
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        _showError('Image too large. Please select an image under 5MB');
        return;
      }
      
      setState(() {
        _eventImage = file;
      });
      
    } catch (e) {
      _showError('Error selecting image: $e');
    }
  }
  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2332),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.eventId == null ? 'Create Event' : 'Edit Event',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildTextField(
                controller: _titleController,
                label: 'Event Title',
                hint: 'Enter event title',
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              // Event Image Upload
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event Image (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickEventImage,
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1B2D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: _eventImage != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _eventImage!,
                                    width: double.infinity,
                                    height: 160,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                      onPressed: () => setState(() => _eventImage = null),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _existingImageUrl != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        _existingImageUrl!,
                                        width: double.infinity,
                                        height: 160,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return _buildImagePlaceholder();
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                          onPressed: () => setState(() => _existingImageUrl = null),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : _buildImagePlaceholder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Enter event description',
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _venueController,
                label: 'Venue',
                hint: 'Enter venue',
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Venue is required' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _capacityController,
                label: 'Max Capacity',
                hint: 'Enter maximum capacity',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Capacity is required';
                  if (int.tryParse(value!) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Duration
              _buildTextField(
                controller: _durationController,
                label: 'Duration (minutes)',
                hint: 'Enter event duration in minutes',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Duration is required';
                  if (int.tryParse(value!) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1B2D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFFFF6B2C)),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Time Picker
              InkWell(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1B2D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFFFF6B2C)),
                      const SizedBox(width: 12),
                      Text(
                        _selectedTime.format(context),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B2C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.eventId == null ? 'Create Event' : 'Update Event',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: const Color(0xFF0F1B2D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF6B2C)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF6B2C),
              surface: Color(0xFF1A2332),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF6B2C),
              surface: Color(0xFF1A2332),
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }
  
  Widget _buildImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 48,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to add event image',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final eventDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      
      // Note: We'll create event first, then upload image if needed
      String? imageUrl = _existingImageUrl;

      // Get club name from clubs collection
      String clubName = 'Unknown Club';
      try {
        final clubDoc = await FirebaseFirestore.instance
            .collection('clubs')
            .doc(widget.clubId)
            .get();
        
        if (clubDoc.exists) {
          clubName = clubDoc.data()?['name'] ?? 'Unknown Club';
        }
      } catch (e) {
        debugPrint('⚠️ [EVENTS] Error fetching club name: $e');
      }

      // Format time as string
      final hour = _selectedTime.hour;
      final minute = _selectedTime.minute;
      final timeString = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      final eventData = {
        'clubId': widget.clubId,
        'clubName': clubName,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'venue': _venueController.text.trim(),
        'maxCapacity': int.parse(_capacityController.text),
        'date': Timestamp.fromDate(eventDate),
        'time': timeString,
        'duration': int.parse(_durationController.text),
        'registeredCount': widget.existingData?['registeredCount'] ?? 0,
        'attendanceCount': widget.existingData?['attendanceCount'] ?? 0,
        'status': widget.existingData?['status'] ?? 'upcoming',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.eventId == null) {
        // Create new event
        debugPrint('🎉 [EVENTS] Creating new event...');
        debugPrint('🏛️ [EVENTS] clubId: ${widget.clubId}');
        debugPrint('📝 [EVENTS] title: ${_titleController.text.trim()}');
        
        // Add existing image URL if available (for create)
        if (imageUrl != null && imageUrl.isNotEmpty) {
          eventData['imageUrl'] = imageUrl;
        }
        
        eventData['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await FirebaseFirestore.instance.collection('events').add(eventData);
        
        debugPrint('✅ [EVENTS] Event created with ID: ${docRef.id}');
        
        // Upload new image if selected
        if (_eventImage != null) {
          debugPrint('📤 [EVENT_IMAGE] Uploading event image...');
          imageUrl = await CloudinaryService().uploadEventBanner(
            imageFile: _eventImage!,
            eventId: docRef.id,
          );
          debugPrint('✅ [EVENT_IMAGE] Image uploaded: $imageUrl');
          
          // Update event with image URL
          await FirebaseFirestore.instance
              .collection('events')
              .doc(docRef.id)
              .update({'imageUrl': imageUrl});
          debugPrint('✅ [EVENTS] Event updated with image URL');
        }
        
        // Verify the event was created by reading it back
        await Future.delayed(const Duration(milliseconds: 500));
        final verifyDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(docRef.id)
            .get(const GetOptions(source: Source.server));
        
        if (verifyDoc.exists) {
          final verifyData = verifyDoc.data();
          debugPrint('🔍 [EVENTS] Verification - clubId: ${verifyData?['clubId']}, title: ${verifyData?['title']}');
        } else {
          debugPrint('❌ [EVENTS] ERROR: Event document not found after creation!');
        }
      } else {
        // Update existing event
        debugPrint('🔄 [EVENTS] Updating event: ${widget.eventId}');
        
        // Upload new image if selected
        if (_eventImage != null) {
          debugPrint('📤 [EVENT_IMAGE] Uploading new event image...');
          imageUrl = await CloudinaryService().uploadEventBanner(
            imageFile: _eventImage!,
            eventId: widget.eventId!,
          );
          debugPrint('✅ [EVENT_IMAGE] Image uploaded: $imageUrl');
          eventData['imageUrl'] = imageUrl;
        } else if (_existingImageUrl == null) {
          // User removed the image and didn't upload a new one
          debugPrint('🗑️ [EVENT_IMAGE] Removing event image');
          eventData['imageUrl'] = FieldValue.delete();
        } else {
          // Keep existing image
          debugPrint('📷 [EVENT_IMAGE] Keeping existing image');
          eventData['imageUrl'] = _existingImageUrl;
        }
        
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .update(eventData);
        debugPrint('✅ [EVENTS] Event updated');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.eventId == null
                  ? 'Event created successfully'
                  : 'Event updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Event Registrations Screen
class _EventRegistrationsScreen extends StatelessWidget {
  final String eventId;
  final String eventTitle;

  const _EventRegistrationsScreen({
    required this.eventId,
    required this.eventTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2332),
        title: Text(eventTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .collection('registrations')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B2C)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No registrations yet',
                style: TextStyle(color: Colors.grey[400]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final reg = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFFF6B2C).withOpacity(0.2),
                      child: Text(
                        (reg['userName'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: Color(0xFFFF6B2C)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reg['userName'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            reg['userEmail'] ?? '',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
