import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/event.dart';
import '../../models/report.dart';
import '../../models/user.dart';
import '../../models/club.dart';
import '../../models/review.dart';
import '../../models/register.dart';
import '../../services/review_service.dart';

class AnalyticsDetailScreen extends StatefulWidget {
  final String id;
  final String name;
  final String email;
  final String role; // 'participant' or 'club'
  final String? imageUrl;
  final String? clubId; // For club users, this is the actual club document ID

  const AnalyticsDetailScreen({
    Key? key,
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.imageUrl,
    this.clubId,
  }) : super(key: key);

  @override
  State<AnalyticsDetailScreen> createState() => _AnalyticsDetailScreenState();
}

class _AnalyticsDetailScreenState extends State<AnalyticsDetailScreen> {
  bool _isLoading = true;
  List<TimelineItem> _timeline = [];
  Map<String, String> _stats = {};
  DateTimeRange? _selectedDateRange; // null means All Time
  
  // New fields for detailed info
  UserModel? _user;
  Club? _club;
  String _selectedActivityFilter = 'All';
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  bool _isSheetExpanded = false;

  // New fields for charts
  List<EventModel> _events = [];
  List<ReportModel> _reports = [];

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(() {
      final isExpanded = _sheetController.size > 0.15;
      if (isExpanded != _isSheetExpanded) {
        setState(() => _isSheetExpanded = isExpanded);
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      if (widget.role == 'participant') {
        await _loadParticipantData();
      } else {
        await _loadClubData();
      }
    } catch (e) {
      print('Error loading detail data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadParticipantData() async {
    // 0. Get User Details
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.id).get();
      if (userDoc.exists) {
        _user = UserModel.fromFirestore(userDoc.data()!);
      }
    } catch (e) {
      print('Error fetching user details: $e');
    }

    // 1. Get Events Registered (where attendees contains userId)
    final eventsSnapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('attendees', arrayContains: widget.id)
        .get();

    var events = eventsSnapshot.docs
        .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
        .toList();

    // 2. Get Reports Made (where userId == userId)
    final reportsSnapshot = await FirebaseFirestore.instance
        .collection('reports')
        .where('userId', isEqualTo: widget.id)
        .get();

    var reports = reportsSnapshot.docs
        .map((doc) => ReportModel.fromFirestore(doc.data(), doc.id))
        .toList();

    // 2b. Get Reviews Made
    final reviewsSnapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .where('userId', isEqualTo: widget.id)
        .get();

    var reviews = reviewsSnapshot.docs
        .map((doc) => ReviewModel.fromFirestore(doc.data(), doc.id))
        .toList();

    // 2c. Get Registrations/Attendances
    final registersSnapshot = await FirebaseFirestore.instance
        .collection('registers')
        .where('userId', isEqualTo: widget.id)
        .get();
    
    var registrations = registersSnapshot.docs
        .map((doc) => Register.fromFirestore(doc.data(), documentId: doc.id))
        .toList();

    // Filter by date range if selected
    if (_selectedDateRange != null) {
      events = events.where((e) {
        if (e.createdAt == null) return false;
        final eventDate = DateTime(e.createdAt!.year, e.createdAt!.month, e.createdAt!.day);
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
        return (eventDate.isAtSameMomentAs(start) || eventDate.isAfter(start)) && 
               (eventDate.isAtSameMomentAs(end) || eventDate.isBefore(end));
      }).toList();
      
      reports = reports.where((r) {
        final reportDate = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
        return (reportDate.isAtSameMomentAs(start) || reportDate.isAfter(start)) && 
               (reportDate.isAtSameMomentAs(end) || reportDate.isBefore(end));
      }).toList();

      reviews = reviews.where((v) {
        if (v.createdAt == null) return false;
        final reviewDate = DateTime(v.createdAt!.year, v.createdAt!.month, v.createdAt!.day);
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
        return (reviewDate.isAtSameMomentAs(start) || reviewDate.isAfter(start)) && 
               (reviewDate.isAtSameMomentAs(end) || reviewDate.isBefore(end));
      }).toList();

      registrations = registrations.where((r) {
        final regDate = DateTime(r.registrationDate.year, r.registrationDate.month, r.registrationDate.day);
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
        
        bool inRange = (regDate.isAtSameMomentAs(start) || regDate.isAfter(start)) && 
               (regDate.isAtSameMomentAs(end) || regDate.isBefore(end));
        
        // If it's an attendance, we should also check attendance date
        if (r.status == 'attended' && r.attendedAt != null) {
          final attendDate = DateTime(r.attendedAt!.year, r.attendedAt!.month, r.attendedAt!.day);
          bool attendInRange = (attendDate.isAtSameMomentAs(start) || attendDate.isAfter(start)) && 
                               (attendDate.isAtSameMomentAs(end) || attendDate.isBefore(end));
          return inRange || attendInRange;
        }
        return inRange;
      }).toList();
    }

    _events = events;
    _reports = reports;

    // 3. Build Timeline
    List<TimelineItem> items = [];
    
    // Create a map for event names
    final Map<String, String> eventNames = {};
    for (var event in events) {
      eventNames[event.id] = event.name;
    }
    
    // Add registrations and attendances from registrations list
    for (var reg in registrations) {
      final eventName = eventNames[reg.eventId] ?? 'Unknown Event';
      
      // Registration activity
      items.add(TimelineItem(
        date: reg.registrationDate,
        title: 'Registered for $eventName',
        type: 'registration',
      ));

      // Attendance activity
      if (reg.status == 'attended') {
        items.add(TimelineItem(
          date: reg.attendedAt ?? reg.registrationDate, // Fallback
          title: 'Attended $eventName',
          type: 'attend',
        ));
      }
    }

    for (var report in reports) {
      items.add(TimelineItem(
        date: report.createdAt,
        title: 'Reported ${report.eventName}',
        type: 'report',
      ));
    }

    for (var review in reviews) {
      if (review.createdAt != null) {
        items.add(TimelineItem(
          date: review.createdAt!,
          title: 'Reviewed an event',
          type: 'review',
          details: review.comment,
          id: review.id,
        ));
      }
    }

    // Sort by date descending
    items.sort((a, b) => b.date.compareTo(a.date));

    _timeline = items;
    _stats = {
      'Event ': events.length.toString(),
      'Report': reports.length.toString(),
      'Review': reviews.length.toString(),
    };
  }

  Future<void> _loadClubData() async {
    // Determine the actual club ID to use
    final actualClubId = widget.clubId ?? widget.id;
    print('DEBUG: Loading club data for clubId: $actualClubId (widget.id: ${widget.id}, widget.clubId: ${widget.clubId})');
    
    // 0. Get Club Details
    try {
      final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(actualClubId).get();
      if (clubDoc.exists) {
        final data = clubDoc.data()!;
        data['id'] = clubDoc.id;
        _club = Club.fromFirestore(data);
        print('DEBUG: Club loaded: ${_club?.name}');
      } else {
        print('DEBUG: Club document not found for id: $actualClubId');
      }
    } catch (e) {
      print('Error fetching club details: $e');
    }

    // 1. Get Events Created (where clubId == actualClubId)
    final eventsSnapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('clubId', isEqualTo: actualClubId)
        .get();
    
    print('DEBUG: Found ${eventsSnapshot.docs.length} events for club $actualClubId');

    var events = eventsSnapshot.docs
        .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
        .toList();

    // Filter events by date range first to reduce report queries if possible
    if (_selectedDateRange != null) {
      events = events.where((e) {
        if (e.createdAt == null) return false;
        final eventDate = DateTime(e.createdAt!.year, e.createdAt!.month, e.createdAt!.day);
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
        return (eventDate.isAtSameMomentAs(start) || eventDate.isAfter(start)) && 
               (eventDate.isAtSameMomentAs(end) || eventDate.isBefore(end));
      }).toList();
    }

    // 2. Get Reports Received (reports on these events)
    List<ReportModel> reports = [];
    List<ReviewModel> reviews = [];

    if (events.isNotEmpty) {
      final eventIds = events.map((e) => e.id).toList();
      
      // Chunking for 'whereIn' limit of 10
      for (var i = 0; i < eventIds.length; i += 10) {
        final end = (i + 10 < eventIds.length) ? i + 10 : eventIds.length;
        final chunk = eventIds.sublist(i, end);
        
        try {
          final reportChunk = await FirebaseFirestore.instance
              .collection('reports')
              .where('eventId', whereIn: chunk)
              .get();
          // Safe mapping for reports
          for (var doc in reportChunk.docs) {
            try {
              reports.add(ReportModel.fromFirestore(doc.data(), doc.id));
            } catch (e) {
              print('Error parsing report: $e');
            }
          }

          final reviewChunk = await FirebaseFirestore.instance
              .collection('reviews')
              .where('eventId', whereIn: chunk)
              .get();
          // Safe mapping for reviews
          for (var doc in reviewChunk.docs) {
             try {
                reviews.add(ReviewModel.fromFirestore(doc.data(), doc.id));
             } catch (e) {
                print('Error parsing review: $e');
             }
          }
        } catch (e) {
          print('Error fetching chunks for club data: $e');
        }
      }
    }

    // Filter by date range
    if (_selectedDateRange != null) {
      reports = reports.where((r) {
        final reportDate = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
        return (reportDate.isAtSameMomentAs(start) || reportDate.isAfter(start)) && 
               (reportDate.isAtSameMomentAs(end) || reportDate.isBefore(end));
      }).toList();

      reviews = reviews.where((v) {
        if (v.createdAt == null) return false;
        final reviewDate = DateTime(v.createdAt!.year, v.createdAt!.month, v.createdAt!.day);
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
        return (reviewDate.isAtSameMomentAs(start) || reviewDate.isAfter(start)) && 
               (reviewDate.isAtSameMomentAs(end) || reviewDate.isBefore(end));
      }).toList();
    }

    _events = events;
    _reports = reports;

    // 3. Build Timeline
    List<TimelineItem> items = [];
    int editCount = 0;
    double estimatedRevenue = 0;

    for (var event in events) {
      // Calculate revenue 
      estimatedRevenue += (event.price * event.attendees.length);

      // Add create event activity
      items.add(TimelineItem(
        date: event.createdAt ?? DateTime.now(),
        title: 'Created event: ${event.name}',
        type: 'create_event',
        details: event.location,
      ));
      
      // Add edit event activity if updatedAt exists and is different from createdAt
      if (event.updatedAt != null && event.createdAt != null) {
        final timeDiff = event.updatedAt!.difference(event.createdAt!).inMinutes.abs();
        if (timeDiff > 1) { // Only count as edit if more than 1 minute difference
          items.add(TimelineItem(
            date: event.updatedAt!,
            title: 'Edited event: ${event.name}',
            type: 'edit_event',
            details: event.location,
          ));
          editCount++;
        }
      }
    }

    items.sort((a, b) => b.date.compareTo(a.date));

    _timeline = items;
    _stats = {
      'Events': events.length.toString(),
      'Edits': editCount.toString(),
      'Revenue': 'RM${estimatedRevenue.toStringAsFixed(2)}',
    };
  }

  Future<void> _selectDateRange(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Time'),
                onTap: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                  Navigator.pop(context);
                  _loadData();
                },
              ),
              ListTile(
                title: const Text('Last 7 Days'),
                onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: now.subtract(const Duration(days: 7)),
                      end: now,
                    );
                  });
                  Navigator.pop(context);
                  _loadData();
                },
              ),
              ListTile(
                title: const Text('Last 30 Days'),
                onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: now.subtract(const Duration(days: 30)),
                      end: now,
                    );
                  });
                  Navigator.pop(context);
                  _loadData();
                },
              ),
              ListTile(
                title: const Text('Last 90 Days'),
                onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: now.subtract(const Duration(days: 90)),
                      end: now,
                    );
                  });
                  Navigator.pop(context);
                  _loadData();
                },
              ),
              ListTile(
                title: const Text('Custom...'),
                onTap: () async {
                  Navigator.pop(context);
                  final DateTimeRange? picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2025, 10, 1),
                    lastDate: DateTime.now(),
                    initialDateRange: _selectedDateRange,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Colors.blue,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Colors.black,
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 400.0,
                              maxHeight: 600.0,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: child!,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                  if (picked != null && picked != _selectedDateRange) {
                    setState(() {
                      _selectedDateRange = picked;
                    });
                    _loadData();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateRange(DateTimeRange? range) {
    if (range == null) return 'All Time';
    
    final now = DateTime.now();
    final diff = now.difference(range.start).inDays;
    
    if (diff >= 6 && diff <= 7) return 'Last 7 Days';
    if (diff >= 29 && diff <= 30) return 'Last 30 Days';
    if (diff >= 89 && diff <= 90) return 'Last 90 Days';

    if (range.start.year == range.end.year && 
        range.start.month == range.end.month && 
        range.start.day == range.end.day) {
      return DateFormat('MMM d, yyyy').format(range.start);
    }
    return '${DateFormat('MMM d').format(range.start)} - ${DateFormat('MMM d, yyyy').format(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.role == 'participant' ? 'Participant' : 'Club'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: () => _selectDateRange(context),
              child: Text(
                _formatDateRange(_selectedDateRange),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Profile Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundImage: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                                      ? NetworkImage(widget.imageUrl!)
                                      : null,
                                  child: widget.imageUrl == null || widget.imageUrl!.isEmpty
                                      ? const Icon(Icons.person, size: 40)
                                      : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.email,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Stats Cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: _stats.entries.map((entry) {
                            final isRevenueCard = entry.key == 'Revenue';
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _showMetricDetail(context, entry.key),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: isRevenueCard
                                        ? LinearGradient(
                                            colors: [
                                              _getStatColor(entry.key).withOpacity(0.15),
                                              _getStatColor(entry.key).withOpacity(0.05),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: !isRevenueCard ? Colors.white : null,
                                    border: isRevenueCard
                                        ? Border.all(
                                            color: _getStatColor(entry.key),
                                            width: 2,
                                          )
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                    child: Column(
                                      children: [
                                        Icon(
                                          _getStatIcon(entry.key),
                                          color: _getStatColor(entry.key),
                                          size: 24,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          entry.value,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          entry.key,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),
                      
                      // More Information
                      _buildMoreInfo(),
                    ],
                  ),
                ),
                
                // Recent Activity Sheet
                _buildRecentActivitySheet(),
              ],
            ),
    );
  }

  IconData _getStatIcon(String key) {
    switch (key) {
      // Participant stats
      case 'Event ': return Icons.event_available;
      case 'Report': return Icons.flag_outlined;
      case 'Review': return Icons.rate_review_outlined;
      // Club stats
      case 'Events': return Icons.calendar_today;
      case 'Edits': return Icons.edit_outlined;
      case 'Members': return Icons.group_outlined;
      case 'Revenue': return Icons.attach_money;
      // Legacy keys
      case 'EVENTS REGISTERED': return Icons.event_available;
      case 'REPORTS MADE': return Icons.report_problem;
      case 'EVENTS': return Icons.calendar_today;
      case 'REPORTS': return Icons.flag_outlined;
      case 'MEMBERS': return Icons.group_outlined;
      default: return Icons.analytics_outlined;
    }
  }

  Color _getStatColor(String key) {
    switch (key) {
      // Participant stats
      case 'Event ': return Colors.blue;
      case 'Report': return Colors.orange;
      case 'Review': return Colors.amber;
      // Club stats  
      case 'Events': return Colors.green;
      case 'Edits': return Colors.purple;
      case 'Members': return Colors.blue;
      case 'Revenue': return Colors.teal;
      // Legacy keys
      case 'EVENTS REGISTERED': return Colors.blue;
      case 'REPORTS MADE': return Colors.orange;
      case 'EVENTS': return Colors.purple;
      case 'REPORTS': return Colors.red;
      case 'MEMBERS': return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _buildMoreInfo() {
    final memberSince = widget.role == 'participant' 
        ? _user?.createdAt 
        : _club?.createdAt;
    
    final location = widget.role == 'participant' 
        ? 'Not available' // User model doesn't have location
        : _club?.location ?? 'Not available';
        
    final contactEmail = widget.role == 'participant'
        ? _user?.email
        : _club?.contactEmail ?? widget.email;

    final lastActivity = _timeline.isNotEmpty ? _timeline.first.date : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'More Information',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.access_time, 'Member Since', memberSince != null ? DateFormat('MMMM d, yyyy').format(memberSince) : 'Unknown'),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.location_on_outlined, 'Location', location),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.email_outlined, 'Contact Email', contactEmail ?? 'Unknown'),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.calendar_today_outlined, 'Last Activity', lastActivity != null ? _formatDateTime(lastActivity) : 'No activity'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey[600], size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.1,
      minChildSize: 0.1,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                GestureDetector(
                  onTap: () {
                    if (_sheetController.size > 0.15) {
                      _sheetController.animateTo(
                        0.1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _sheetController.animateTo(
                        0.95,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Container(
                    color: Colors.transparent, // Ensure hit test works
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'RECENT ACTIVITIES',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isSheetExpanded)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.filter_list),
                            onSelected: (value) {
                              setState(() {
                                _selectedActivityFilter = value;
                              });
                            },
                            itemBuilder: (context) {
                              // Different filters for participant vs club
                              final filters = widget.role == 'participant'
                                  ? ['All', 'Register', 'Attend', 'Report', 'Review']
                                  : ['All', 'Create Event', 'Edit Event'];
                              return filters.map((filter) => PopupMenuItem(
                                value: filter,
                                child: Text(filter),
                              )).toList();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                _buildActivityList(), // Always build, don't hide based on expansion
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityList() {
    final filteredTimeline = _selectedActivityFilter == 'All'
        ? _timeline
        : _timeline.where((item) {
            // Participant filters
            if (_selectedActivityFilter == 'Register') return item.type == 'registration';
            if (_selectedActivityFilter == 'Attend') return item.type == 'attend';
            if (_selectedActivityFilter == 'Report') return item.type.contains('report');
            if (_selectedActivityFilter == 'Review') return item.type.contains('review');
            // Club filters
            if (_selectedActivityFilter == 'Create Event') return item.type == 'create_event';
            if (_selectedActivityFilter == 'Edit Event') return item.type == 'edit_event';
            return true;
          }).toList();

    if (filteredTimeline.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Text('No activities found'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: filteredTimeline.length,
      itemBuilder: (context, index) {
        final item = filteredTimeline[index];
        final typeColor = _getTypeColor(item.type);
        
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: typeColor,
                        width: 2,
                      ),
                      color: Colors.white,
                    ),
                  ),
                  if (index != filteredTimeline.length - 1)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: Colors.grey[200],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMM d, yyyy').format(item.date),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.details != null && !item.type.contains('review'))
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.details!,
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              if (item.type.contains('review') && item.id != null)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _deleteReview(item.id!),
                                    icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                    label: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 11)),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.type.toUpperCase(),
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteReview(String reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ReviewService().deleteReview(reviewId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review deleted')));
          _loadData(); // Refresh data
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Color _getTypeColor(String type) {
    if (type.contains('review')) return Colors.amber[700]!;
    if (type.contains('report')) return Colors.red;
    if (type == 'registration') return Colors.blue;
    if (type == 'attend') return Colors.green;
    if (type == 'create_event') return Colors.green;
    if (type == 'edit_event') return Colors.purple;
    return Colors.grey;
  }


  String _formatDateTime(DateTime dt) {
    return '${DateFormat('MMM d, yyyy').format(dt)} at ${DateFormat('h:mm a').format(dt)}';
  }

  void _showMetricDetail(BuildContext context, String key) {
    if (key == 'MEMBERS') return; // No chart for members
    
    // Disable popups for specific metrics based on role
    if (widget.role == 'participant' && ['Event ', 'Report', 'Review'].contains(key)) return;
    if (widget.role == 'club' && ['Events', 'Edits'].contains(key)) return;

    List<dynamic> data = [];
    Color color = _getStatColor(key);
    
    if (key == 'EVENTS REGISTERED' || key == 'EVENTS') {
      data = _events;
    } else if (key == 'REPORTS MADE' || key == 'REPORTS') {
      data = _reports;
    } else if (key == 'Revenue') {
      data = _events; // Use events for revenue analysis
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    '$key Analysis',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (key == 'Revenue')
                    _buildRevenueAnalysis(color)
                  else
                    _buildMetricChart(key, data, color),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildRevenueAnalysis(Color color) {
    // Calculate revenue timeline
    Map<DateTime, double> revenueByDate = {};
    Map<String, double> participantSpending = {}; // participantId -> total spent
    Map<String, double> clubRevenue = {}; // clubId -> total revenue
    
    for (var event in _events) {
      final eventDate = event.createdAt ?? DateTime.now();
      final day = DateTime(eventDate.year, eventDate.month, eventDate.day);
      final eventRevenue = event.price * event.attendees.length;
      
      // Add to date timeline
      revenueByDate[day] = (revenueByDate[day] ?? 0) + eventRevenue;
      
      // Track by club
      if (event.clubId != null) {
        clubRevenue[event.clubId!] = (clubRevenue[event.clubId!] ?? 0) + eventRevenue;
      }
    }
    
    // For participant, calculate their spending from registered events
    if (widget.role == 'participant') {
      double totalSpent = 0;
      for (var event in _events) {
        totalSpent += event.price;
      }
      participantSpending[widget.id] = totalSpent;
    }

    final sortedDates = revenueByDate.keys.toList()..sort();
    
    // Get top participants by spending (for club view)
    List<MapEntry<String, double>> topParticipants = [];
    if (widget.role == 'club') {
      // Build participant spending from events
      for (var event in _events) {
        for (var participantId in event.attendees) {
          participantSpending[participantId] = (participantSpending[participantId] ?? 0) + event.price;
        }
      }
      topParticipants = participantSpending.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topParticipants = topParticipants.take(5).toList();
    }

    // Get top clubs by revenue (for participant view)
    List<MapEntry<String, double>> topClubs = clubRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topClubs = topClubs.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Revenue Timeline Chart
        if (sortedDates.isNotEmpty && widget.role != 'club') ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Revenue Timeline',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildRevenueTimelineChart(revenueByDate, sortedDates, color),
          const SizedBox(height: 32),
        ],

        // Top Participants by Money Spent (for club view)
        if (widget.role == 'club' && topParticipants.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Top Participants by Money Spent',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildTopParticipantsList(topParticipants),
          const SizedBox(height: 32),
        ],

        // Top Clubs by Revenue (for participant view)
        if (widget.role == 'participant' && topClubs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Top Clubs by Revenue',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildTopClubsList(topClubs),
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  Widget _buildRevenueTimelineChart(
    Map<DateTime, double> revenueByDate,
    List<DateTime> sortedDates,
    Color color,
  ) {
    final spots = sortedDates.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), revenueByDate[e.value]!);
    }).toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          width: sortedDates.length * 50.0 < MediaQuery.of(context).size.width
              ? MediaQuery.of(context).size.width - 48
              : sortedDates.length * 50.0,
          padding: const EdgeInsets.only(left: 24, top: 24, bottom: 12),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < sortedDates.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('MM/dd').format(sortedDates[index]),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      return const Text('');
                    },
                    interval: 1,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: null,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        'RM${value.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 9),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withOpacity(0.1),
                  ),
                ),
              ],
              minY: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopParticipantsList(List<MapEntry<String, double>> topParticipants) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: List.generate(topParticipants.length, (index) {
          final entry = topParticipants[index];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(entry.key)
                            .get(),
                        builder: (context, snapshot) {
                          String name = 'User #${index + 1}';
                          if (snapshot.hasData && snapshot.data!.exists) {
                            name = snapshot.data!['name'] ?? name;
                          }
                          return Text(
                            name,
                            style: const TextStyle(fontSize: 14),
                          );
                        },
                      ),
                    ),
                    Text(
                      'RM${entry.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < topParticipants.length - 1)
                Divider(height: 1, color: Colors.grey[300]),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTopClubsList(List<MapEntry<String, double>> topClubs) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: List.generate(topClubs.length, (index) {
          final entry = topClubs[index];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('clubs')
                            .doc(entry.key)
                            .get(),
                        builder: (context, snapshot) {
                          String name = 'Club #${index + 1}';
                          if (snapshot.hasData && snapshot.data!.exists) {
                            name = snapshot.data!['name'] ?? name;
                          }
                          return Text(
                            name,
                            style: const TextStyle(fontSize: 14),
                          );
                        },
                      ),
                    ),
                    Text(
                      'RM${entry.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < topClubs.length - 1)
                Divider(height: 1, color: Colors.grey[300]),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMetricChart(String title, List<dynamic> data, Color color) {
    // Aggregate data by date
    Map<DateTime, int> counts = {};
    
    for (var item in data) {
      DateTime? date;
      if (item is EventModel) date = item.createdAt;
      if (item is ReportModel) date = item.createdAt;
      
      if (date != null) {
        final day = DateTime(date.year, date.month, date.day);
        counts[day] = (counts[day] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) return const SizedBox.shrink();

    final sortedDates = counts.keys.toList()..sort();
    final spots = sortedDates.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), counts[e.value]!.toDouble());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          height: 200,
          padding: const EdgeInsets.only(right: 24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: sortedDates.length * 50.0 < MediaQuery.of(context).size.width 
                  ? MediaQuery.of(context).size.width - 48 
                  : sortedDates.length * 50.0,
              padding: const EdgeInsets.only(left: 24, top: 24, bottom: 12),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < sortedDates.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MM/dd').format(sortedDates[index]),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 == 0) {
                            return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.1),
                      ),
                    ),
                  ],
                  minY: 0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class TimelineItem {
  final DateTime date;
  final String title;
  final String type;
  final String? details;
  final String? id;

  TimelineItem({
    required this.date,
    required this.title,
    required this.type,
    this.details,
    this.id,
  });
}
