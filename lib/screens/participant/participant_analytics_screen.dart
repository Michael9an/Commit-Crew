import 'package:event_app/models/event.dart';
import 'package:event_app/models/register.dart';
import 'package:event_app/services/event_service.dart';
import 'package:event_app/services/registration_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ParticipantAnalyticsScreen extends StatefulWidget {
  const ParticipantAnalyticsScreen({super.key});

  @override
  State<ParticipantAnalyticsScreen> createState() => _ParticipantAnalyticsScreenState();
}

class _ParticipantAnalyticsScreenState extends State<ParticipantAnalyticsScreen> {
  final RegistrationService _registrationService = RegistrationService();
  final EventService _eventService = EventService();
  
  bool _isLoading = true;
  List<Register> _allRegistrations = [];
  List<ParticipationActivity> _allActivities = [];
  Map<String, EventModel> _eventsMap = {};
  
  // Stats
  int _totalRegistrations = 0;
  int _attendedEvents = 0;
  int _upcomingEvents = 0;
  double _totalSpent = 0.0;
  
  // Filter for activities
  String _selectedPeriod = 'All Time';
  final List<String> _periods = ['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'All Time'];

  String _selectedType = 'All';
  final List<String> _types = ['All', 'Registration', 'Attend'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Fetch all user registrations
      final registrations = await _registrationService.getUserRegistrations(userId: user.uid);
      
      // 2. Fetch associated events to get dates and details
      final eventIds = registrations.map((r) => r.eventId).toSet();
      final Map<String, EventModel> events = {};
      
      // Fetch events in parallel
      await Future.wait(eventIds.map((id) async {
        final event = await _eventService.getEventById(id);
        if (event != null) {
          events[id] = event;
        }
      }));

      // 3. Calculate Stats
      int totalReg = registrations.length;
      int attended = registrations.where((r) => r.status == 'attended').length;
      double spent = registrations.fold(0.0, (sum, r) => sum + r.amountPaid);
      
      int upcoming = 0;
      final now = DateTime.now();
      
      List<ParticipationActivity> activities = [];

      for (var r in registrations) {
        // Create Registration activity
        activities.add(ParticipationActivity(
          date: r.registrationDate,
          type: 'Registration',
          registration: r,
          event: events[r.eventId],
        ));

        // Create Attend activity if attended
        if (r.status == 'attended' || r.attendedAt != null) {
          final attendDate = r.attendedAt ?? r.registrationDate; // Fallback if attendedAt is null but status attended
          activities.add(ParticipationActivity(
            date: attendDate,
            type: 'Attend',
            registration: r,
            event: events[r.eventId],
          ));
        }

        // Consider upcoming if status is registered/pending and event date is future
        // Or simply if event date is future regardless of status (unlikely if cancelled)
        final event = events[r.eventId];
        if (event != null) {
          // Parse event date string to DateTime
          // EventModel.date is String (likely millisecondsSinceEpoch based on previous reads)
          try {
             final eventDate = DateTime.fromMillisecondsSinceEpoch(int.parse(event.date));
             if (eventDate.isAfter(now) && r.status != 'cancelled') {
               upcoming++;
             }
          } catch (e) {
            // Handle date parse error if any
          }
        }
      }

      // Sort activities by date descending
      activities.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _allRegistrations = registrations;
          _allActivities = activities;
          _eventsMap = events;
          _totalRegistrations = totalReg;
          _attendedEvents = attended;
          _upcomingEvents = upcoming;
          _totalSpent = spent;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ParticipationActivity> _getFilteredActivities() {
    var activities = _allActivities;

    // Filter by Type
    if (_selectedType != 'All') {
      activities = activities.where((a) => a.type == _selectedType).toList();
    }

    if (_selectedPeriod == 'All Time') return activities;

    final now = DateTime.now();
    int days = 0;
    
    if (_selectedPeriod == 'Last 7 Days') days = 7;
    else if (_selectedPeriod == 'Last 30 Days') days = 30;
    else if (_selectedPeriod == 'Last 90 Days') days = 90;

    final cutoff = now.subtract(Duration(days: days));
    
    return activities.where((a) {
      return a.date.isAfter(cutoff);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Analytics'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : RefreshIndicator(
            onRefresh: _fetchData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSummaryCards(),
                   const SizedBox(height: 20),
                   _buildMoneySpentCard(),
                   const SizedBox(height: 24),
                   _buildRecentActivitiesHeader(),
                   const SizedBox(height: 12),
                   _buildActivitiesList(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Registrations', _totalRegistrations.toString())),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Attended', _attendedEvents.toString())),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Upcoming', _upcomingEvents.toString())),
      ],
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMoneySpentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Money Spent',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${_totalSpent.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitiesHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activities',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                   contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                   labelText: 'Type',
                ),
                items: _types.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedType = newValue!;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedPeriod,
                decoration: InputDecoration(
                   contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                   labelText: 'Period',
                ),
                items: _periods.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedPeriod = newValue!;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivitiesList() {
    final filtered = _getFilteredActivities();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(
            'No activities found for selection',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final activity = filtered[index];
        final event = activity.event;
        
        IconData icon;
        Color iconColor;
        String titlePrefix;

        if (activity.type == 'Attend') {
          icon = Icons.check_circle;
          iconColor = Colors.green;
        } else {
          icon = Icons.event;
          iconColor = Colors.blue;
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.1),
              child: Icon(
                icon,
                color: iconColor,
              ),
            ),
            title: Text(
              event?.name ?? 'Unknown Event',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('MMM dd, yyyy').format(activity.date)),
                if (activity.type == 'Registration' && activity.registration.amountPaid > 0)
                  Text(
                    'Paid: \$${activity.registration.amountPaid.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.green[700], fontSize: 12),
                  ),
              ],
            ),
            trailing: activity.type == 'Registration' 
              ? Chip(
              label: Text(
                 activity.registration.status[0].toUpperCase() + activity.registration.status.substring(1),
                 style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: _getStatusColor(activity.registration.status),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ) : null,
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'attended': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'registered': return Colors.blue;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }
}

class ParticipationActivity {
  final DateTime date;
  final String type; // 'Registration', 'Attend'
  final Register registration;
  final EventModel? event;

  ParticipationActivity({
    required this.date,
    required this.type,
    required this.registration,
    this.event,
  });
}
