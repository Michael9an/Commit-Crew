import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/event.dart';
import '../../models/club.dart';
import '../../models/register.dart';
import '../../models/review.dart';
import '../../models/report.dart';
import '../../services/firestore_service.dart';
import '../../widgets/charts/simple_line_chart_painter.dart';
import 'analytics_detail_screen.dart';

enum OverviewType {
  activeParticipants,
  activeClubs,
  totalRegistrations,
  eventsCreated,
  totalReports,
  totalRevenue,
}

class OverviewDetailScreen extends StatefulWidget {
  final OverviewType type;
  final DateTimeRange? dateRange;

  const OverviewDetailScreen({
    Key? key,
    required this.type,
    this.dateRange,
  }) : super(key: key);

  @override
  State<OverviewDetailScreen> createState() => _OverviewDetailScreenState();
}

class _OverviewDetailScreenState extends State<OverviewDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  DateTimeRange? _selectedDateRange;
  bool _isLoading = true;
  
  // Data holders
  List<Map<String, dynamic>> _chartData = [];
  List<Map<String, dynamic>> _listData = [];
  // For Registrations Pie Chart
  int _newUsersCount = 0;
  int _returningUsersCount = 0;
  // For Top Events
  List<Map<String, dynamic>> _topEvents = [];

  // For Top Registrations (Participants & Clubs)
  List<Map<String, dynamic>> _topParticipants = [];
  List<Map<String, dynamic>> _topClubs = [];
  
  // For Events Created Pie Chart
  String _eventDistributionFilter = 'Schedule'; // 'Schedule' or 'Pricing'
  int _weekdayVal = 0;
  int _weekendVal = 0;
  int _freeVal = 0;
  int _paidVal = 0;

  int _totalCount = 0;
  double _totalRevenue = 0;

  // For Active Clubs Pie Chart
  String _clubActivityFilter = 'Activity'; // 'Activity' (Active/Inactive) or 'Status' (New/Existing)
  int _activeClubsCount = 0;
  int _inactiveClubsCount = 0;
  int _newClubsCount = 0;
  int _existingClubsCount = 0;

  // For Reports Analysis
  Map<String, int> _reportReasonCounts = {};

  @override
  void initState() {
    super.initState();
    _selectedDateRange = widget.dateRange;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      switch (widget.type) {
        case OverviewType.activeParticipants:
          await _loadParticipantsData();
          break;
        case OverviewType.activeClubs:
          await _loadClubsData();
          break;
        case OverviewType.totalRegistrations:
          await _loadRegistrationsData();
          break;
        case OverviewType.eventsCreated:
          await _loadEventsData();
          break;
        case OverviewType.totalReports:
          await _loadReportsData();
          break;
        case OverviewType.totalRevenue:
          await _loadRevenueData();
          break;
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // For Active Participants Analysis
  int _activeParticipantsCount = 0;
  int _inactiveParticipantsCount = 0;

  List<Map<String, dynamic>> _fillMissingDates(List<Map<String, dynamic>> data) {
    if (data.isEmpty && _selectedDateRange == null) return [];

    DateTime start;
    DateTime end;

    if (_selectedDateRange != null) {
      start = _selectedDateRange!.start;
      end = _selectedDateRange!.end;
    } else {
      if (data.isEmpty) return [];
      // Sort first to find min/max
      final sorted = List<Map<String, dynamic>>.from(data)
        ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      start = sorted.first['date'] as DateTime;
      end = sorted.last['date'] as DateTime;
    }

    // Normalize to start of day
    start = DateTime(start.year, start.month, start.day);
    end = DateTime(end.year, end.month, end.day);

    Map<String, Map<String, dynamic>> dataMap = {};
    for (var item in data) {
      final date = item['date'] as DateTime;
      final key = DateFormat('yyyy-MM-dd').format(date);
      dataMap[key] = item;
    }

    List<Map<String, dynamic>> filled = [];
    final days = end.difference(start).inDays;
    
    for (int i = 0; i <= days; i++) {
      final d = start.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      if (dataMap.containsKey(key)) {
        filled.add(dataMap[key]!);
      } else {
        // Ensure count type matches (int/double handled by dynamic but safer to use 0)
        filled.add({'date': d, 'count': 0});
      }
    }
    return filled;
  }

  Future<void> _loadParticipantsData() async {
    final eventsSnapshot = await FirebaseFirestore.instance.collection('events').get();
    final usersSnapshot = await FirebaseFirestore.instance.collection('users')
        .where('role', isEqualTo: 'participant')
        .get();
    
    // safe load reviews
    List<ReviewModel> reviews = [];
    try {
      final reviewsSnapshot = await FirebaseFirestore.instance.collection('reviews').get();
      reviews = reviewsSnapshot.docs.map((doc) {
        try {
          return ReviewModel.fromFirestore(doc.data(), doc.id);
        } catch (_) {
          return null;
        }
      }).whereType<ReviewModel>()
      .where((r) => _isInDateRange(r.createdAt))
      .toList();
    } catch (e) {
      print('Error loading reviews for participants: $e');
    }

    // safe load reports
    List<ReportModel> reports = [];
    try {
      final reportsSnapshot = await FirebaseFirestore.instance.collection('reports').get();
      reports = reportsSnapshot.docs.map((doc) {
        try {
          return ReportModel.fromFirestore(doc.data(), doc.id);
        } catch (_) {
          return null;
        }
      }).whereType<ReportModel>()
      .where((r) => _isInDateRange(r.createdAt))
      .toList();
    } catch (e) {
      print('Error loading reports for participants: $e');
    }
    
    // Total participants
    final allParticipants = usersSnapshot.docs.toList();
    
    final events = eventsSnapshot.docs
        .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
        .where((e) => _isInDateRange(e.createdAt))
        .toList();
    
    // Count registrations per participant in this period
    Map<String, int> participantCounts = {};
    Map<String, DateTime> participantLastActivity = {};
    Map<String, int> dailyInteraction = {};
    
    // 1. Process Registrations
    for (var event in events) {
      if (event.createdAt != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(event.createdAt!);
        dailyInteraction[dateKey] = (dailyInteraction[dateKey] ?? 0) + event.attendees.length;
      }

      for (var attendeeId in event.attendees) {
        participantCounts[attendeeId] = (participantCounts[attendeeId] ?? 0) + 1;
        final eventDate = event.createdAt ?? DateTime.now();
        if (participantLastActivity[attendeeId] == null || 
            eventDate.isAfter(participantLastActivity[attendeeId]!)) {
          participantLastActivity[attendeeId] = eventDate;
        }
      }
    }

    // 2. Process Reviews
    for (var review in reviews) {
      if (review.createdAt != null) {
         final dateKey = DateFormat('yyyy-MM-dd').format(review.createdAt!);
         dailyInteraction[dateKey] = (dailyInteraction[dateKey] ?? 0) + 1;
      }

      participantCounts[review.userId] = (participantCounts[review.userId] ?? 0) + 1;
      final reviewDate = review.createdAt ?? DateTime.now();
       if (participantLastActivity[review.userId] == null || 
            reviewDate.isAfter(participantLastActivity[review.userId]!)) {
          participantLastActivity[review.userId] = reviewDate;
        }
    }

    // 3. Process Reports
    for (var report in reports) {
      // ReportModel guarantees non-null createdAt, but purely for safety
       final dateKey = DateFormat('yyyy-MM-dd').format(report.createdAt);
       dailyInteraction[dateKey] = (dailyInteraction[dateKey] ?? 0) + 1;

      participantCounts[report.userId] = (participantCounts[report.userId] ?? 0) + 1;
      final reportDate = report.createdAt;
       if (participantLastActivity[report.userId] == null || 
            reportDate.isAfter(participantLastActivity[report.userId]!)) {
          participantLastActivity[report.userId] = reportDate;
        }
    }
    
    // 1. Timeline Chart Data (Interaction)
    final rawData = dailyInteraction.entries.map((e) => {
      'date': DateTime.parse(e.key),
      'count': e.value,
    }).toList();
    _chartData = _fillMissingDates(rawData);
    
    // 2. Pie Chart Data (Active vs Inactive)
    _activeParticipantsCount = participantCounts.keys.length;
    _inactiveParticipantsCount = allParticipants.length - _activeParticipantsCount;
    if (_inactiveParticipantsCount < 0) _inactiveParticipantsCount = 0;

    // 3. Top Active List
    _listData = [];
    final sortedParticipantIds = participantCounts.keys.toList()
      ..sort((a, b) => participantCounts[b]!.compareTo(participantCounts[a]!));

    for (var userId in sortedParticipantIds.take(5)) {
      try {
        final userExists = allParticipants.any((d) => d.id == userId);
        Map<String, dynamic> userData = {};
        if (userExists) {
             userData = allParticipants.firstWhere((d) => d.id == userId).data();
        } else {
             // If we can't find in the 'role=participant' list, we should probably fetch it or display Unknown.
             // But for now, display as Unknown or fallback
             userData = {'name': 'Unknown User', 'email': 'N/A'};
        }

        _listData.add({
          'id': userId,
          'name': userData['name'] ?? userData['email'] ?? 'Unknown',
          'email': userData['email'] ?? '',
          'photoUrl': userData['photoUrl'],
          'count': participantCounts[userId],
          'lastActivity': participantLastActivity[userId],
          'role': 'participant',
        });
      } catch (e) {
        // Fallback or skip
      }
    }
    
    _totalCount = _activeParticipantsCount;
  }

  Future<void> _loadClubsData() async {
    final eventsSnapshot = await FirebaseFirestore.instance.collection('events').get();
    final clubsSnapshot = await FirebaseFirestore.instance.collection('clubs').get();
    
    final events = eventsSnapshot.docs
        .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
        .where((e) => _isInDateRange(e.createdAt))
        .toList();
    
    // Count events and registrations per club
    Map<String, int> clubEventCounts = {};
    
    // 1. Calculate Daily Active Clubs (Timeline)
    Map<String, Set<String>> dailyActiveClubs = {};

    for (var event in events) {
      // For Top 5 List & Active verification
      clubEventCounts[event.clubId] = (clubEventCounts[event.clubId] ?? 0) + 1;
      
      // For Timeline
      if (event.createdAt != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(event.createdAt!);
        if (!dailyActiveClubs.containsKey(dateKey)) {
          dailyActiveClubs[dateKey] = {};
        }
        dailyActiveClubs[dateKey]!.add(event.clubId);
      }
    }
    
    final rawData = dailyActiveClubs.entries.map((e) => {
      'date': DateTime.parse(e.key),
      'count': e.value.length,
    }).toList();
    _chartData = _fillMissingDates(rawData);
    
    // 2. Pie Chart Metrics
    _activeClubsCount = 0;
    _inactiveClubsCount = 0;
    _newClubsCount = 0;
    _existingClubsCount = 0;

    final periodStart = _selectedDateRange?.start ?? DateTime(2000); // Default distant past if All Time

    final allClubs = clubsSnapshot.docs.map((doc) {
       final data = doc.data();
       data['id'] = doc.id;
       return Club.fromFirestore(data);
    }).toList();

    for (var club in allClubs) {
      // Activity (Active vs Inactive in this period)
      if (clubEventCounts.containsKey(club.id)) {
        _activeClubsCount++;
      } else {
        _inactiveClubsCount++;
      }

      // Status (New vs Existing)
      // New: Created on or after period start
        if (club.createdAt != null) {
          if (club.createdAt!.isAfter(periodStart) || club.createdAt!.isAtSameMomentAs(periodStart)) {
            _newClubsCount++;
          } else {
             _existingClubsCount++;
          }
        } else {
           _existingClubsCount++; // Default to existing if no date
        }
    }

    // 3. Top 5 Active Clubs List (by Events Created)
    _listData = [];
    final activeClubIds = clubEventCounts.keys.toList();
    
    // Sort club IDs by event count desc
    activeClubIds.sort((a, b) => clubEventCounts[b]!.compareTo(clubEventCounts[a]!));
    
    for (var clubId in activeClubIds.take(5)) {
        try {
          final club = allClubs.firstWhere((c) => c.id == clubId);
          _listData.add({
            'id': club.id,
            'name': club.name,
            'email': club.contactEmail ?? '', // or createdBy user email if we had it easily
            'photoUrl': club.imageUrl,
            'eventCount': clubEventCounts[clubId],
          });
        } catch (e) {
            // Club not found
        }
    }
    
    // No need to sort again, already sorted
    _totalCount = clubEventCounts.length; // Active clubs count
  }

  Future<void> _loadRegistrationsData() async {
    // Switch to using Events collection as the source of truth for registrations
    // to align with System Analytics screen
    final eventsSnapshot = await FirebaseFirestore.instance.collection('events').get();
    print('DEBUG: Total events fetched: ${eventsSnapshot.docs.length}');
    final clubsSnapshot = await FirebaseFirestore.instance.collection('clubs').get();
    final allEvents = eventsSnapshot.docs
        .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
        .toList();
    
    final clubsMap = {for (var doc in clubsSnapshot.docs) doc.id: doc.data()};

    // 1. Determine first activity per user (for New vs Returning logic)
    Map<String, DateTime> firstActivity = {};
    for (var event in allEvents) {
      // DEBUG: print if event has attendees
      // if (event.attendees.isNotEmpty) print('Event ${event.id} has ${event.attendees.length} attendees');
      
      if (event.createdAt == null) continue;
      for (var userId in event.attendees) {
        if (!firstActivity.containsKey(userId) || event.createdAt!.isBefore(firstActivity[userId]!)) {
          firstActivity[userId] = event.createdAt!; 
        }
      }
    }

    // 2. Filter events for current period
    final filteredEvents = allEvents.where((e) => _isInDateRange(e.createdAt)).toList();
    print('DEBUG: Filtered events in range: ${filteredEvents.length}');

    // 3. Build Daily Counts (Timeline)
    Map<String, int> dailyCounts = {};
    for (var event in filteredEvents) {
      if (event.createdAt != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(event.createdAt!);
        dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + event.attendees.length;
      }
    }
    
    final rawData = dailyCounts.entries.map((e) => {
      'date': DateTime.parse(e.key),
      'count': e.value,
    }).toList();
    _chartData = _fillMissingDates(rawData);

    // 4. Member Composition (New vs Returning)
    _newUsersCount = 0;
    _returningUsersCount = 0;
    
    Set<String> activeUsersInPeriod = {};
    for (var event in filteredEvents) {
      activeUsersInPeriod.addAll(event.attendees);
    }
    
    final periodStart = _selectedDateRange?.start ?? DateTime(2000); 

    for (var userId in activeUsersInPeriod) {
       final firstDate = firstActivity[userId];
       // If their first activity was BEFORE this period start, they are Returning.
       // If their first activity is within this period (or after start), they are New (for this period).
       if (firstDate != null && firstDate.isBefore(periodStart)) {
         _returningUsersCount++;
       } else {
         _newUsersCount++;
       }
    }

    // 5. Top Participants and Clubs
    Map<String, int> userRegCounts = {};
    Map<String, int> clubRegCounts = {};

    for (var event in filteredEvents) {
      // Club counts (sum of attendees for this event)
      clubRegCounts[event.clubId] = (clubRegCounts[event.clubId] ?? 0) + event.attendees.length;
      
      // User counts
      for (var uid in event.attendees) {
        userRegCounts[uid] = (userRegCounts[uid] ?? 0) + 1;
      }
    }

    // Process Top Participants
    final sortedUsers = userRegCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topUserIds = sortedUsers.take(5).map((e) => e.key).toList();
    
    // Fetch user details
    List<Map<String, dynamic>> topParticipants = [];
    if (topUserIds.isNotEmpty) {
        try {
          final usersSnap = await FirebaseFirestore.instance.collection('users')
              .where(FieldPath.documentId, whereIn: topUserIds)
              .get();
          final userMap = {for (var doc in usersSnap.docs) doc.id: doc.data()};
          
          for (var entry in sortedUsers.take(5)) {
              final data = userMap[entry.key];
              topParticipants.add({
                  'id': entry.key,
                  'name': data?['name'] ?? 'Unknown User',
                  'email': data?['email'] ?? '',
                  'count': entry.value,
                  'photoUrl': data?['photoUrl'],
              });
          }
        } catch (e) {
          print('Error fetching top users: $e');
        }
    }
    _topParticipants = topParticipants;

    // Process Top Clubs
    final sortedClubs = clubRegCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    List<Map<String, dynamic>> topClubs = [];
    for (var entry in sortedClubs.take(5)) {
        final data = clubsMap[entry.key];
        topClubs.add({
            'id': entry.key,
            'name': data?['name'] ?? 'Unknown Club',
            'count': entry.value,
            'photoUrl': data?['imageUrl'],
        });
    }
    _topClubs = topClubs;
    
    // Calculate total
    _totalCount = filteredEvents.fold(0, (sum, e) => sum + e.attendees.length);
    
    // We don't populate _listData for Total Registrations 
    _listData = []; 
  }

  Future<void> _loadEventsData() async {
    final eventsSnapshot = await FirebaseFirestore.instance.collection('events').get();
    final clubsSnapshot = await FirebaseFirestore.instance.collection('clubs').get();
    
    final events = eventsSnapshot.docs
        .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
        .where((e) => _isInDateRange(e.createdAt))
        .toList();
    
    final clubsMap = {for (var doc in clubsSnapshot.docs) doc.id: doc.data()};
    
    // Reset counters
    _weekdayVal = 0;
    _weekendVal = 0;
    _freeVal = 0;
    _paidVal = 0;

    // Build chart data
    Map<String, int> dailyCounts = {};
    for (var event in events) {
      if (event.createdAt != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(event.createdAt!);
        dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
      }

      // Schedule Stats
       try {
        if (event.date.isNotEmpty) {
           final dt = DateTime.tryParse(event.date);
           if (dt != null) {
              if (dt.weekday >= 6) _weekendVal++;
              else _weekdayVal++;
           }
        }
      } catch (e) {
        // ignore date parsing error
      }

      // Pricing Stats
      if (event.isFree || event.price <= 0) {
        _freeVal++;
      } else {
        _paidVal++;
      }
    }
    
    final rawData = dailyCounts.entries.map((e) => {
      'date': DateTime.parse(e.key),
      'count': e.value,
    }).toList();
    _chartData = _fillMissingDates(rawData);
    
    _listData = events.map((e) {
      final clubData = clubsMap[e.clubId];
      return {
        'id': e.id,
        'name': e.name,
        'clubName': clubData?['name'] ?? 'Unknown Club',
        'date': e.date,
        'createdAt': e.createdAt,
        'attendeeCount': e.attendees.length,
        'price': e.price,
      };
    }).toList();
    
    _listData.sort((a, b) {
      final dateA = a['createdAt'] as DateTime?;
      final dateB = b['createdAt'] as DateTime?;
      if (dateA == null || dateB == null) return 0;
      return dateB.compareTo(dateA);
    });
    _totalCount = events.length;

    // Calculate Top 5 Events by Registration
    int totalAttendees = events.fold(0, (sum, e) => sum + e.attendees.length);
    _topEvents = events.map((e) {
      final clubData = clubsMap[e.clubId];
      double pct = totalAttendees > 0 ? e.attendees.length / totalAttendees : 0;
      return {
        'id': e.id,
        'name': e.name,
        'count': e.attendees.length,
        'date': e.createdAt,
        'clubName': clubData?['name'] ?? 'Unknown Club',
        'percentage': pct,
      };
    }).toList();
    
    _topEvents.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    if (_topEvents.length > 5) _topEvents = _topEvents.sublist(0, 5);
  }

  Future<void> _loadReportsData() async {
    try {
      final reportsSnapshot = await FirebaseFirestore.instance.collection('reports').get();
      final eventsSnapshot = await FirebaseFirestore.instance.collection('events').get();
      final clubsSnapshot = await FirebaseFirestore.instance.collection('clubs').get();
      
      final reports = reportsSnapshot.docs.where((doc) {
        final data = doc.data();
        DateTime? createdAt;
        if (data['createdAt'] is Timestamp) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        } else if (data['createdAt'] is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
        }
        return _isInDateRange(createdAt);
      }).toList();
      
      final eventsMap = {for (var doc in eventsSnapshot.docs) doc.id: doc.data()};
      final clubsMap = {for (var doc in clubsSnapshot.docs) doc.id: doc.data()};
      
      // Build chart data
      Map<String, int> dailyCounts = {};
      _reportReasonCounts = {};
      Map<String, int> eventReportCounts = {};

      for (var doc in reports) {
        final data = doc.data();
        DateTime? date;
        if (data['createdAt'] is Timestamp) {
          date = (data['createdAt'] as Timestamp).toDate();
        } else if (data['createdAt'] is int) {
          date = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
        }
        
        if (date != null) {
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
        }
        
        // Reason counts
        final reason = data['reason']?.toString() ?? 'Other';
        _reportReasonCounts[reason] = (_reportReasonCounts[reason] ?? 0) + 1;

        // Event counts
        final eventId = data['eventId']?.toString();
        if (eventId != null) {
          eventReportCounts[eventId] = (eventReportCounts[eventId] ?? 0) + 1;
        }
      }
      
      final rawData = dailyCounts.entries.map((e) => {
        'date': DateTime.parse(e.key),
        'count': e.value,
      }).toList();
      _chartData = _fillMissingDates(rawData);
      
      // Calculate Top 5 Reported Events
      final sortedEventIds = eventReportCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      _topEvents = [];
      final int totalReports = reports.length;

      for (var entry in sortedEventIds.take(5)) {
        final eventData = eventsMap[entry.key];
        if (eventData != null) {
            final clubId = eventData['clubId'];
            final clubData = clubId != null ? clubsMap[clubId] : null;
            
            _topEvents.add({
              'id': entry.key,
              'name': eventData['name'] ?? 'Unknown Event',
              'count': entry.value,
              'percentage': totalReports > 0 ? entry.value / totalReports : 0.0,
              'clubName': clubData?['name'] ?? 'Unknown Club',
            });
        }
      }
      
      _totalCount = reports.length;
      _listData = []; 
    } catch (e) {
      print('Error in _loadReportsData: $e');
    }
  }

  Future<void> _loadRevenueData() async {
    final eventsSnapshot = await FirebaseFirestore.instance.collection('events').get();
    final clubsSnapshot = await FirebaseFirestore.instance.collection('clubs').get();
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    
    final events = eventsSnapshot.docs
        .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
        .where((e) => _isInDateRange(e.createdAt))
        .toList();
    
    final clubsMap = {for (var doc in clubsSnapshot.docs) doc.id: doc.data()};
    final usersMap = {for (var doc in usersSnapshot.docs) doc.id: doc.data()};
    
    // Build chart data by date
    Map<String, double> dailyRevenue = {};
    _totalRevenue = 0;
    _totalCount = 0; // Total PAID registrations (attendees in paid events)

    Map<String, double> clubRevenue = {};
    Map<String, double> participantRevenue = {};

    for (var event in events) {
      if (event.createdAt != null) {
        // Calculate revenue for this event
        double eventRevenue = event.price * event.attendees.length;
        
        if (eventRevenue > 0) {
           // Add to global total
          _totalRevenue += eventRevenue;
          _totalCount += event.attendees.length;
          
          // Add to daily trend (using event creation date as proxy)
          final dateKey = DateFormat('yyyy-MM-dd').format(event.createdAt!);
          dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + eventRevenue;
          
          // Add to club revenue
          clubRevenue[event.clubId] = (clubRevenue[event.clubId] ?? 0) + eventRevenue;
          
          // Add to participant revenue
          double pricePerHead = event.price;
          for (var userId in event.attendees) {
              participantRevenue[userId] = (participantRevenue[userId] ?? 0) + pricePerHead;
          }
        }
      }
    }
    
    final rawData = dailyRevenue.entries.map((e) => {
      'date': DateTime.parse(e.key),
      'count': e.value, // 'count' is used for the Y-axis value in the line chart
    }).toList();
    _chartData = _fillMissingDates(rawData);
    
    // Group by club
    _topClubs = clubRevenue.entries.map((e) {
      final clubData = clubsMap[e.key];
      return {
        'id': e.key,
        'name': clubData?['name'] ?? 'Unknown Club',
        'photoUrl': clubData?['imageUrl'],
        'revenue': e.value,
        'role': 'club',
      };
    }).toList();
    
    _topClubs.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    _topClubs = _topClubs.take(5).toList();

    // Group by Participant
    _topParticipants = participantRevenue.entries.map((e) {
      final userData = usersMap[e.key];
      return {
        'id': e.key,
        'name': userData?['name'] ?? 'Unknown User',
        'photoUrl': userData?['imageUrl'],
        'revenue': e.value,
        'email': userData?['email'] ?? '',
        'role': 'participant',
      };
    }).toList();
    _topParticipants.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    _topParticipants = _topParticipants.take(5).toList();
  }

  bool _isInDateRange(DateTime? date) {
    // If no date range selected (All Time), include everything
    if (_selectedDateRange == null) return true;
    // If date range selected but event has no date, still include it
    // (to avoid hiding data just because createdAt wasn't set)
    if (date == null) return true;
    
    final eventDate = DateTime(date.year, date.month, date.day);
    final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
    final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
    
    return (eventDate.isAtSameMomentAs(start) || eventDate.isAfter(start)) && 
           (eventDate.isAtSameMomentAs(end) || eventDate.isBefore(end));
  }

  List<Map<String, dynamic>> _buildTimeSeriesData(
    List<EventModel> events, 
    int Function(EventModel) valueExtractor,
    {bool groupByClub = false}
  ) {
    Map<String, int> dailyCounts = {};
    for (var event in events) {
      if (event.createdAt != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(event.createdAt!);
        dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + valueExtractor(event);
      }
    }
    
    return dailyCounts.entries.map((e) => {
      'date': DateTime.parse(e.key),
      'count': e.value,
    }).toList()..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  }

  String get _title {
    switch (widget.type) {
      case OverviewType.activeParticipants:
        return 'Active Participants';
      case OverviewType.activeClubs:
        return 'Active Clubs';
      case OverviewType.totalRegistrations:
        return 'Total Registrations';
      case OverviewType.eventsCreated:
        return 'Events Created';
      case OverviewType.totalReports:
        return 'Total Reports';
      case OverviewType.totalRevenue:
        return 'Revenue';
    }
  }

  Color get _themeColor {
    switch (widget.type) {
      case OverviewType.activeParticipants:
        return Colors.blue;
      case OverviewType.activeClubs:
        return Colors.blue;
      case OverviewType.totalRegistrations:
        return Colors.blue;
      case OverviewType.eventsCreated:
        return Colors.blue;
      case OverviewType.totalReports:
        return Colors.red;
      case OverviewType.totalRevenue:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          TextButton(
            onPressed: () => _selectDateRange(context),
            child: Text(
              _formatDateRange(_selectedDateRange),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _themeColor,
              backgroundColor: _themeColor.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Card
                    _buildSummaryCard(),
                    const SizedBox(height: 24),
                    
                    // Chart
                    _buildChartSection(),
                    const SizedBox(height: 24),
                    
                    // List
                    _buildListSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final isRevenue = widget.type == OverviewType.totalRevenue;
    final displayValue = isRevenue 
        ? 'RM ${_totalRevenue.toStringAsFixed(2)}'
        : _totalCount.toString();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_themeColor.withOpacity(0.8), _themeColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _themeColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayValue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          if (isRevenue) ...[
            const SizedBox(height: 8),
            Text(
              '$_totalCount paid registrations',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    if (widget.type == OverviewType.activeParticipants) {
      final total = _activeParticipantsCount + _inactiveParticipantsCount;
      return Column(
        children: [
           // 1. Interaction Timeline
           Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Interaction',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                 _chartData.isEmpty 
                  ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No activity data')))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        height: 200,
                        width: _chartData.length * 40.0 < MediaQuery.of(context).size.width - 64
                            ? MediaQuery.of(context).size.width - 64
                            : _chartData.length * 40.0,
                        padding: const EdgeInsets.fromLTRB(25, 0, 25, 0),
                        child: BarChart(
                          BarChartData(
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => Colors.black.withOpacity(0.7),
                                tooltipPadding: const EdgeInsets.all(8),
                                fitInsideHorizontally: true, 
                                fitInsideVertically: true,
                                tooltipMargin: 0,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final date = _chartData[group.x.toInt()]['date'] as DateTime;
                                  return BarTooltipItem(
                                    '${DateFormat('MMM dd').format(date)}\n',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    children: [
                                      TextSpan(
                                        text: rod.toY.toInt().toString(),
                                        style: const TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    final index = value.toInt();
                                    if (index >= 0 && index < _chartData.length) {
                                      if (_chartData.length > 10 && index % 2 != 0) {
                                        return const SizedBox();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          DateFormat('M/d').format(_chartData[index]['date']),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  interval: 1,
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            barGroups: _chartData.asMap().entries.map((e) {
                              final count = (e.value['count'] as num).toDouble();
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: count,
                                    color: Colors.blue,
                                    width: 16,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 2. Active vs Inactive Pie Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 0,
                            centerSpaceRadius: 30,
                            sections: [
                              PieChartSectionData(
                                color: Colors.blue,
                                value: total == 0 ? 1 : _activeParticipantsCount.toDouble(),
                                title: _activeParticipantsCount > 0 ? '$_activeParticipantsCount' : '',
                                radius: 35,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              PieChartSectionData(
                                color: Colors.blue.withOpacity(0.3),
                                value: _inactiveParticipantsCount.toDouble(),
                                title: _inactiveParticipantsCount > 0 ? '$_inactiveParticipantsCount' : '',
                                radius: 35,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 100,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(Colors.blue, 'Active'),
                            const SizedBox(height: 8),
                            _buildLegendItem(Colors.blue.withOpacity(0.3), 'Inactive'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (widget.type == OverviewType.activeClubs) {
      final isActivity = _clubActivityFilter == 'Activity';
      final val1 = isActivity ? _activeClubsCount : _newClubsCount;
      final val2 = isActivity ? _inactiveClubsCount : _existingClubsCount;
      final label1 = isActivity ? 'Active' : 'New';
      final label2 = isActivity ? 'Inactive' : 'Existing';
      final total = val1 + val2;

      return Column(
        children: [
           // 1. Timeline Chart
           Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Active Clubs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                 _chartData.isEmpty 
                  ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No data')))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        height: 200,
                        width: _chartData.length * 40.0 < MediaQuery.of(context).size.width - 64
                            ? MediaQuery.of(context).size.width - 64
                            : _chartData.length * 40.0,
                        padding: const EdgeInsets.fromLTRB(25, 0, 25, 0),
                        child: BarChart(
                          BarChartData(
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => Colors.black.withOpacity(0.7),
                                tooltipPadding: const EdgeInsets.all(8),
                                fitInsideHorizontally: true, 
                                fitInsideVertically: true,
                                tooltipMargin: 0,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final date = _chartData[group.x.toInt()]['date'] as DateTime;
                                  return BarTooltipItem(
                                    '${DateFormat('MMM dd').format(date)}\n',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    children: [
                                      TextSpan(
                                        text: rod.toY.toInt().toString(),
                                        style: const TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    final index = value.toInt();
                                    if (index >= 0 && index < _chartData.length) {
                                      if (_chartData.length > 10 && index % 2 != 0) {
                                        return const SizedBox();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          DateFormat('M/d').format(_chartData[index]['date']),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  interval: 1,
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            barGroups: _chartData.asMap().entries.map((e) {
                              final count = (e.value['count'] as num).toDouble();
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: count,
                                    color: Colors.blue,
                                    width: 16,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 2. Club Activity/Status Pie Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Club Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildToggleOptionForClubs('Activity'),
                          _buildToggleOptionForClubs('Status'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 0,
                            centerSpaceRadius: 30,
                            sections: [
                              PieChartSectionData(
                                color: Colors.blue,
                                value: total == 0 ? 1 : val1.toDouble(),
                                title: val1 > 0 ? '$val1' : '',
                                radius: 40,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              PieChartSectionData(
                                color: Colors.blue.withOpacity(0.4),
                                value: val2.toDouble(),
                                title: val2 > 0 ? '$val2' : '',
                                radius: 40,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 120,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(Colors.blue, label1),
                            const SizedBox(height: 8),
                            _buildLegendItem(Colors.blue.withOpacity(0.4), label2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (widget.type == OverviewType.totalReports) {
      return Column(
        children: [
           // 1. Report Timeline
           Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Trend',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                 _chartData.isEmpty 
                  ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No data')))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        height: 200,
                        width: _chartData.length * 40.0 < MediaQuery.of(context).size.width - 64
                            ? MediaQuery.of(context).size.width - 64
                            : _chartData.length * 40.0,
                        padding: const EdgeInsets.fromLTRB(25, 0, 25, 0),
                        child: BarChart(
                          BarChartData(
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => Colors.black.withOpacity(0.7),
                                tooltipPadding: const EdgeInsets.all(8),
                                fitInsideHorizontally: true, 
                                fitInsideVertically: true,
                                tooltipMargin: 0,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final date = _chartData[group.x.toInt()]['date'] as DateTime;
                                  return BarTooltipItem(
                                    '${DateFormat('MMM dd').format(date)}\n',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    children: [
                                      TextSpan(
                                        text: rod.toY.toInt().toString(),
                                        style: const TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    final index = value.toInt();
                                    if (index >= 0 && index < _chartData.length) {
                                      if (_chartData.length > 10 && index % 2 != 0) {
                                        return const SizedBox();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          DateFormat('M/d').format(_chartData[index]['date']),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  interval: 1,
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            barGroups: _chartData.asMap().entries.map((e) {
                              final count = (e.value['count'] as num).toDouble();
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: count,
                                    color: Colors.red,
                                    width: 16,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 2. Reason Breakdown Pie Chart
          if (_reportReasonCounts.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        child: PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                if (event is FlTapUpEvent && pieTouchResponse != null && pieTouchResponse.touchedSection != null) {
                                  final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                  if (index >= 0 && index < _reportReasonCounts.length) {
                                      final reason = _reportReasonCounts.keys.elementAt(index);
                                      final count = _reportReasonCounts.values.elementAt(index);
                                      _showReasonDetails(context, reason, count);
                                  }
                                }
                              },
                            ),
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                            sections: List.generate(_reportReasonCounts.length, (index) {
                              final reason = _reportReasonCounts.keys.elementAt(index);
                              final count = _reportReasonCounts.values.elementAt(index);
                              final color = _getReportColor(index);
                              return PieChartSectionData(
                                color: color,
                                value: count.toDouble(),
                                title: '$count',
                                radius: 40,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 120,
                        child: SingleChildScrollView(
                          child: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: List.generate(_reportReasonCounts.length, (index) {
                               final reason = _reportReasonCounts.keys.elementAt(index);
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 8.0),
                                 child: _buildLegendItem(_getReportColor(index), reason),
                               );
                             }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Center(child: Text('Tap on chart for details', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic))),
              ],
            ),
          ),
        ],
      );
    }

    if (widget.type == OverviewType.totalRevenue) {
      return Column(
        children: [
           // 1. Revenue Timeline
           Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revenue Trend (RM)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                 _chartData.isEmpty 
                  ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No revenue data')))
                  : Builder(
                      builder: (context) {
                        double maxY = 0;
                        if (_chartData.isNotEmpty) {
                          maxY = _chartData.map((e) => (e['count'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
                        }
                        if (maxY <= 0) maxY = 100;
                        final displayMaxY = maxY * 1.2;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            height: 400,
                            width: _chartData.length * 40.0 < MediaQuery.of(context).size.width - 64
                                ? MediaQuery.of(context).size.width - 64
                                : _chartData.length * 40.0,
                            padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                            child: BarChart(
                              BarChartData(
                                maxY: displayMaxY,
                                barTouchData: BarTouchData(
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipColor: (_) => Colors.black.withOpacity(0.7),
                                    tooltipPadding: const EdgeInsets.all(8),
                                    fitInsideHorizontally: true, 
                                    fitInsideVertically: true,
                                    tooltipMargin: 0,
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      final date = _chartData[group.x.toInt()]['date'] as DateTime;
                                      return BarTooltipItem(
                                        '${DateFormat('MMM dd').format(date)}\n',
                                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        children: [
                                          TextSpan(
                                            text: 'RM ${rod.toY.toStringAsFixed(2)}',
                                            style: const TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                gridData: const FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index >= 0 && index < _chartData.length) {
                                          if (_chartData.length > 10 && index % 2 != 0) {
                                            return const SizedBox();
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              DateFormat('M/d').format(_chartData[index]['date']),
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
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                                          style: const TextStyle(fontSize: 9),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: _chartData.asMap().entries.map((e) {
                                  final count = (e.value['count'] as num).toDouble();
                                  return BarChartGroupData(
                                    x: e.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: count,
                                        color: Colors.teal,
                                        width: 16,
                                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      }
                    ),
              ],
            ),
          ),
        ],
      );
    }
  
    if (widget.type == OverviewType.eventsCreated) {
      // Setup data for pie chart
      final isSchedule = _eventDistributionFilter == 'Schedule';
      final val1 = isSchedule ? _weekdayVal : _freeVal;
      final val2 = isSchedule ? _weekendVal : _paidVal;
      final label1 = isSchedule ? 'Weekday' : 'Free';
      final label2 = isSchedule ? 'Weekend' : 'Paid';
      final total = val1 + val2;
      
      return Column(
        children: [
           // 1. Creation Trend Timeline (Styled like Registration Timeline)
           Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Creation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                 _chartData.isEmpty 
                  ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No data')))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        height: 200,
                        width: _chartData.length * 40.0 < MediaQuery.of(context).size.width - 64
                            ? MediaQuery.of(context).size.width - 64
                            : _chartData.length * 40.0,
                        padding: const EdgeInsets.fromLTRB(25, 0, 25, 0),
                        child: BarChart(
                          BarChartData(
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => Colors.black.withOpacity(0.7),
                                tooltipPadding: const EdgeInsets.all(8),
                                fitInsideHorizontally: true, 
                                fitInsideVertically: true,
                                tooltipMargin: 0,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final date = _chartData[group.x.toInt()]['date'] as DateTime;
                                  return BarTooltipItem(
                                    '${DateFormat('MMM dd').format(date)}\n',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    children: [
                                      TextSpan(
                                        text: rod.toY.toInt().toString(),
                                        style: const TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    final index = value.toInt();
                                    if (index >= 0 && index < _chartData.length) {
                                      if (_chartData.length > 10 && index % 2 != 0) {
                                        return const SizedBox();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          DateFormat('M/d').format(_chartData[index]['date']),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  interval: 1,
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            barGroups: _chartData.asMap().entries.map((e) {
                              final count = (e.value['count'] as num).toDouble();
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: count,
                                    color: Colors.blue,
                                    width: 16,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
           const SizedBox(height: 24),

           // 2. Distribution Pie Chart
           Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Distribution',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildToggleOption('Schedule'),
                          _buildToggleOption('Pricing'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 0,
                            centerSpaceRadius: 30,
                            sections: [
                              PieChartSectionData(
                                color: Colors.blue,
                                value: total == 0 ? 1 : val1.toDouble(),
                                title: val1 > 0 ? '$val1' : '',
                                radius: 40,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              PieChartSectionData(
                                color: Colors.blue.withOpacity(0.5),
                                value: val2.toDouble(),
                                title: val2 > 0 ? '$val2' : '',
                                radius: 40,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 120,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(Colors.blue, label1), // Weekday / Free
                            const SizedBox(height: 8),
                            _buildLegendItem(Colors.blue.withOpacity(0.5), label2), // Weekend / Paid
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (widget.type == OverviewType.totalRegistrations) {
      return Column(
        children: [
          // 1. Timeline Chart
           Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Signups',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                 _chartData.isEmpty 
                  ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No data')))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        height: 200,
                        width: _chartData.length * 40.0 < MediaQuery.of(context).size.width - 64
                            ? MediaQuery.of(context).size.width - 64
                            : _chartData.length * 40.0,
                        padding: const EdgeInsets.fromLTRB(25, 0, 25, 0),
                        child: BarChart(
                          BarChartData(
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => Colors.black.withOpacity(0.7),
                                tooltipPadding: const EdgeInsets.all(8),
                                fitInsideHorizontally: true, 
                                fitInsideVertically: true,
                                tooltipMargin: 0,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final date = _chartData[group.x.toInt()]['date'] as DateTime;
                                  return BarTooltipItem(
                                    '${DateFormat('MMM dd').format(date)}\n',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    children: [
                                      TextSpan(
                                        text: rod.toY.toInt().toString(),
                                        style: const TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    final index = value.toInt();
                                    if (index >= 0 && index < _chartData.length) {
                                      if (_chartData.length > 10 && index % 2 != 0) {
                                        return const SizedBox();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          DateFormat('M/d').format(_chartData[index]['date']),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  interval: 1,
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            barGroups: _chartData.asMap().entries.map((e) {
                              final count = (e.value['count'] as num).toDouble();
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: count,
                                    color: Colors.blue,
                                    width: 16,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 2. Member Composition Pie Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Member Composition',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 0,
                            centerSpaceRadius: 30,
                            sections: [
                              PieChartSectionData(
                                color: Colors.blue,
                                value: (_newUsersCount + _returningUsersCount) == 0 ? 1 : _returningUsersCount.toDouble(), // Default to 1 if empty to show ring
                                title: _returningUsersCount > 0 ? '${_returningUsersCount}' : '',
                                radius: 40,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              PieChartSectionData(
                                color: Colors.blue.withOpacity(0.4),
                                value: _newUsersCount.toDouble(),
                                title: _newUsersCount > 0 ? '${_newUsersCount}' : '',
                                radius: 40,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 120,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(Colors.blue.withOpacity(0.4), 'New Users'),
                            const SizedBox(height: 8),
                            _buildLegendItem(Colors.blue, 'Returning'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  
    if (_chartData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No data available for chart', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trend Over Time',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          _chartData.isEmpty 
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No trend data')))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                height: 200,
                width: _chartData.length * 60.0 < MediaQuery.of(context).size.width - 64
                    ? MediaQuery.of(context).size.width - 64
                    : _chartData.length * 60.0,
                child: CustomPaint(
                  size: const Size(double.infinity, 200),
                  painter: LineChartPainter(
                    data: _chartData,
                    color: _themeColor,
                    isRevenue: widget.type == OverviewType.totalRevenue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    // Shorten common long report reasons
    String displayText = text;
    if (text.toLowerCase().contains('inappropriate')) displayText = 'Inappropriate';
    if (text.toLowerCase().contains('misleading')) displayText = 'Misleading';

    return Row(
      children: [
        const SizedBox(width: 4), // Small extra nudge to the right
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            displayText,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListSection() {
    // Special case for Active Participants Top 5 List
    if (widget.type == OverviewType.activeParticipants) {
      if (_listData.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text('No active participants found', style: TextStyle(color: Colors.grey)),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Top Active Participants',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _listData.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final item = _listData[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      image: item['photoUrl'] != null && item['photoUrl'].isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(item['photoUrl']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: item['photoUrl'] == null || item['photoUrl'].isEmpty
                        ? Center(
                            child: Text(
                              (item['name'] as String).isNotEmpty ? item['name'][0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          )
                        : null,
                  ),
                  title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(item['email'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item['count']} activities',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // Special case for Active Clubs Top 5 List
    if (widget.type == OverviewType.activeClubs) {
      if (_listData.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text('No active clubs found', style: TextStyle(color: Colors.grey)),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Top Active Clubs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _listData.length > 5 ? 5 : _listData.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final item = _listData[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    backgroundImage: item['photoUrl'] != null && item['photoUrl'].isNotEmpty
                        ? NetworkImage(item['photoUrl'])
                        : null,
                    child: item['photoUrl'] == null || item['photoUrl'].isEmpty
                        ? const Icon(Icons.group, color: Colors.blue)
                        : null,
                  ),
                  title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(item['email'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item['eventCount']} events',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
    
    // Special case for Total Reports Top 5 Events
    if (widget.type == OverviewType.totalReports) {
      if (_topEvents.isEmpty) {
        return Container(
           padding: const EdgeInsets.all(32),
           decoration: BoxDecoration(
             color: Colors.grey[100],
             borderRadius: BorderRadius.circular(16),
           ),
           child: const Center(
             child: Text('No reports found', style: TextStyle(color: Colors.grey)),
           ),
        );
      }
      
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Most Reported Events',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topEvents.length > 5 ? 5 : _topEvents.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final item = _topEvents[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                  title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(item['clubName'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${item['count']}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // Special case for Events Created Top 5 Events
    if (widget.type == OverviewType.eventsCreated) {
      if (_topEvents.isEmpty && _weekdayVal == 0 && _weekendVal == 0 && _freeVal == 0 && _paidVal == 0) {
        return Container(
           padding: const EdgeInsets.all(32),
           decoration: BoxDecoration(
             color: Colors.grey[100],
             borderRadius: BorderRadius.circular(16),
           ),
           child: const Center(
             child: Text('No events found', style: TextStyle(color: Colors.grey)),
           ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Top 5 Events by Registration',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topEvents.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final item = _topEvents[index];
                // In events created, we use a global total for percentage if we wanted, 
                // but since these are potentially independent of the query time (or rely on it),
                // we'll calculate based on highest or total. Let's stick to percentage of total attendees in this set.
                // Assuming we want visual percentage. 
                // For 'eventsCreated' in _loadEventsData we already computed 'percentage' or similar.
                // Actually looking at _loadEventsData, I added logic to calculate _topEvents with percentage.
                
                final count = item['count'] as int;
                final percentage = item['percentage'] as double;
                final percentageStr = '${(percentage * 100).toStringAsFixed(0)}%';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${index + 1}. ${item['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$count ($percentageStr)',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.grey[100],
                          color: _themeColor,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['clubName'],
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // Special case for Total Registrations (Participants & Clubs)
    if (widget.type == OverviewType.totalRegistrations) {
      if (_topParticipants.isEmpty && _topClubs.isEmpty && _totalCount == 0) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text('No registration data available', style: TextStyle(color: Colors.grey)),
          ),
        );
      }

      return Column(
        children: [
          // Top Participants
          if (_topParticipants.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Top Participants by Registrations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _topParticipants.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, index) {
                    final item = _topParticipants[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        backgroundImage: item['photoUrl'] != null && item['photoUrl'].isNotEmpty
                            ? NetworkImage(item['photoUrl'])
                            : null,
                        child: item['photoUrl'] == null || item['photoUrl'].isEmpty
                            ? const Icon(Icons.person, color: Colors.blue)
                            : null,
                      ),
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(item['email'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${item['count']}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Top Clubs
          if (_topClubs.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Top Clubs by Registrations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                 ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _topClubs.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, index) {
                    final item = _topClubs[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        backgroundImage: item['photoUrl'] != null && item['photoUrl'].isNotEmpty
                            ? NetworkImage(item['photoUrl'])
                            : null,
                        child: item['photoUrl'] == null || item['photoUrl'].isEmpty
                            ? const Icon(Icons.group, color: Colors.blue)
                            : null,
                      ),
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${item['count']}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Special case for Total Revenue (Participants & Clubs)
    if (widget.type == OverviewType.totalRevenue) {
       if (_topParticipants.isEmpty && _topClubs.isEmpty && _totalRevenue == 0) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text('No revenue data available', style: TextStyle(color: Colors.grey)),
          ),
        );
      }

      return Column(
        children: [
          // Top Participants by Money Spent
          if (_topParticipants.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Top Participant by Money Spent',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _topParticipants.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, index) {
                    final item = _topParticipants[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.withOpacity(0.1),
                        backgroundImage: item['photoUrl'] != null && item['photoUrl'].isNotEmpty
                            ? NetworkImage(item['photoUrl'])
                            : null,
                        child: item['photoUrl'] == null || item['photoUrl'].isEmpty
                            ? const Icon(Icons.person, color: Colors.teal)
                            : null,
                      ),
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(item['email'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      trailing: Text(
                        'RM ${(item['revenue'] as double).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      onTap: () {
                         Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnalyticsDetailScreen(
                              id: item['id'],
                              name: item['name'],
                              email: item['email'],
                              role: 'participant',
                              imageUrl: item['photoUrl'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // Top Clubs by Money Revenue
          if (_topClubs.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                 BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
             child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Top Club by Money Revenue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _topClubs.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, index) {
                    final item = _topClubs[index];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          image: item['photoUrl'] != null && item['photoUrl'].isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(item['photoUrl']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ), 
                        child: item['photoUrl'] == null || item['photoUrl'].isEmpty
                            ? const Icon(Icons.business_center, color: Colors.teal, size: 20)
                            : null,
                      ),
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Text(
                        'RM ${(item['revenue'] as double).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                       onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnalyticsDetailScreen(
                              id: item['id'],
                              name: item['name'],
                              email: '',
                              role: 'club',
                              imageUrl: item['photoUrl'],
                              clubId: item['id'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Default list view for other types
    if (_listData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No data available', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _listData.length > 20 ? 20 : _listData.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final item = _listData[index];
              return _buildListItem(item);
            },
          ),
          if (_listData.length > 20)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Showing 20 of ${_listData.length} items',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> item) {
    switch (widget.type) {
      case OverviewType.activeParticipants:
      case OverviewType.activeClubs:
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _themeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              image: item['photoUrl'] != null && item['photoUrl'].isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(item['photoUrl']),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: item['photoUrl'] == null || item['photoUrl'].isEmpty
                ? Center(
                    child: Text(
                      (item['name'] as String).isNotEmpty ? item['name'][0].toUpperCase() : '?',
                      style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold),
                    ),
                  )
                : null,
          ),
          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(item['email'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.type == OverviewType.activeParticipants)
                Text('${item['count']} events', style: TextStyle(fontWeight: FontWeight.bold, color: _themeColor))
              else ...[
                Text('${item['eventCount']} events', style: TextStyle(fontWeight: FontWeight.bold, color: _themeColor)),
                Text('${item['regCount']} regs', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnalyticsDetailScreen(
                  id: item['id'],
                  name: item['name'],
                  email: item['email'] ?? '',
                  role: item['role'],
                  imageUrl: item['photoUrl'],
                  clubId: item['role'] == 'club' ? item['id'] : null,
                ),
              ),
            );
          },
        );
      
      case OverviewType.totalRegistrations:
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _themeColor.withOpacity(0.1),
            child: Icon(Icons.person, color: _themeColor),
          ),
          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['eventName'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              if (item['date'] != null)
                Text(DateFormat('MMM d, yyyy').format(item['date']), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: item['paymentStatus'] == 'paid' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item['paymentStatus'] ?? 'N/A',
                  style: TextStyle(
                    color: item['paymentStatus'] == 'paid' ? Colors.green : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (item['amount'] != null && item['amount'] > 0)
                Text('RM ${(item['amount'] as double).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: _themeColor)),
            ],
          ),
          isThreeLine: true,
        );
      
      case OverviewType.eventsCreated:
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _themeColor.withOpacity(0.1),
            child: Icon(Icons.event, color: _themeColor),
          ),
          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['clubName'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              if (item['date'] != null)
                Text('Event: ${DateFormat('MMM d, yyyy').format(item['date'])}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${item['attendeeCount']} attendees', style: TextStyle(fontWeight: FontWeight.bold, color: _themeColor)),
              if (item['price'] != null && item['price'] > 0)
                Text('RM ${(item['price'] as double).toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          isThreeLine: true,
        );
      
      case OverviewType.totalReports:
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _getStatusColor(item['status']).withOpacity(0.1),
            child: Icon(Icons.flag, color: _getStatusColor(item['status'])),
          ),
          title: Text(item['eventName'], style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['reason'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              if (item['date'] != null)
                Text(DateFormat('MMM d, yyyy').format(item['date']), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(item['status']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item['status'] ?? 'pending',
              style: TextStyle(
                color: _getStatusColor(item['status']),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          isThreeLine: true,
        );
      
      case OverviewType.totalRevenue:
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _themeColor.withOpacity(0.1),
            backgroundImage: item['photoUrl'] != null && item['photoUrl'].isNotEmpty
                ? NetworkImage(item['photoUrl'])
                : null,
            child: item['photoUrl'] == null || item['photoUrl'].isEmpty
                ? Text(
                    (item['name'] as String).isNotEmpty ? item['name'][0].toUpperCase() : '?',
                    style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Text(
            'RM ${(item['revenue'] as double).toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: _themeColor, fontSize: 16),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnalyticsDetailScreen(
                  id: item['id'],
                  name: item['name'],
                  email: '',
                  role: 'club',
                  imageUrl: item['photoUrl'],
                  clubId: item['id'], // This is the club document ID
                ),
              ),
            );
          },
        );
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.grey;
      case 'pending':
      default:
        return Colors.orange;
    }
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
                  setState(() => _selectedDateRange = null);
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
                    firstDate: DateTime(2024, 1, 1),
                    lastDate: DateTime.now(),
                    initialDateRange: _selectedDateRange,
                  );
                  if (picked != null) {
                    setState(() => _selectedDateRange = picked);
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
    return '${DateFormat('MMM d').format(range.start)} - ${DateFormat('MMM d').format(range.end)}';
  }

  Widget _buildToggleOptionForClubs(String text) {
    final isSelected = _clubActivityFilter == text;
    return GestureDetector(
      onTap: () => setState(() => _clubActivityFilter = text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getReportColor(int index) {
    const list = [
      Color(0xFFE57373), // Red 300
      Color(0xFFBA68C8), // Purple 300
      Color(0xFF64B5F6), // Blue 300
      Color(0xFF81C784), // Green 300
      Color(0xFFFFB74D), // Orange 300
      Color(0xFFA1887F), // Brown 300
      Color(0xFF90A4AE), // Blue Grey 300
    ];
    return list[index % list.length];
  }

  void _showReasonDetails(BuildContext context, String reason, int count) {
     showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.report_problem, color: Colors.red, size: 40),
              const SizedBox(height: 16),
              Text(
                reason,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$count reports',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                     topLeft: Radius.circular(16),
                     topRight: Radius.circular(16),
                     bottomRight: Radius.circular(16),
                     bottomLeft: Radius.zero,
                  ),
                ),
                child: Text(
                   'Events flagged as "$reason" currently have $count active reports.',
                   style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  Widget _buildToggleOption(String text) {
    final isSelected = _eventDistributionFilter == text;
    return GestureDetector(
      onTap: () => setState(() => _eventDistributionFilter = text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
