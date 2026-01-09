import 'package:event_app/models/event.dart';
import 'package:event_app/models/register.dart';
import 'package:event_app/models/participation_activity.dart';
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
        // If attended, we only show the "Attend" activity
        if (r.status == 'attended' || r.attendedAt != null) {
          final attendDate = r.attendedAt ?? r.registrationDate;
          activities.add(ParticipationActivity(
            date: attendDate,
            type: 'Attend',
            registration: r,
            event: events[r.eventId],
          ));
        } else {
          // If not attended (pending, registered, cancelled), show selection/registration
          activities.add(ParticipationActivity(
            date: r.registrationDate,
            type: 'Registration',
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

  void _showActivityDetails(ParticipationActivity activity) {
    if (activity.event == null) return;
    final event = activity.event!;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Status Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(activity.registration.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(activity.registration.status, activity.type == 'Attend'),
                      size: 16,
                      color: _getStatusColor(activity.registration.status),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      activity.type == 'Attend' 
                        ? 'Attended' 
                        : (activity.registration.status[0].toUpperCase() + activity.registration.status.substring(1)),
                      style: TextStyle(
                        color: _getStatusColor(activity.registration.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                event.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                event.clubName,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Info Rows
              _buildDetailRow(Icons.calendar_today_outlined, 'DATE', DateFormat('EEEE, MMMM d, yyyy').format(activity.date)),
              const SizedBox(height: 16),
              
              // Time - prefer showing event time range, or attendance time if attended
              if (activity.type == 'Attend')
                _buildDetailRow(Icons.access_time, 'TIME ATTENDED', DateFormat('HH:mm').format(activity.date))
              else
                _buildDetailRow(Icons.access_time, 'TIME', '${event.startTime} - ${event.endTime}'),
                
              const SizedBox(height: 16),
              _buildDetailRow(Icons.location_on_outlined, 'LOCATION', event.location),
              const SizedBox(height: 16),
              _buildDetailRow(
                Icons.payment_outlined, 
                'PAYMENT', 
                activity.registration.amountPaid > 0 
                  ? 'Paid \$${activity.registration.amountPaid.toStringAsFixed(2)}' 
                  : 'Free'
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.grey[600], size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
        final status = activity.registration.status;
        final isAttended = activity.type == 'Attend' || status == 'attended';
        final isCancelled = status == 'cancelled';

        // Styling constants
        final statusColor = _getStatusColor(status);
        final dateColor = isCancelled ? Colors.red : (isAttended ? Colors.green : Colors.blue);
        
        return GestureDetector(
          onTap: () => _showActivityDetails(activity),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Date Box (Left)
                Container(
                  width: 50,
                  height: 54,
                  decoration: BoxDecoration(
                    color: dateColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('MMM').format(activity.date).toUpperCase(),
                        style: TextStyle(
                          color: dateColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('d').format(activity.date),
                        style: TextStyle(
                          color: dateColor.shade900,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Info (Middle)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event?.name ?? 'Unknown Event',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            event?.category ?? 'Event',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                          if (activity.registration.amountPaid > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '\$${activity.registration.amountPaid.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),

                // Icon (Right)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(status, isAttended),
                    color: statusColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getStatusIcon(String status, bool isAttended) {
    if (isAttended) return Icons.check_circle_outline;
    switch (status) {
      case 'cancelled': return Icons.cancel_outlined;
      case 'registered': return Icons.confirmation_number_outlined;
      case 'pending': return Icons.hourglass_empty;
      default: return Icons.info_outline;
    }
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

