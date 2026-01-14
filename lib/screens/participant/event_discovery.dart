import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'dart:io';
import '../../services/storage_service.dart';
import '../../services/registration_service.dart'; 
import '../../models/event.dart';
import '../../services/firestore_service.dart';
import 'event_detail_screen.dart';
import 'qr_scanner_page.dart';

class EventDiscoveryScreen extends StatefulWidget {
  const EventDiscoveryScreen({super.key});

  @override
  State<EventDiscoveryScreen> createState() => _EventDiscoveryScreenState();
}

class _EventDiscoveryScreenState extends State<EventDiscoveryScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();
  final RegistrationService _registrationService = RegistrationService(); 
  
  // --- STATE MANAGEMENT ---
  List<EventModel> _events = [];
  Set<String> _registeredEventIds = {}; 
  bool _isLoading = true; 
  bool _isFabExtended = true;

  // --- FILTER STATE ---
  late TabController _tabController;
  String _selectedCategory = 'All';
  String _selectedTimeFilter = 'All'; 

  final List<String> _categories = [
    'All', 'Technology', 'Sports', 'Music', 'Arts', 
    'Business', 'Education', 'Social', 'Workshop', 'Gaming', 'Health'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initial Load
    _loadData(isInitialLoad: true);

    // FAB scroll listener
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_isFabExtended) setState(() => _isFabExtended = false);
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_isFabExtended) setState(() => _isFabExtended = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose(); 
    super.dispose();
  }

  // --- DATA LOADING LOGIC (Events + Registrations) ---
  Future<void> _loadData({bool isInitialLoad = false}) async {
    if (isInitialLoad) {
      setState(() => _isLoading = true);
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      // 1. Fetch Events
      final eventsFuture = _firestoreService.getEvents().first;
      
      // 2. Fetch User's Registrations (if logged in)
      Future<List<String>> registrationsFuture;
      if (user != null) {
        registrationsFuture = _registrationService
            .getUserRegistrations(userId: user.uid)
            .then((list) => list.map((r) => r.eventId).toList());
      } else {
        registrationsFuture = Future.value([]);
      }

      // Wait for both to complete
      final results = await Future.wait([eventsFuture, registrationsFuture]);
      
      final newEvents = results[0] as List<EventModel>;
      final myEventIds = results[1] as List<String>;

      if (mounted) {
        setState(() {
          _events = newEvents;
          _registeredEventIds = myEventIds.toSet(); // Cache registered IDs
          _isLoading = false; 
        });
      }
    } catch (e) {
      print("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REFRESH HANDLER ---
  Future<void> _handleRefresh() async {
    final minWait = Future.delayed(const Duration(milliseconds: 1000));
    final dataFuture = _loadData(isInitialLoad: false);
    await Future.wait([minWait, dataFuture]);
  }

  // --- FILTER LOGIC ---
  List<EventModel> _getFilteredEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Base Filter: Published ONLY AND Exclude registered events
    final visibleEvents = _events.where((e) {
      if (e.status != 'published') return false;
      if (_registeredEventIds.contains(e.id)) return false; // <--- HIDE REGISTERED EVENTS
      return true;
    }).toList();

    List<EventModel> tabEvents;

    if (_tabController.index == 0) { 
      // --- UPCOMING TAB ---
      tabEvents = visibleEvents.where((e) {
        if (e.date.isEmpty) return false;
        
        final dateBase = DateTime.fromMillisecondsSinceEpoch(int.parse(e.date));
        final eventDate = DateTime(dateBase.year, dateBase.month, dateBase.day);

        if (eventDate.isBefore(today)) return false; 
        if (eventDate.isAfter(today)) return true;   

        final endDateTime = _getEventEndTime(e);
        return endDateTime.isAfter(now); 
      }).toList();
      
      tabEvents.sort((a, b) => _getEventEndTime(a).compareTo(_getEventEndTime(b)));

    } else { 
      // --- PAST TAB ---
      tabEvents = visibleEvents.where((e) {
        if (e.date.isEmpty) return true;
        
        final dateBase = DateTime.fromMillisecondsSinceEpoch(int.parse(e.date));
        final eventDate = DateTime(dateBase.year, dateBase.month, dateBase.day);

        if (eventDate.isBefore(today)) return true; 
        if (eventDate.isAfter(today)) return false;  

        final endDateTime = _getEventEndTime(e);
        return endDateTime.isBefore(now);
      }).toList();

      tabEvents.sort((a, b) => _getEventEndTime(b).compareTo(_getEventEndTime(a)));
    }

    // Apply Category & Time Filters
    return tabEvents.where((e) {
      if (_selectedCategory != 'All' && e.category != _selectedCategory) return false;
      
      if (_tabController.index == 0 && _selectedTimeFilter != 'All') {
        final endDateTime = _getEventEndTime(e);
        final diff = endDateTime.difference(now).inDays;
        
        if (_selectedTimeFilter == 'Next 7 Days' && diff > 7) return false;
        if (_selectedTimeFilter == 'Next 15 Days' && diff > 15) return false;
      }
      return true;
    }).toList();
  }

  // --- HELPER: Get Exact End Time ---
  DateTime _getEventEndTime(EventModel event) {
    if (event.date.isEmpty) return DateTime.now();

    DateTime dateBase = DateTime.fromMillisecondsSinceEpoch(int.parse(event.date));
    String timeStr = event.endTime.isNotEmpty ? event.endTime : event.startTime;
    TimeOfDay time = _parseTimeString(timeStr);

    return DateTime(dateBase.year, dateBase.month, dateBase.day, time.hour, time.minute);
  }

  // --- HELPER: Robust Time Parser ---
  TimeOfDay _parseTimeString(String timeStr) {
    const defaultTime = TimeOfDay(hour: 0, minute: 0); 

    if (timeStr.isEmpty || timeStr == 'Time not set') return defaultTime;

    try {
      String cleanStr = timeStr.toLowerCase().trim()
          .replaceAll(' ', '')
          .replaceAll('.', ':'); 

      if (cleanStr.contains('-')) cleanStr = cleanStr.split('-').last;

      if (cleanStr.contains('am') || cleanStr.contains('pm')) {
        bool isPm = cleanStr.contains('pm');
        cleanStr = cleanStr.replaceAll('am', '').replaceAll('pm', '');
        
        int hour = 0;
        int minute = 0;
        if (cleanStr.contains(':')) {
          final parts = cleanStr.split(':');
          hour = int.parse(parts[0]);
          minute = parts.length > 1 ? int.parse(parts[1]) : 0;
        } else {
          hour = int.parse(cleanStr);
        }
        if (isPm && hour < 12) hour += 12; 
        if (!isPm && hour == 12) hour = 0; 
        return TimeOfDay(hour: hour, minute: minute);
      } 
      else if (cleanStr.contains(':')) {
        final parts = cleanStr.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      return defaultTime;
    } catch (e) {
      return defaultTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayEvents = _getFilteredEvents();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Discover Events'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => setState(() {}),
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Upcoming"),
            Tab(text: "Past Events"),
          ],
        ),
      ),
      
      floatingActionButton: _isFabExtended
          ? FloatingActionButton.extended(
              onPressed: _openScanner,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Scan Attendance"),
              backgroundColor: Colors.blue,
            )
          : FloatingActionButton(
              onPressed: _openScanner,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.qr_code_scanner),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Colors.blue,
            backgroundColor: Colors.white,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              // FIXED: Ensure itemCount is at least 2 to show Filter + EmptyState
              itemCount: displayEvents.isEmpty ? 2 : displayEvents.length + 2, 
              itemBuilder: (context, index) {
                
                // 1. FILTER BAR (Index 0)
                if (index == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (_tabController.index == 0) ...[
                            _buildFilterChip('All', _selectedTimeFilter == 'All', () => setState(() => _selectedTimeFilter = 'All')),
                            const SizedBox(width: 8),
                            _buildFilterChip('Next 7 Days', _selectedTimeFilter == 'Next 7 Days', () => setState(() => _selectedTimeFilter = 'Next 7 Days')),
                            const SizedBox(width: 8),
                            _buildFilterChip('Next 15 Days', _selectedTimeFilter == 'Next 15 Days', () => setState(() => _selectedTimeFilter = 'Next 15 Days')),
                            const VerticalDivider(width: 24, thickness: 1, color: Colors.grey),
                          ],
                          ..._categories.map((cat) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildFilterChip(
                                cat, 
                                _selectedCategory == cat, 
                                () => setState(() => _selectedCategory = cat),
                                isCategory: true
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  );
                }

                // 2. EMPTY STATE (Index 1 when empty)
                if (displayEvents.isEmpty) {
                   return _buildEmptyState();
                }

                // 3. BOTTOM SPACER (Last Index)
                if (index == displayEvents.length + 1) {
                  return const SizedBox(height: 80); 
                }

                // 4. EVENT CARDS
                return _buildEventCard(displayEvents[index - 1], context);
              },
            ),
          ),
    );
  }

  // --- UPDATED WIDGET HELPERS ---
  
  Widget _buildEmptyState() {
    String message = "No events found";
    IconData icon = Icons.event_busy;

    if (_tabController.index == 0) {
      // Check if we have events that are hidden because of registration
      bool hiddenDueToRegistration = _events.any((e) {
        if (e.status != 'published') return false; 
        if (_selectedCategory != 'All' && e.category != _selectedCategory) return false;
        
        // Is it upcoming?
        final end = _getEventEndTime(e);
        if (!end.isAfter(DateTime.now())) return false; 

        // Is it registered?
        return _registeredEventIds.contains(e.id);
      });

      if (hiddenDueToRegistration) {
        message = "There are no upcoming events\n(You've registered for all available events!)";
        icon = Icons.done_all;
      } else {
        message = "There are no upcoming events";
      }
    } else {
      message = "No past events found";
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, {bool isCategory = false}) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.white,
      selectedColor: isCategory ? Colors.purple[50] : Colors.blue[50],
      labelStyle: TextStyle(
        color: isSelected 
            ? (isCategory ? Colors.purple : Colors.blue) 
            : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected 
              ? (isCategory ? Colors.purple : Colors.blue) 
              : Colors.grey[300]!,
        ),
      ),
      showCheckmark: false,
    );
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerPage()),
    );
  }

  Widget _buildEventCard(EventModel event, BuildContext context) {
    final isEnded = DateTime.now().isAfter(_getEventEndTime(event));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParticipantEventDetailScreen(event: event),
            ),
          ).then((_) => _loadData()); // Refresh upon return
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                 AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildEventImage(event.bannerUrl),
                ),
                if (isEnded)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text("ENDED", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(event.formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(event.formattedTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: event.isFree ? Colors.green[50] : Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: event.isFree ? Colors.green : Colors.blue),
                        ),
                        child: Text(
                          event.isFree ? 'FREE' : '\$${event.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold,
                            color: event.isFree ? Colors.green : Colors.blue,
                          ),
                        ),
                      ),
                      Text('by ${event.clubName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.event, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('No image', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    if (imageUrl.startsWith('/')) {
      return Image.file(File(imageUrl), fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildErrorImage());
    }
    final storageService = StorageService();
    return FutureBuilder<String?>(
      future: storageService.resolveImageUrl(imageUrl),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(color: Colors.grey[200]);
        }
        final resolved = snap.data;
        if (resolved == null || resolved.isEmpty) return _buildErrorImage();
        
        if (resolved.startsWith('/')) {
           return Image.file(File(resolved), fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildErrorImage());
        }

        return Image.network(resolved, fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildErrorImage());
      },
    );
  }

  Widget _buildErrorImage() {
    return Container(
      color: Colors.grey[200],
      child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
    );
  }
}