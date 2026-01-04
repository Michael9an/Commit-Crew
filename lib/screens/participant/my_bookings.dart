import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

// --- SCREENS ---
import '../../screens/participant/event_discovery.dart';

// --- MODELS ---
import '../../models/event.dart';
import '../../models/register.dart';
import '../../models/user.dart';

// --- SERVICES ---
import '../../services/registration_service.dart';
import '../../services/auth_service.dart';
import '../../screens/participant/event_detail_screen.dart'; // For navigation

class MyBookingsScreen extends StatefulWidget {
  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  // --- SERVICES ---
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();

  // --- STATE VARIABLES ---
  List<Register> _myRegistrations = [];
  List<EventModel> _registeredEvents = []; // This will store events fetched separately
  Map<String, EventModel> _eventMap = {}; // Map eventId -> EventModel
  bool _isLoading = true;
  String? _errorMessage;
  String _currentFilter = 'All';

  @override
  void initState() {
    super.initState();

    // Debug Logging
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('🔄 MyBookingsScreen initialized');
    
    // Get current user first
      final user = await _authService.getCurrentUser();
      if (user != null) {
        print('👤 Current user: ${user.id}, ${user.email}');
        
        // Debug registration service
        await _registrationService.debugUserRegistrations(user.id, user.email);
      } else {
        print('❌ No user found!');
      }
      
      // Load registrations
      _loadMyRegistrations();
    });
  }

  Future<void> _loadMyRegistrations() async {
    try {
      print('=== STARTING LOAD REGISTRATIONS ===');

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = await _authService.getCurrentUser();
      if (user == null) {
        print('❌ No user logged in');
        if(mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Please sign in to view your bookings';
          });
        }
        return;
      }

      print('✅ User logged in: ID=${user.id}, Email=${user.email}');

      // Test registration service
      try {
        // Add null check here
        if (_registrationService != null) {
          await _registrationService.testRegistrationConnection();
        }
      } catch (e) {
        print('❌ Registration service test failed: $e');
      }

      // Fetch registrations for the current user
      print('📋 Fetching registrations for user...');
      final registrations = await _registrationService.getUserRegistrations(
        userId: user.id,
        email: user.email,
      );

      print('📊 Found ${registrations.length} registrations:');
      for (var reg in registrations) {
        print('  - ID: ${reg.id}, Event: ${reg.eventId}, Status: ${reg.status}');
      }

      if (registrations.isEmpty) {
        print('ℹ️ No registrations found, checking Firestore directly...');

        // Direct Firestore query for debugging
        final snapshot = await FirebaseFirestore.instance
            .collection('registers')
            .where('userId', isEqualTo: user.id)
            .get();

        print('Direct Firestore query found ${snapshot.docs.length} documents');
        for (var doc in snapshot.docs) {
          print('  Doc: ${doc.id}, Data: ${doc.data()}');
        }
      }

      // Fetch events for each registration
      final List<EventModel> events = [];
      final Map<String, EventModel> eventMap = {};

      for (var registration in registrations) {
        try {
          print('🔍 Fetching event for registration: ${registration.eventId}');
          final event = await _fetchEventById(registration.eventId);
          if (event != null) {
            events.add(event);
            eventMap[registration.eventId] = event;
            print('✅ Found event: ${event.name}');
          } else {
            print('❌ Event ${registration.eventId} not found');
          }
        } catch (e) {
          print('❌ Error fetching event ${registration.eventId}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _myRegistrations = registrations;
          _registeredEvents = events;
          _eventMap = eventMap;
          _isLoading = false;
        });

        print('✅ Load complete: ${registrations.length} registrations, ${events.length} events');
        print('=== LOAD REGISTRATIONS COMPLETE ===');
      }
    } catch (e) {
      print('❌ ERROR in _loadMyRegistrations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load bookings: ${e.toString()}';
        });
      }
    }
  }

  Future<EventModel?> _fetchEventById(String eventId) async {
    try {
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();
      
      if (eventDoc.exists) {
        final data = eventDoc.data() as Map<String, dynamic>;
        return EventModel.fromFirestore(data, eventDoc.id);
      }
      return null;
    } catch (e) {
      print('Error fetching event $eventId: $e');
      return null;
    }
  }

  // Helper to get status color based on Register status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'registered':
        return Colors.green;
      case 'attended':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'no_show':
        return Colors.grey;
      case 'pending': // For payment status
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Get display status text
  String _getDisplayStatus(Register registration) {
    if (registration.status == 'registered') {
      if (registration.paymentStatus == 'pending' && registration.amountPaid > 0) {
        return 'Payment Pending';
      }
      return registration.displayStatus;
    }
    return registration.displayStatus;
  }

  // Check if registration is free
  bool _isRegistrationFree(Register registration) {
    return registration.amountPaid == 0;
  }

  // Filter registrations by status
  List<Register> _getFilteredRegistrations() {
    if (_currentFilter == 'All') return _myRegistrations;
    
    return _myRegistrations.where((registration) {
      final displayStatus = _getDisplayStatus(registration);
      return displayStatus.toLowerCase() == _currentFilter.toLowerCase();
    }).toList();
  }

  // Format date for display
  String _formatDate(DateTime? date) {
    if (date == null) return 'Date not set';
    return '${date.day}/${date.month}/${date.year}';
  }

  // Get the event for a registration
  EventModel? _getEventForRegistration(Register registration) {
    return _eventMap[registration.eventId];
  }

  Widget _buildBookingCard(Register registration) {
    final event = _getEventForRegistration(registration);
    final displayStatus = _getDisplayStatus(registration);
    final statusColor = _getStatusColor(registration.status);
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: event != null ? () {
          // Navigate to event details
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParticipantEventDetailScreen(
                event: event,
              ),
            ),
          );
        } : null,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event name and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event?.name ?? 'Event not found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (event?.clubName != null)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'by ${event!.clubName}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      displayStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Event date and time
              if (event != null)
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text(
                          event.formattedDate,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text(
                          event.formattedTime,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Location
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.location,
                            style: TextStyle(color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Text(
                  'Event information not available',
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              
              SizedBox(height: 12),
              
              // Registration details
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Booking ID
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking ID',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          registration.id.length > 8 
                            ? '${registration.id.substring(0, 8)}...' 
                            : registration.id,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Monospace',
                          ),
                        ),
                      ],
                    ),
                    
                    // Tickets
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Tickets',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.confirmation_number, size: 16, color: Colors.red),
                            SizedBox(width: 4),
                            Text(
                              '${registration.ticketQuantity}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    // Total
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _isRegistrationFree(registration)
                            ? 'FREE' 
                            : 'RM${registration.amountPaid.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _isRegistrationFree(registration) ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 12),
              
              // Action buttons based on status
              if (registration.status == 'registered')
                _buildRegisteredActions(registration, event)
              else if (registration.status == 'attended' && event?.isPast == true)
                _buildAttendedActions(registration, event!)
              else if (registration.status == 'cancelled')
                _buildCancelledActions(registration),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisteredActions(Register registration, EventModel? event) {
    final isPaymentPending = registration.paymentStatus == 'pending' && registration.amountPaid > 0;
    
    return Row(
      children: [
        // Cancel button (always available for registered status)
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              _showCancelDialog(registration.id);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel, size: 18),
                SizedBox(width: 8),
                Text('Cancel'),
              ],
            ),
          ),
        ),
        
        SizedBox(width: 12),
        
        // Pay Now or View Ticket button
        Expanded(
          child: ElevatedButton(
            onPressed: isPaymentPending
                ? () => _viewPaymentDetails(registration)
                : event != null ? () => _viewTicket(registration, event) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isPaymentPending ? Colors.red : Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isPaymentPending ? Icons.payment : Icons.qr_code, size: 18),
                SizedBox(width: 8),
                Text(isPaymentPending ? 'Pay Now' : 'View Ticket'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendedActions(Register registration, EventModel event) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // TODO: Navigate to review screen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Review screen will open here')),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(vertical: 10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review, size: 18),
            SizedBox(width: 8),
            Text('Write Review'),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledActions(Register registration) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.red),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cancelled on ${_formatDate(registration.cancelledAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(String registerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Registration'),
        content: Text('Are you sure you want to cancel this registration? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final result = await _registrationService.cancelRegistration(registerId);
                
                if (result['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Registration cancelled successfully'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  _loadMyRegistrations(); // Refresh list
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['error'] ?? 'Failed to cancel registration'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to cancel: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _viewPaymentDetails(Register registration) {
    // TODO: Implement payment details screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment details for ${registration.id}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _viewTicket(Register registration, EventModel event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Event Ticket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.qr_code, size: 100, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              event.name,
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text('by ${event.clubName}', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Text('Booking ID: ${registration.id}', style: TextStyle(fontSize: 12)),
            SizedBox(height: 4),
            Text('Tickets: ${registration.ticketQuantity}', style: TextStyle(fontSize: 12)),
            SizedBox(height: 4),
            Text('Registered: ${_formatDate(registration.registrationDate)}', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement save/share ticket
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ticket saved to device')),
              );
            },
            child: Text('Save Ticket'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRegistrations = _getFilteredRegistrations();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('My Bookings'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              print('Manual refresh triggered');
              _loadMyRegistrations();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.red))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadMyRegistrations,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _myRegistrations.isEmpty
                  ? Column(
                    children: [
                      // Add a header for consistency
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[100]!),
                        ),
                        margin: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.red, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No Bookings Found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'You haven\'t registered for any events yet.',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Main empty state content
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.event_note,
                                    size: 60,
                                    color: Colors.red[200],
                                  ),
                                ),
                                SizedBox(height: 24),
                                Text(
                                  'No Bookings Yet',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 12),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 40),
                                  child: Text(
                                    'Register for events to see them here. Browse exciting events and secure your spot!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                
                                // Browse Events button
                                ElevatedButton.icon(
                                  onPressed: () {
                                    // Navigate to event discovery screen
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EventDiscoveryScreen(),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.explore, size: 20),
                                  label: Text('Browse Events'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                  : RefreshIndicator(
                      onRefresh: _loadMyRegistrations,
                      color: Colors.red,
                      child: ListView(
                        padding: EdgeInsets.all(16),
                        children: [
                          // Header with stats
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red[100]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatItem(
                                  count: _myRegistrations.length,
                                  label: 'Total',
                                  color: Colors.red,
                                ),
                                _buildStatItem(
                                  count: _myRegistrations
                                      .where((r) => r.status == 'registered')
                                      .length,
                                  label: 'Registered',
                                  color: Colors.green,
                                ),
                                _buildStatItem(
                                  count: _myRegistrations
                                      .where((r) => r.status == 'attended')
                                      .length,
                                  label: 'Attended',
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Filter chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('All', isSelected: _currentFilter == 'All'),
                                SizedBox(width: 8),
                                _buildFilterChip('Registered', isSelected: _currentFilter == 'Registered'),
                                SizedBox(width: 8),
                                _buildFilterChip('Payment Pending', isSelected: _currentFilter == 'Payment Pending'),
                                SizedBox(width: 8),
                                _buildFilterChip('Attended', isSelected: _currentFilter == 'Attended'),
                                SizedBox(width: 8),
                                _buildFilterChip('Cancelled', isSelected: _currentFilter == 'Cancelled'),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Results count
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '${filteredRegistrations.length} booking${filteredRegistrations.length != 1 ? 's' : ''} found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 12),
                          
                          // Bookings list
                          ...filteredRegistrations.map((registration) => _buildBookingCard(registration)).toList(),
                          
                          SizedBox(height: 20),
                          
                          // Info footer
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tap on any booking to view event details',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStatItem({required int count, required String label, required Color color}) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFilter = label;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}