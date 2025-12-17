import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _eventsStream = _firestoreService.getEventsByClub(widget.club.id);
  }

  void _createNewEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventFlow(club: widget.club),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.club.name} Events'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _createNewEvent,
            tooltip: 'Create New Event',
          ),
        ],
      ),
      body: Column(
        children: [
          // Club Header
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: widget.club.imageUrl.isNotEmpty 
                      ? NetworkImage(widget.club.imageUrl)
                      : null,
                  child: widget.club.imageUrl.isEmpty 
                      ? Icon(Icons.group, size: 30)
                      : null,
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
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.club.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Events List
          Expanded(
            child: StreamBuilder<List<EventModel>>(
              stream: _eventsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading events: ${snapshot.error}'),
                  );
                }

                final events = snapshot.data ?? [];

                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No events yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create your first event for ${widget.club.name}',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _createNewEvent,
                          child: Text('Create First Event'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: event.bannerUrl != null
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(event.bannerUrl!),
                              )
                            : CircleAvatar(
                                child: Icon(Icons.event),
                              ),
                        title: Text(event.name),
                        subtitle: Text(
                          '${event.formattedDate} • ${event.location}',
                        ),
                        trailing: Chip(
                          label: Text(
                            event.isFree ? 'Free' : '\$${event.price}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: event.isFree ? Colors.green : Colors.blue,
                        ),
                        onTap: () {
                          // Navigate to event details
                          // You can implement this later
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewEvent,
        child: Icon(Icons.add),
        tooltip: 'Create New Event',
      ),
    );
  }
}