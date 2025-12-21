import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import 'user_management.dart';
import 'system_analytics.dart';
import 'content_moderation.dart';
import 'admin_verification_screen.dart'; // Import the approval screen

class AdminHomeScreen extends StatefulWidget {
  @override
  _AdminHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    SystemAnalyticsScreen(),
    UserManagementScreen(),
    ContentModerationScreen(),
    AdminVerificationScreen(), // Add approval screen as the 4th tab
  ];

  // Admin-specific bottom navigation items
  final List<BottomNavigationBarItem> _adminNavItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard),
      label: 'Overview',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.people),
      label: 'Users',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.shield),
      label: 'Moderate',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.approval),
      label: 'Approvals',
      // You can add a badge for pending approvals
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        backgroundColor: Colors.red, // Different color for admin
        actions: [
          // Add a quick access badge for pending approvals
          _buildPendingApprovalsBadge(),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildAdminBottomNav(),
    );
  }

  // Custom admin bottom navigation with 4 items
  Widget _buildAdminBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      items: _adminNavItems,
      selectedItemColor: Colors.red,
      unselectedItemColor: Colors.grey,
    );
  }

  // Badge to show pending approval count
  Widget _buildPendingApprovalsBadge() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'club')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return IconButton(
            icon: Icon(Icons.approval),
            onPressed: () => setState(() => _currentIndex = 3),
          );
        }

        final pendingCount = snapshot.data!.docs.length;
        
        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.approval),
              onPressed: () => setState(() => _currentIndex = 3),
            ),
            if (pendingCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    pendingCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<AppProvider>().logout();
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}