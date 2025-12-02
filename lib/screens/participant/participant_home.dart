import 'package:event_app/screens/participant/profile_screen.dart';
import 'package:flutter/material.dart';
import '../../widgets/role_based_bottom_nav.dart';
import 'event_discovery.dart';
import 'my_bookings.dart';

class ParticipantHomeScreen extends StatefulWidget {
  @override
  _ParticipantHomeScreenState createState() => _ParticipantHomeScreenState();
}

class _ParticipantHomeScreenState extends State<ParticipantHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    EventDiscoveryScreen(),
    MyBookingsScreen(),
    ProfileScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Event Discovery'),
        actions: [
          IconButton(icon: Icon(Icons.search), onPressed: () {}),
          IconButton(icon: Icon(Icons.notifications), onPressed: () {}),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: RoleBasedBottomNav(
        selectedIndex: _currentIndex,
        onItemTapped: (index) => setState(() => _currentIndex = index),
        userRole: 'participant',
      ),
    );
  }
}