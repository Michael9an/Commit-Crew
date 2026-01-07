import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'dart:io';

// --- SCREENS ---
import '../../screens/participant/event_discovery.dart';

// --- MODELS ---
import '../../models/event.dart';
import '../../models/register.dart';

// --- SERVICES ---
import '../../services/registration_service.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart'; // Added for images
import '../../screens/participant/event_detail_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  // --- SERVICES ---
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  // --- STATE VARIABLES ---
  List<Register> _myRegistrations = [];
  List<EventModel> _registeredEvents = [];
  Map<String, EventModel> _eventMap = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _currentFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyRegistrations());
  }

  Future<void> _loadMyRegistrations() async {
    try {
      setState(() { _isLoading = true; _errorMessage = null; });

      final user = await _authService.getCurrentUser();
      if (user == null) {
        if(mounted) setState(() { _isLoading = false; _errorMessage = 'Please sign in to view your bookings'; });
        return;
      }

      final registrations = await _registrationService.getUserRegistrations(userId: user.id, email: user.email);
      
      // Fetch events
      final List<EventModel> events = [];
      final Map<String, EventModel> eventMap = {};

      for (var registration in registrations) {
        final event = await _fetchEventById(registration.eventId);
        if (event != null) {
          events.add(event);
          eventMap[registration.eventId] = event;
        }
      }

      if (mounted) {
        setState(() {
          _myRegistrations = registrations;
          _registeredEvents = events;
          _eventMap = eventMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Failed to load: $e'; });
    }
  }

  Future<EventModel?> _fetchEventById(String eventId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('events').doc(eventId).get();
      if (doc.exists) return EventModel.fromFirestore(doc.data()!, doc.id);
      return null;
    } catch (e) { return null; }
  }

  List<Register> _getFilteredRegistrations() {
    if (_currentFilter == 'All') return _myRegistrations;
    return _myRegistrations.where((r) => r.displayStatus.toLowerCase() == _currentFilter.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredRegistrations = _getFilteredRegistrations();
    
    return Scaffold(
      backgroundColor: Colors.grey[50], // Lighter background
      appBar: AppBar(
        title: const Text('Registered Events', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadMyRegistrations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _myRegistrations.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadMyRegistrations,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildStatsOverview(),
                          const SizedBox(height: 20),
                          _buildFilterSection(),
                          const SizedBox(height: 16),
                          ...filteredRegistrations.map((reg) => _buildModernBookingCard(reg)).toList(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStatsOverview() {
    int total = _myRegistrations.length;
    int upcoming = _myRegistrations.where((r) => r.status == 'registered').length;
    int attended = _myRegistrations.where((r) => r.status == 'attended').length;

    return Row(
      children: [
        _buildStatCard('Total', total.toString(), Colors.blue),
        const SizedBox(width: 12),
        _buildStatCard('Upcoming', upcoming.toString(), Colors.orange),
        const SizedBox(width: 12),
        _buildStatCard('Attended', attended.toString(), Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All'),
          const SizedBox(width: 8),
          _buildFilterChip('Registered'),
          const SizedBox(width: 8),
          _buildFilterChip('Attended'),
          const SizedBox(width: 8),
          _buildFilterChip('Cancelled'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _currentFilter.toLowerCase() == label.toLowerCase();
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) setState(() => _currentFilter = label);
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.black,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildModernBookingCard(Register registration) {
    final event = _eventMap[registration.eventId];
    final statusColor = _getStatusColor(registration.status);
    final statusText = registration.displayStatus.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: event != null ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantEventDetailScreen(event: event!))) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Event Image ---
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: _buildEventImage(event?.bannerUrl),
                  ),
                ),
                const SizedBox(width: 16),
                
                // --- Details ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 6),
                      
                      // Title
                      Text(
                        event?.name ?? 'Loading Event...',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2),
                      ),
                      const SizedBox(height: 4),
                      
                      // Date & Location
                      if (event != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(event.formattedDate, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ]),
                            const SizedBox(height: 2),
                            Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(color: Colors.grey[100], child: const Icon(Icons.event, color: Colors.grey));
    }
    
    // Check if local file
    if (imageUrl.startsWith('/')) {
      return Image.file(File(imageUrl), fit: BoxFit.cover);
    }

    return FutureBuilder<String?>(
      future: _storageService.resolveImageUrl(imageUrl),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Container(color: Colors.grey[100]);
        if (snap.data == null) return Container(color: Colors.grey[100], child: const Icon(Icons.broken_image, size: 20));
        return Image.network(snap.data!, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.error));
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No Bookings Yet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          const Text("Join an event to get started!", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EventDiscoveryScreen())),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: const Text("Explore Events"),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadMyRegistrations, child: const Text("Retry")),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'registered': return Colors.orange;
      case 'attended': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }
}