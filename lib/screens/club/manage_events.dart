import 'package:flutter/material.dart';
import 'club_events_screen.dart'; // Add this import
import '../../../models/club.dart'; // Add this import

class ManageEventsScreen extends StatelessWidget {
  final Club? club; // Add club parameter

  const ManageEventsScreen({super.key, this.club});

  @override
  Widget build(BuildContext context) {
    // If club is provided, use ClubEventsScreen, otherwise show placeholder
    if (club != null) {
      return ClubEventsScreen(club: club!);
    }

    // Fallback UI if no club is provided
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No club data available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Please try refreshing the app',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
