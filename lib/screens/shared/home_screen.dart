import 'package:flutter/material.dart';
import '../../widgets/event_card.dart';
import '../../widgets/bottom_nav.dart';
import '../../services/event_service.dart';
import '../../services/firestore_service.dart';
import '../../models/club.dart';
import '../../models/event.dart';
import "../club/create_event/create_event_flow.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EventService _eventService = EventService();
  List<EventModel> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    // Check if mounted before starting
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      _events = await _eventService.getEvents();
      
      // Check if still mounted before updating state
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      // Check if still mounted before updating state
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Club Events'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEvents,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: EventCard(event: event),
                  );
                },
              ),
            ),
      bottomNavigationBar: BottomNav(selectedIndex: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final firestoreService = FirestoreService();
          final clubs = await firestoreService.getClubs().first;

          if (!mounted) return;

          if (clubs.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You need to be a member of a club to create events'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          if (clubs.length == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateEventFlow(club: clubs.first),
              ),
            );
            return;
          }

          final selectedClub = await showDialog<Club>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Select Club'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: clubs.length,
                    itemBuilder: (context, index) {
                      final club = clubs[index];
                      return ListTile(
                        leading: club.imageUrl.isNotEmpty
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(club.imageUrl),
                              )
                            : CircleAvatar(child: Text(club.name.isNotEmpty ? club.name[0] : '?')),
                        title: Text(club.name),
                        onTap: () => Navigator.pop(context, club),
                      );
                    },
                  ),
                ),
              );
            },
          );

          if (selectedClub != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateEventFlow(club: selectedClub),
              ),
            );
          }
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(Icons.add),
      ),
    
    );
  }
}