import 'package:flutter/material.dart';

class RoleBasedBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final String userRole;

  const RoleBasedBottomNav({
    required this.selectedIndex,
    required this.onItemTapped,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    // Different navigation items based on role
    switch (userRole) {
      case 'admin':
        return _buildAdminNav();
      case 'club':
        return _buildClubNav();
      case 'participant':
      default:
        return _buildParticipantNav();
    }
  }

  BottomNavigationBar _buildParticipantNav() {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onItemTapped,
      type: BottomNavigationBarType.fixed, // Ensure label visibility with > 3 items
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Discover'),
        BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Bookings'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Analytics'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  BottomNavigationBar _buildClubNav() {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onItemTapped,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.event), label: 'My Events'),
        BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Profile'),
      ],
    );
  }

  BottomNavigationBar _buildAdminNav() {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onItemTapped,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Analytics'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
        BottomNavigationBarItem(icon: Icon(Icons.shield), label: 'Moderate'),
      ],
    );
  }
}