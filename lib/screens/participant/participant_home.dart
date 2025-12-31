import 'package:event_app/screens/participant/profile_screen.dart';
import 'package:flutter/material.dart';
import '../../widgets/role_based_bottom_nav.dart';
import 'event_discovery.dart';
import 'my_bookings.dart';
import 'qr_scanner_page.dart'; // <--- 1. IMPORT ADDED

class ParticipantHomeScreen extends StatefulWidget {
  const ParticipantHomeScreen({super.key});

  @override
  _ParticipantHomeScreenState createState() => _ParticipantHomeScreenState();
}

class _ParticipantHomeScreenState extends State<ParticipantHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const EventDiscoveryScreen(),
    MyBookingsScreen(),
    const ProfileScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],

      bottomNavigationBar: RoleBasedBottomNav(
        selectedIndex: _currentIndex,
        onItemTapped: (index) => setState(() => _currentIndex = index),
        userRole: 'participant',
      ),
    );
  }
}