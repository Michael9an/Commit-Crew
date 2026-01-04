import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import '../../services/storage_service.dart';
import '../../models/event.dart';
import '../../services/firestore_service.dart';
import 'event_detail_screen.dart';
import 'qr_scanner_page.dart';

// 1. CHANGE TO STATEFUL WIDGET
class EventDiscoveryScreen extends StatefulWidget {
  const EventDiscoveryScreen({super.key});

  @override
  State<EventDiscoveryScreen> createState() => _EventDiscoveryScreenState();
}

// 2. ADD THE MIXIN (SingleTickerProviderStateMixin)
class _EventDiscoveryScreenState extends State<EventDiscoveryScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isFabExtended = true;

  // --- FILTER STATE ---
  late TabController _tabController; // Now this will work because we are in a State class
  String _selectedCategory = 'All';
  String _selectedTimeFilter = 'All'; 

  final List<String> _categories = [
    'All', 'Technology', 'Sports', 'Music', 'Arts', 
    'Business', 'Education', 'Social', 'Workshop', 'Gaming', 'Health'
  ];

  @override
  void initState() {
    super.initState();
    // 3. INITIALIZE TAB CONTROLLER
    // 'vsync: this' works because of the Mixin above
    _tabController = TabController(length: 2, vsync: this);
    
    // Listen to scroll changes to toggle FAB state
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
    _tabController.dispose(); // Don't forget to dispose
    super.dispose();
  }

  // --- FILTER LOGIC ---
  List<EventModel> _processEvents(List<EventModel> allEvents) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); 

    // 1. Separate by Tab (Upcoming vs Past)
    List<EventModel> tabEvents;
    
    // Check tab index. Note: We use _tabController.index in build, but setState updates UI
    if (_tabController.index == 0) {
      // Upcoming Tab: Events today or in future
      tabEvents = allEvents.where((e) {
         if (e.date == null) return false;
         // Parse date safely
         try {
           final eDate = DateTime.fromMillisecondsSinceEpoch(int.parse(e.date!));
           return !eDate.isBefore(today); 
         } catch (e) { return false; }
      }).toList();
      
      // Sort: Nearest date first
      tabEvents.sort((a, b) {
        final d1 = int.tryParse(a.date ?? '0') ?? 0;
        final d2 = int.tryParse(b.date ?? '0') ?? 0;
        return d1.compareTo(d2);
      });
    } else {
      // Past Tab: Events strictly before today
      tabEvents = allEvents.where((e) {
         if (e.date == null) return false;
         try {
           final eDate = DateTime.fromMillisecondsSinceEpoch(int.parse(e.date!));
           return eDate.isBefore(today);
         } catch (e) { return false; }
      }).toList();

      // Sort: Most recent past event first
      tabEvents.sort((a, b) {
        final d1 = int.tryParse(a.date ?? '0') ?? 0;
        final d2 = int.tryParse(b.date ?? '0') ?? 0;
        return d2.compareTo(d1);
      });
    }

    // 2. Apply Category & Time Filters
    return tabEvents.where((e) {
      // Category Filter
      if (_selectedCategory != 'All' && e.category != _selectedCategory) {
        return false;
      }

      // Time Filter (Only applies to Upcoming tab mostly)
      if (_tabController.index == 0 && _selectedTimeFilter != 'All') {
        try {
          final eDate = DateTime.fromMillisecondsSinceEpoch(int.parse(e.date!));
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
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

      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: const Text('Discover Events'),
              floating: true,
              pinned: true,
              snap: true,
              bottom: TabBar(
                controller: _tabController,
                onTap: (index) => setState(() {}), // Refresh UI on tab change
                indicatorColor: Colors.blue,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: "Upcoming"),
                  Tab(text: "Past Events"),
                ],
              ),
            ),
          ];
        },
        body: Column(
          children: [
            // Filter Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
            ),

            // Event List
            Expanded(
              child: StreamBuilder<List<EventModel>>(
                stream: _firestoreService.getEvents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final allEvents = snapshot.data ?? [];
                  final displayEvents = _processEvents(allEvents);

                  if (displayEvents.isEmpty) {
                    return Center(
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
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: displayEvents.length + 1,
                    itemBuilder: (context, index) {
                      if (index == displayEvents.length) {
                        return const SizedBox(height: 80); 
                      }
                      return _buildEventCard(displayEvents[index], context);
                    },
                  );
                },
              ),
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
    // Check if ended
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
             // Image Section
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