import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Needed for ScrollDirection
import 'dart:io';
import '../../services/storage_service.dart';
import '../../models/event.dart';
import '../../services/firestore_service.dart';
import 'event_detail_screen.dart';
import 'qr_scanner_page.dart'; // Import scanner here

class EventDiscoveryScreen extends StatefulWidget {
  const EventDiscoveryScreen({super.key});

  @override
  State<EventDiscoveryScreen> createState() => _EventDiscoveryScreenState();
}

class _EventDiscoveryScreenState extends State<EventDiscoveryScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isFabExtended = true;

  @override
  void initState() {
    super.initState();
    // Listen to scroll changes to toggle FAB state
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        // User is scrolling down -> Minimize FAB
        if (_isFabExtended) {
          setState(() => _isFabExtended = false);
        }
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        // User is scrolling up -> Extend FAB
        if (!_isFabExtended) {
          setState(() => _isFabExtended = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    
    return Scaffold(
      // 1. Dynamic Floating Action Button
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
      // Positioned at the bottom right (standard for this behavior)
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: StreamBuilder<List<EventModel>>(
        stream: firestoreService.getEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No Events Found'));
          }

          final events = snapshot.data!;

          return ListView(
            // 2. Attach the ScrollController here
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Discover Events', 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 16),
              ...events.map((event) => _buildEventCard(event, context)).toList(),
              // Add extra padding at bottom so FAB doesn't cover the last item
              const SizedBox(height: 80), 
            ],
          );
        },
      ),
    );
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerPage()),
    );
  }

  Widget _buildEventCard(EventModel event, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParticipantEventDetailScreen(event: event),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildEventImage(event.bannerUrl),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                event.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              // ... existing row details ...
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    event.formattedDate,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    event.formattedTime,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
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
                      border: Border.all(
                        color: event.isFree ? Colors.green : Colors.blue,
                      ),
                    ),
                    child: Text(
                      event.isFree ? 'FREE' : '\$${event.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: event.isFree ? Colors.green : Colors.blue,
                      ),
                    ),
                  ),
                  Text(
                    'by ${event.clubName}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Keep _buildEventImage and _buildErrorImage exactly as they were) ...
  
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
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
      );
    }
    final storageService = StorageService();
    return FutureBuilder<String?>(
      future: storageService.resolveImageUrl(imageUrl),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator()));
        }
        final resolved = snap.data;
        if (resolved == null || resolved.isEmpty) return _buildErrorImage();
        
        if (resolved.startsWith('/')) {
           return Image.file(File(resolved), fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildErrorImage());
        }

        return Image.network(
          resolved,
          fit: BoxFit.cover,
          errorBuilder: (_,__,___) => _buildErrorImage(),
        );
      },
    );
  }

  Widget _buildErrorImage() {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.broken_image, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text('Image not available', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}