import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../models/report.dart';
import '../../models/user.dart';
import '../../models/club.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
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
    }

    // 3. Build Timeline
    List<TimelineItem> items = [];
    
    // Add registrations (using event createdAt as proxy for reg time if not available, 
    // but ideally we'd have a separate registrations collection. 
    // For now, we'll use event date or createdAt)
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

    // Sort by date descending
    items.sort((a, b) => b.date.compareTo(a.date));

    _timeline = items;
    _stats = {
      'EVENTS REGISTERED': events.length.toString(),
      'REPORTS MADE': reports.length.toString(),
    };
  }

  Future<void> _loadClubData() async {
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
    if (events.isNotEmpty) {
      // Firestore 'in' query is limited to 10. If more, we need multiple queries or client-side filter.
      // For scalability, let's fetch all reports and filter (not ideal for prod but ok for now)
      // OR fetch reports where eventId is in the list.
      
      // Let's try fetching reports for each event (parallel)
      final eventIds = events.map((e) => e.id).toList();
      
      // Chunking for 'whereIn' limit of 10
      for (var i = 0; i < eventIds.length; i += 10) {
        final end = (i + 10 < eventIds.length) ? i + 10 : eventIds.length;
        final chunk = eventIds.sublist(i, end);
        
        final chunkSnapshot = await FirebaseFirestore.instance
            .collection('reports')
            .where('eventId', whereIn: chunk)
            .get();
            
        reports.addAll(chunkSnapshot.docs
            .map((doc) => ReportModel.fromFirestore(doc.data(), doc.id)));
      }
    }

    // Filter reports by date range if selected
    if (_selectedDateRange != null) {
      reports = reports.where((r) {
        final reportDate = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
        return (reportDate.isAtSameMomentAs(start) || reportDate.isAfter(start)) && 
               (reportDate.isAtSameMomentAs(end) || reportDate.isBefore(end));
      }).toList();
    }

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

    items.sort((a, b) => b.date.compareTo(a.date));

    _timeline = items;
    _stats = {
      'EVENTS': events.length.toString(),
      'REPORTS': reports.length.toString(),
      'MEMBERS': '0', // Need to fetch club members count if available
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
          : SingleChildScrollView(
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
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Recent Activity
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RECENT ACTIVITY',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _timeline.length,
                          itemBuilder: (context, index) {
                            final item = _timeline[index];
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
                                            color: Colors.blue,
                                            width: 2,
                                          ),
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (index != _timeline.length - 1)
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
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.type,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
}

class TimelineItem {
  final DateTime date;
  final String title;
  final String type;

  TimelineItem({
    required this.date,
    required this.title,
    required this.type,
  });
}
