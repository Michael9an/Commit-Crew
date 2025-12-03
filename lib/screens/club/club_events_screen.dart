import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/event.dart';
import '../../services/firestore_service.dart';
import 'create_event/create_event_flow.dart';

class ClubEventsScreen extends StatefulWidget {
  final Club club;

  const ClubEventsScreen({super.key, required this.club});

  @override
  _ClubEventsScreenState createState() => _ClubEventsScreenState();
}

class _ClubEventsScreenState extends State<ClubEventsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Stream<List<EventModel>> _eventsStream;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    try {
      _eventsStream = _firestoreService.getEventsByClub(widget.club.id);
      _hasError = false;
      _errorMessage = null;
      if (mounted) setState(() {});
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      if (mounted) setState(() {});
    }
  }

  void _createNewEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventFlow(club: widget.club),
      ),
    ).then((_) {
      if (mounted) setState(() => _loadEvents());
    });
  }

  // ... [Keep existing _getFormattedDate, _buildEventItem, _buildPlaceholderIcon methods unchanged] ...
  // [I will include the build method where the visible changes are]

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // [AppBar removed or kept based on preference - typically handled by parent scaffold, but safe to keep]
      body: Column(
        children: [
          // Club Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue[50]!, Colors.purple[50]!],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: widget.club.imageUrl.isNotEmpty 
                      ? NetworkImage(widget.club.imageUrl)
                      : null,
                  child: widget.club.imageUrl.isEmpty 
                      ? Icon(Icons.group, size: 30, color: Colors.white)
                      : null,
                  backgroundColor: widget.club.imageUrl.isEmpty ? Colors.blue : null,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.club.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.club.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      // CHANGED: Removed member count, only showing event count
                      Text(
                        '${widget.club.eventIds.length} events created',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Error Banner
          if (_hasError && _errorMessage != null)
             Container(
              padding: EdgeInsets.all(8),
              color: Colors.red[100],
              child: Text("Error loading events: $_errorMessage"),
             ),

          SizedBox(height: 8),

          // Events List
          Expanded(
            child: StreamBuilder<List<EventModel>>(
              stream: _eventsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                final events = snapshot.data ?? [];

                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note, size: 64, color: Colors.grey[300]),
                        SizedBox(height: 16),
                        Text('No Events Yet', style: TextStyle(color: Colors.grey)),
                        TextButton(onPressed: _createNewEvent, child: Text("Create Event"))
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadEvents(),
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      // Reuse your existing _buildEventItem here
                      return _buildEventItem(events[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewEvent,
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }
  
  // Need to include the helpers for the build method to work:
  Widget _buildEventItem(EventModel event) {
    // ... Copy your original _buildEventItem logic here ...
    // Since I cannot inject code into your existing file without retyping it,
    // ensure you keep the _buildEventItem, _getFormattedDate, etc., from your uploaded file.
    
    // Quick simplified placeholder for compilation sake in this answer:
    return Card(
      child: ListTile(
        title: Text(event.name ?? 'Event'),
        subtitle: Text(event.location ?? 'No location'),
        trailing: Chip(label: Text(event.status ?? 'Draft')),
        onTap: () {}, // Add your details dialog logic back
      ),
    );
  }
}