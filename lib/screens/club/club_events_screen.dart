import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/event.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import 'club_event_details_screen.dart';
import 'dart:io';

class ClubEventsScreen extends StatefulWidget {
  final Club club;

  const ClubEventsScreen({super.key, required this.club});

  @override
  _ClubEventsScreenState createState() => _ClubEventsScreenState();
}

class _ClubEventsScreenState extends State<ClubEventsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedFilter = 'All';

  // --- FILTER LOGIC (Unchanged basic filtering) ---
  List<EventModel> _filterEvents(List<EventModel> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return events.where((event) {
      final status = event.status ?? 'draft';
      
      // 1. Archive Logic
      if (_selectedFilter == 'Archived') {
        return status == 'archived';
      }
      if (status == 'archived') {
        return false; // Hide archived events from other tabs
      }

      if (event.date.isEmpty) return false;
      
      DateTime? eventDate;
      try {
        final millis = int.tryParse(event.date);
        if (millis != null) {
          eventDate = DateTime.fromMillisecondsSinceEpoch(millis);
        }
      } catch (e) {
        return false;
      }

      if (eventDate == null) return false;

      switch (_selectedFilter) {
        case '7 Days':
          final end = today.add(const Duration(days: 7));
          return eventDate.isAfter(today.subtract(const Duration(seconds: 1))) && 
                 eventDate.isBefore(end);
        case '15 Days':
          final end = today.add(const Duration(days: 15));
          return eventDate.isAfter(today.subtract(const Duration(seconds: 1))) && 
                 eventDate.isBefore(end);
        case 'Past':
          return eventDate.isBefore(today);
        case 'All':
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // 1. Full-Width Filter Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white, 
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 12),
                  _buildFilterChip('7 Days'),
                  const SizedBox(width: 12),
                  _buildFilterChip('15 Days'),
                  const SizedBox(width: 12),
                  _buildFilterChip('Past'),
                  const SizedBox(width: 12),
                  _buildFilterChip('Archived'),
                ],
              ),
            ),
          ),

          // 2. Event List
          Expanded(
            child: StreamBuilder<List<EventModel>>(
              stream: _firestoreService.getEventsByClub(widget.club.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allEvents = snapshot.data ?? [];
                
                // Get the filtered list based on the selected chip
                final displayEvents = _filterEvents(allEvents);

                if (displayEvents.isEmpty) {
                  return _buildEmptyState();
                }

                // --- NEW LOGIC: GROUP VIEW FOR 'ALL' FILTER ---
                if (_selectedFilter == 'All') {
                  return _buildGroupedList(displayEvents);
                }

                // Standard flat list for other filters
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayEvents.length,
                  itemBuilder: (context, index) {
                    return _buildModernEventCard(displayEvents[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW: Grouped List Builder ---
  Widget _buildGroupedList(List<EventModel> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<EventModel> upcoming = [];
    List<EventModel> past = [];

    for (var event in events) {
      if (event.date.isEmpty) continue;
      final millis = int.tryParse(event.date) ?? 0;
      final date = DateTime.fromMillisecondsSinceEpoch(millis);

      if (date.isBefore(today)) {
        past.add(event);
      } else {
        upcoming.add(event);
      }
    }

    // Sort: Upcoming (Ascending), Past (Descending)
    upcoming.sort((a, b) => (int.tryParse(a.date) ?? 0).compareTo(int.tryParse(b.date) ?? 0));
    past.sort((a, b) => (int.tryParse(b.date) ?? 0).compareTo(int.tryParse(a.date) ?? 0));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (upcoming.isNotEmpty) ...[
          _buildSectionHeader("Upcoming Events", Colors.orange),
          ...upcoming.map((e) => _buildModernEventCard(e)).toList(),
          const SizedBox(height: 24),
        ],

        if (past.isNotEmpty) ...[
          _buildSectionHeader("Past Events", Colors.grey),
          ...past.map((e) => _buildModernEventCard(e)).toList(),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        ],
      ),
    );
  }

  // --- UI WIDGETS ---

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    final isArchivedTab = label == 'Archived'; 
    final selectedColor = isArchivedTab ? Colors.grey[700] : Colors.blue[600];

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) setState(() => _selectedFilter = label);
      },
      selectedColor: selectedColor,
      backgroundColor: Colors.grey[100],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.grey[300]!,
        ),
      ),
    );
  }

  Widget _buildModernEventCard(EventModel event) {
    DateTime? date;
    if (event.date.isNotEmpty) {
      date = DateTime.fromMillisecondsSinceEpoch(int.tryParse(event.date) ?? 0);
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClubEventDetailsScreen(
                event: event,
                club: widget.club,
              ),
            ),
          );
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT: Image or Date
              SizedBox(
                width: 100,
                child: _buildCardImageOrDate(event.bannerUrl, date),
              ),

              // RIGHT: Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              event.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(event.status),
                        ],
                      ),
                      
                      const SizedBox(height: 8),

                      // Middle Row
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),

                      // Bottom Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.people, size: 14, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  '${event.attendees.length}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (!event.isFree)
                            Text(
                              '\$${event.price.toStringAsFixed(0)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardImageOrDate(String? bannerUrl, DateTime? date) {
    if (bannerUrl != null && bannerUrl.isNotEmpty && bannerUrl != 'file:///') {
      return Builder(
        builder: (context) {
          if (bannerUrl.startsWith('http')) {
            return FutureBuilder<String?>(
              future: StorageService().resolveImageUrl(bannerUrl),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.network(
                    snapshot.data!, 
                    fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => _buildDateBox(date),
                  );
                }
                return Container(color: Colors.grey[100]); 
              },
            );
          }
          return _buildDateBox(date); 
        },
      );
    }
    return _buildDateBox(date);
  }

  Widget _buildDateBox(DateTime? date) {
    return Container(
      color: Colors.blue[50],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            date != null ? _getMonth(date) : 'DATE',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue[700]),
          ),
          Text(
            date != null ? '${date.day}' : '?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'published':
        bgColor = Colors.green[50]!;
        textColor = Colors.green[800]!;
        label = 'PUB';
        break;
      case 'archived':
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
        label = 'ARCH';
        break;
      default:
        bgColor = Colors.orange[50]!;
        textColor = Colors.orange[800]!;
        label = 'DRAFT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No events found', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _getMonth(DateTime date) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[date.month - 1];
  }
}