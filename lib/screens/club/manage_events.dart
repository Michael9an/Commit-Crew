import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'club_events_screen.dart'; 
import '../../../models/club.dart';
import '../../../providers/app_provider.dart'; // Import AppProvider

class ManageEventsScreen extends StatelessWidget {
  final Club? club;

  const ManageEventsScreen({super.key, this.club});

  @override
  Widget build(BuildContext context) {
    // 1. If we have club data, show the normal screen
    if (club != null) {
      return ClubEventsScreen(club: club!);
    }

    // 2. Fallback UI (Now with AppBar!)
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Events'),
        // You can choose to hide the "Add" button here if no club exists
        // or show it but make it show a snackbar saying "Wait for loading"
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No club data available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Please check your internet or verification status.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            // Retry Button
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Retry Loading'),
              onPressed: () {
                // Trigger a reload via Provider
                context.read<AppProvider>().refreshUser();
              },
            ),
          ],
        ),
      ),
    );
  }
}