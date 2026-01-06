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
import '../../services/review_service.dart';

class AnalyticsDetailScreen extends StatefulWidget {
  final String id;
  final String name;
  final String email;
  final String role; // 'participant' or 'club'
  final String? imageUrl;

  const AnalyticsDetailScreen({
    Key? key,
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.imageUrl,
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
    }

    _events = events;
    _reports = reports;

    // 3. Build Timeline
    List<TimelineItem> items = [];
    
    // Add registrations
    for (var event in events) {
      items.add(TimelineItem(
        date: event.createdAt ?? DateTime.now(),
        title: 'Registered for ${event.name}',
        type: 'registration',
      ));
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
      'EVENTS REGISTERED': events.length.toString(),
      'REPORTS MADE': reports.length.toString(),
      'REVIEWS SUBMITTED': reviews.length.toString(),
    };
  }

  Future<void> _loadClubData() async {
    // 0. Get Club Details
    try {
      final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(widget.id).get();
      if (clubDoc.exists) {
        final data = clubDoc.data()!;
        data['id'] = clubDoc.id;
        _club = Club.fromFirestore(data);
      }
    } catch (e) {
      print('Error fetching club details: $e');
    }

    // 1. Get Events Created (where clubId == id)
    final eventsSnapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('clubId', isEqualTo: widget.id)
        .get();

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
        
        final reportChunk = await FirebaseFirestore.instance
            .collection('reports')
            .where('eventId', whereIn: chunk)
            .get();
        reports.addAll(reportChunk.docs.map((doc) => ReportModel.fromFirestore(doc.data(), doc.id)));

        final reviewChunk = await FirebaseFirestore.instance
            .collection('reviews')
            .where('eventId', whereIn: chunk)
            .get();
        reviews.addAll(reviewChunk.docs.map((doc) => ReviewModel.fromFirestore(doc.data(), doc.id)));
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

    for (var event in events) {
      items.add(TimelineItem(
        date: event.createdAt ?? DateTime.now(),
        title: 'Created event ${event.name}',
        type: 'creation',
      ));
    }

    for (var report in reports) {
      items.add(TimelineItem(
        date: report.createdAt,
        title: 'Report received for ${report.eventName}',
        type: 'report_received',
      ));
    }

    for (var review in reviews) {
      if (review.createdAt != null) {
        items.add(TimelineItem(
          date: review.createdAt!,
          title: 'Review received on an event',
          type: 'review_received',
          details: '${review.comment} (${review.rating} stars)',
          id: review.id,
        ));
      }
    }

    items.sort((a, b) => b.date.compareTo(a.date));

    _timeline = items;
    _stats = {
      'EVENTS': events.length.toString(),
      'REPORTS': reports.length.toString(),
      'REVIEWS': reviews.length.toString(),
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
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _showMetricDetail(context, entry.key),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
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
      case 'EVENTS REGISTERED': return Icons.event_available;
      case 'REPORTS MADE': return Icons.report_problem;
      case 'EVENTS': return Icons.calendar_today;
      case 'REPORTS': return Icons.flag_outlined;
      case 'MEMBERS': return Icons.group_outlined;
      default: return Icons.circle;
    }
  }

  Color _getStatColor(String key) {
    switch (key) {
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
                              final filters = ['All', 'Registration', 'Creation', 'Report', 'Review'];
                              if (widget.role == 'participant') {
                                filters.remove('Creation');
                              } else {
                                filters.remove('Registration');
                              }
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
                if (_isSheetExpanded)
                  _buildActivityList(),
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
            if (_selectedActivityFilter == 'Registration') return item.type == 'registration';
            if (_selectedActivityFilter == 'Creation') return item.type == 'creation';
            if (_selectedActivityFilter == 'Report') return item.type.contains('report');
            if (_selectedActivityFilter == 'Review') return item.type.contains('review');
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
                      if (item.details != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              top: BorderSide(color: Colors.grey[200]!),
                              right: BorderSide(color: Colors.grey[200]!),
                              bottom: BorderSide(color: Colors.grey[200]!),
                              left: BorderSide(color: typeColor, width: 4),
                            ),
                          ),
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
    if (type == 'creation') return Colors.purple;
    return Colors.grey;
  }


  String _formatDateTime(DateTime dt) {
    return '${DateFormat('MMM d, yyyy').format(dt)} at ${DateFormat('h:mm a').format(dt)}';
  }

  void _showMetricDetail(BuildContext context, String key) {
    if (key == 'MEMBERS') return; // No chart for members yet

    List<dynamic> data = [];
    Color color = _getStatColor(key);
    
    if (key == 'EVENTS REGISTERED' || key == 'EVENTS') {
      data = _events;
    } else if (key == 'REPORTS MADE' || key == 'REPORTS') {
      data = _reports;
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
        maxChildSize: 0.9,
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
                  _buildMetricChart(key, data, color),
                ],
              ),
            ),
          );
        }
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
