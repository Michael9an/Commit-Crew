import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/role_based_bottom_nav.dart';
import 'club_events_screen.dart'; // Add this import
import 'event_analytics.dart';
import 'club_members.dart';
import 'create_event/create_event_flow.dart';
import '../../../models/club.dart';
import '../../../services/firestore_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';

class ClubHomeScreen extends StatefulWidget {
  @override
  _ClubHomeScreenState createState() => _ClubHomeScreenState();
}

class _ClubHomeScreenState extends State<ClubHomeScreen> {
  int _currentIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();
  Club? _currentClub;
  bool _isLoading = true;

  // Update screens to pass club data
  final List<Widget> _screens = [
    // These will be updated when club data is loaded
    Center(child: CircularProgressIndicator()),
    Center(child: CircularProgressIndicator()),
    Center(child: CircularProgressIndicator()),
  ];

  @override
  void initState() {
    super.initState();
    _debugUserData(); // Add this
    _loadClubData();
  }

  // Load club data for the current user
  Future<void> _loadClubData() async {
    try {
      final club = await _getCurrentUserClub();
      setState(() {
        _currentClub = club;
        _isLoading = false;
        // Update screens with club data
        _updateScreens();
      });
    } catch (e) {
      print('Error loading club data: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading club data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        });
      }
    }
  }

  void _updateScreens() {
    if (_currentClub != null) {
      setState(() {
        _screens
          ..[0] = ClubEventsScreen(club: _currentClub!)
          ..[1] = EventAnalyticsScreen(club: _currentClub!)
          ..[2] = ClubMembersScreen(club: _currentClub!);
      });
    }
  }

  Future<Club> _getCurrentUserClub() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final currentUser = appProvider.currentUser;

    if (currentUser == null) {
      throw Exception('No user logged in');
    }

    // For club users, they should have at least one club ID
    if (currentUser.clubIds.isEmpty) {
      throw Exception('User is not associated with any club');
    }

    final clubId = currentUser.clubIds.first;

    try {
      final clubDoc = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .get();

      if (clubDoc.exists) {
        final data = clubDoc.data()!;
        return Club(
          id: clubDoc.id,
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          createdBy: data['createdBy'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          memberIds: List<String>.from(data['memberIds'] ?? []),
          adminIds: List<String>.from(data['adminIds'] ?? []),
          eventIds: List<String>.from(data['eventIds'] ?? []),
          createdAt: data['createdAt']?.toDate(),
          updatedAt: data['updatedAt']?.toDate(),
          isActive: data['isActive'] ?? true,
          status: data['status'] ?? 'pending',
          contactEmail: data['contactEmail'],
          contactPhone: data['contactPhone'],
          website: data['website'],
          location: data['location'],
          categories: List<String>.from(data['categories'] ?? []),
          approvalLetterUrl: data['approvalLetterUrl'],
        );
      } else {
        throw Exception('Club not found');
      }
    } catch (e) {
      print('Error fetching club: $e');
      throw Exception('Failed to load club information');
    }
  }

  // Add logout functionality
  Future<void> _logout() async {
    final shouldLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await context.read<AppProvider>().logout();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? 'Loading...' : 'Club Dashboard'),
        actions: [
          // Create Event Button
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _currentClub != null ? _createNewEvent : null,
            tooltip: 'Create New Event',
          ),
          // Logout Button
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : _screens[_currentIndex],
      bottomNavigationBar: _isLoading 
          ? null 
          : RoleBasedBottomNav(
              selectedIndex: _currentIndex,
              onItemTapped: (index) => setState(() => _currentIndex = index),
              userRole: 'club',
            ),
    );
  }

  void _createNewEvent() {
    if (_currentClub == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load club information. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if club is approved before allowing event creation
    if (!_currentClub!.canCreateEvents) {
      String message = '';
      if (!_currentClub!.isApproved) {
        message =
            'Your club account is pending admin approval. You cannot create events until approved.';
      } else if (!_currentClub!.isActive) {
        message = 'Your club account is inactive. Please contact support.';
      } else {
        message = 'You do not have permission to create events for this club.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check if current user can create events for this club
    final currentUserId = context.read<AppProvider>().currentUser?.id;
    if (currentUserId == null ||
        !_currentClub!.canUserCreateEvents(currentUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You do not have permission to create events for this club.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to create event flow - FIXED NAVIGATION
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventFlow(club: _currentClub!),
      ),
    ).then((_) {
      // Refresh data when returning from create event flow
      _loadClubData();
    });
  }

    void _debugUserData() {
    final appProvider = context.read<AppProvider>();
    final currentUser = appProvider.currentUser;
    
    print('=== USER DATA DEBUG ===');
    print('User ID: ${currentUser?.id}');
    print('User Role: ${currentUser?.role}');
    print('Club IDs: ${currentUser?.clubIds}');
    print('Club IDs length: ${currentUser?.clubIds?.length}');
    print('=== END DEBUG ===');
  }
}