import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/storage_service.dart';
import '../widgets/bottom_nav.dart';
import '../models/event.dart';
import '../models/club.dart';
import '../services/firestore_service.dart';
import 'club/create_event/create_event_flow.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Events'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () async {
              final firestoreService = FirestoreService();
              final clubs = await firestoreService.getClubs().first;
              
              if (!context.mounted) return;

              if (clubs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('You need to be a member of a club to create events'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // If there's only one club, use it directly
              if (clubs.length == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateEventFlow(club: clubs.first),
                  ),
                );
                return;
              }

              // If there are multiple clubs, show a dialog to choose
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
                              : CircleAvatar(
                                  child: Text(club.name[0]),
                                ),
                            title: Text(club.name),
                            onTap: () {
                              Navigator.pop(context, club);
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              );

              if (selectedClub != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateEventFlow(club: selectedClub),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<EventModel>>(
        stream: firestoreService.getEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error loading events'),
                  SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No Events Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create your first event to get started!',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final firestoreService = FirestoreService();
                      final clubs = await firestoreService.getClubs().first;
                      
                      if (!context.mounted) return;

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
                                      : CircleAvatar(
                                          child: Text(club.name[0]),
                                        ),
                                    title: Text(club.name),
                                    onTap: () {
                                      Navigator.pop(context, club);
                                    },
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      );

                      if (selectedClub != null && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateEventFlow(club: selectedClub),
                          ),
                        );
                      }
                    },
                    child: Text('Create Event'),
                  ),
                ],
              ),
            );
          }

          final events = snapshot.data!;

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _buildEventCard(event, context);
            },
          );
        },
      ),
      bottomNavigationBar: BottomNav(selectedIndex: 1),
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
            Text(
              'No image',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // If the URL is a local file path (temporary during upload)
    if (imageUrl.startsWith('/')) {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading local image: $error');
          return _buildErrorImage();
        },
      );
    }

    // For network or storage images, attempt to resolve them first (may be a
    // gs:// URL or a storage path saved in Firestore). Use StorageService to
    // convert to a usable https URL if needed.
    final storageService = StorageService();
    return FutureBuilder<String?>(
      future: storageService.resolveImageUrl(imageUrl),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[200],
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final resolved = snap.data;
        if (resolved == null || resolved.isEmpty) {
          return _buildErrorImage();
        }

        // If the resolver returned a local path, show it as a file.
        if (resolved.startsWith('/')) {
          return Image.file(
            File(resolved),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading resolved local image: $error');
              return _buildErrorImage();
            },
          );
        }

        return Image.network(
          resolved,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading network image: $error');
            return _buildErrorImage();
          },
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
          Text(
            'Image not available',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(EventModel event, BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to event details
        },
        child: Padding(
          padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildEventImage(event.bannerUrl),
              ),
            ),
            
            SizedBox(height: 12),
            
            // Event Name
            Text(
              event.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 8),
            
            // Event Description
            Text(
              event.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            ),
            
            SizedBox(height: 12),
            
            // Event Details Row
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  event.formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  event.formattedTime,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Location
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Price and Club Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}