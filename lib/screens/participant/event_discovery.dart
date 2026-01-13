import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import '../../services/storage_service.dart';
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
  
  // --- STATE MANAGEMENT ---
  List<EventModel> _events = [];
  bool _isLoading = true; // Only true on FIRST load
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
    _loadEvents(isInitialLoad: true);

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

  // --- DATA LOADING LOGIC (NO FLASHING) ---
  Future<void> _loadEvents({bool isInitialLoad = false}) async {
    if (isInitialLoad) {
      setState(() => _isLoading = true);
    }

    try {
      // Fetch 1 snapshot of data (No StreamBuilder = No Flashing)
      final newEvents = await _firestoreService.getEvents().first;
      
      if (mounted) {
        setState(() {
          _events = newEvents;
          _isLoading = false; 
        });
      }
    } catch (e) {
      print("Error loading events: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REFRESH HANDLER ---
  Future<void> _handleRefresh() async {
    // 1. Force the spinner to be visible for a moment (Premium Feel)
    final minWait = Future.delayed(const Duration(milliseconds: 1000));
    // 2. Load data in background (Old list stays visible)
    final dataFuture = _loadEvents(isInitialLoad: false);
    // 3. Wait for both
    await Future.wait([minWait, dataFuture]);
  }

  // --- FILTER LOGIC ---
  List<EventModel> _getFilteredEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); 

    // 1. BASE FILTER: Only show 'published' events. 
    // This removes 'archived', 'draft', or 'cancelled' events from the list immediately.
    final visibleEvents = _events.where((e) => e.status == 'published').toList();

    List<EventModel> tabEvents;
    
    if (_tabController.index == 0) { // Upcoming
      tabEvents = visibleEvents.where((e) { // Changed _events to visibleEvents
         if (e.date.isEmpty) return false;
         try {
           final eDate = DateTime.fromMillisecondsSinceEpoch(int.parse(e.date));
           return !eDate.isBefore(today); 
         } catch (e) { return false; }
      }).toList();
      tabEvents.sort((a, b) => (int.tryParse(a.date) ?? 0).compareTo(int.tryParse(b.date) ?? 0));
    } else { // Past
      tabEvents = visibleEvents.where((e) { // Changed _events to visibleEvents
         if (e.date.isEmpty) return false;
         try {
           final eDate = DateTime.fromMillisecondsSinceEpoch(int.parse(e.date));
           return eDate.isBefore(today);
         } catch (e) { return false; }
      }).toList();
      tabEvents.sort((a, b) => (int.tryParse(b.date) ?? 0).compareTo(int.tryParse(a.date) ?? 0));
    }

    return tabEvents.where((e) {
      if (_selectedCategory != 'All' && e.category != _selectedCategory) {
        return false;
      }
      if (_tabController.index == 0 && _selectedTimeFilter != 'All') {
        try {
          final eDate = DateTime.fromMillisecondsSinceEpoch(int.parse(e.date));
          final diff = eDate.difference(now).inDays;

          if (_selectedTimeFilter == 'Next 7 Days' && diff > 7) return false;
          if (_selectedTimeFilter == 'Next 15 Days' && diff > 15) return false;
        } catch (e) { return false; }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayEvents = _getFilteredEvents();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      // Standard AppBar (No Sliver/NestedScrollView issues)
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

      // --- REFRESH INDICATOR ---
      // Wraps the simple ListView. This is the most stable configuration.
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Colors.blue,
            backgroundColor: Colors.white,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(), // Ensures bounce works
              // Add 2 to count: Index 0 is FilterBar, Last index is Bottom Spacer
              itemCount: displayEvents.length + 2, 
              itemBuilder: (context, index) {
                
                // --- 1. FILTER BAR (Index 0) ---
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

                // --- 2. BOTTOM SPACER (Last Index) ---
                if (index == displayEvents.length + 1) {
                  return const SizedBox(height: 80); 
                }

                // --- 3. EVENT CARDS ---
                if (displayEvents.isEmpty) {
                   // Fallback if list is empty but we are in the builder loop
                   return _buildEmptyState();
                }

                return _buildEventCard(displayEvents[index - 1], context);
              },
            ),
          ),
    );
  }

  // --- WIDGET HELPERS ---
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _tabController.index == 0 
                  ? "No upcoming events found" 
                  : "No past events found",
              style: TextStyle(color: Colors.grey[600])
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
     bool isEnded = false;
    if (event.date != null) {
      try {
        final d = DateTime.fromMillisecondsSinceEpoch(int.parse(event.date!));
        if (d.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) {
          isEnded = true;
        }
      } catch (e) {}
    }

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
          );
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