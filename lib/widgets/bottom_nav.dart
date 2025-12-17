import 'package:flutter/material.dart';
import '../screens/shared/home_screen.dart';
import '../screens/events_screen.dart';
import '../screens/shared/clubs_screen.dart';
import '../screens/shared/profile_screen.dart';

class BottomNav extends StatelessWidget {
  final int selectedIndex;

  const BottomNav({super.key, required this.selectedIndex});

  void _navigateToScreen(BuildContext context, int index) {
    if (index == selectedIndex) return;

    switch (index) {
      case 0:
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => HomeScreen(),
            transitionDuration: Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false,
        );
        break;
      case 1:
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => EventsScreen(),
            transitionDuration: Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false,
        );
        break;
      case 2:
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => ClubsScreen(),
            transitionDuration: Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false,
        );
        break;
      case 3:
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => ProfileScreen(),
            transitionDuration: Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: const Color.fromARGB(255, 83, 82, 82),
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
      items: [
        // Home icon with animation - FIXED
        BottomNavigationBarItem(
          icon: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            transform: selectedIndex == 0 
                ? Matrix4.identity().scaled(1.0)  // Use .scaled() instead of ..scale()
                : Matrix4.identity().scaled(0.8),
            child: Icon(Icons.home),
          ),
          activeIcon: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            transform: Matrix4.identity().scaled(1.2), // Use .scaled()
            child: Icon(Icons.home_filled),
          ),
          label: 'Home',
        ),

        // Events icon with animation - FIXED
        BottomNavigationBarItem(
          icon: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            transform: selectedIndex == 1 
                ? Matrix4.identity().scaled(1.0)
                : Matrix4.identity().scaled(0.8),
            child: Icon(Icons.event),
          ),
          activeIcon: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            transform: Matrix4.identity().scaled(1.2),
            child: Icon(Icons.event_available),
          ),
          label: 'Events',
        ),

        // Clubs icon with animation - FIXED
        BottomNavigationBarItem(
          icon: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            transform: selectedIndex == 2 
                ? Matrix4.identity().scaled(1.0)
                : Matrix4.identity().scaled(0.8),
            child: Icon(Icons.people),
          ),
          activeIcon: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            transform: Matrix4.identity().scaled(1.2),
            child: Icon(Icons.people_alt),
          ),
          label: 'Clubs',
        ),

        // Profile icon with animation - FIXED
        BottomNavigationBarItem(
          icon: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            transform: selectedIndex == 3 
                ? Matrix4.identity().scaled(1.0)
                : Matrix4.identity().scaled(0.8),
            child: Icon(Icons.person),
          ),
          activeIcon: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            transform: Matrix4.identity().scaled(1.2),
            child: Icon(Icons.person_2),
          ),
          label: 'Profile',
        ),
      ],
      onTap: (index) => _navigateToScreen(context, index),
    );
  }
}