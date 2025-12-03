import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/role_based_bottom_nav.dart';
import 'club_events_screen.dart';
import 'event_analytics.dart';
import 'club_profile_screen.dart'; // Updated import
import 'create_event/create_event_flow.dart';
import '../../../models/club.dart';
import '../../../services/firestore_service.dart';
import '../../../providers/app_provider.dart';
import 'club_verification_screen.dart';

class ClubHomeScreen extends StatefulWidget {
  @override
  _ClubHomeScreenState createState() => _ClubHomeScreenState();
}

class _ClubHomeScreenState extends State<ClubHomeScreen> {
  int _currentIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();
  Club? _currentClub;
  bool _isLoading = true;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _initializeScreens();
    _loadClubData();
  }

  void _initializeScreens() {
    _screens = List.generate(3, (index) => 
      Center(child: CircularProgressIndicator())
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // ========== BUILD METHODS ==========
  AppBar _buildAppBar() {
    return AppBar(
      title: _isLoading 
          ? Text('Loading...')
          : Text('${_currentClub?.name ?? "Club"} Dashboard'),
      actions: [
        IconButton(
          icon: Icon(Icons.add),
          onPressed: _currentClub != null ? _createNewEvent : null,
          tooltip: 'Create New Event',
        ),
        _buildLogoutMenu(),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return Center(child: CircularProgressIndicator());

    // Check verification status to inject the banner
    return Column(
      children: [
        if (_currentClub != null && !_currentClub!.isApproved)
          _buildVerificationBanner(),
        
        Expanded(child: _screens[_currentIndex]),
      ],
    );
  }

Widget _buildVerificationBanner() {
    final bool isSubmitted = _currentClub!.approvalLetterUrl != null && 
                            _currentClub!.approvalLetterUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSubmitted ? Colors.orange[100] : Colors.red[100],
        border: Border(bottom: BorderSide(color: isSubmitted ? Colors.orange : Colors.red, width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isSubmitted ? Icons.hourglass_top : Icons.warning_amber,
                color: isSubmitted ? Colors.orange[900] : Colors.red[900],
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSubmitted ? 'Verification Pending' : 'Action Required',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSubmitted ? Colors.orange[900] : Colors.red[900],
                      ),
                    ),
                    Text(
                      isSubmitted 
                        ? 'Your documents are under review by the admin.' 
                        : 'You must verify your club to create events.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSubmitted ? Colors.orange[800] : Colors.red[800],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSubmitted)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClubVerificationScreen(club: _currentClub!),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _loadClubData(); // Refresh if they submitted
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text('Verify Now'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomNavigationBar() {
    return _isLoading 
        ? null 
        : RoleBasedBottomNav(
            selectedIndex: _currentIndex,
            onItemTapped: (index) => setState(() => _currentIndex = index),
            userRole: 'club',
          );
  }

  PopupMenuButton<String> _buildLogoutMenu() {
    return PopupMenuButton<String>(
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
    );
  }

  // ========== DATA MANAGEMENT ==========
  Future<void> _loadClubData() async {
    try {
      final club = await _getCurrentUserClub();
      if (mounted) {
        setState(() {
          _currentClub = club;
          _isLoading = false;
          _updateScreens();
        });
      }
    } catch (e) {
      print('Error loading club data: $e');
      _handleLoadError(e);
    }
  }

  void _handleLoadError(dynamic error) {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading club data: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateScreens() {
    if (_currentClub != null) {
      setState(() {
        _screens = [
          ClubEventsScreen(club: _currentClub!),     // Index 0: Events
          EventAnalyticsScreen(club: _currentClub!), // Index 1: Analytics
          ClubProfileScreen(club: _currentClub!),    // Index 2: Profile (Was Members)
        ];
      });
    }
  }

  // ========== CLUB DATA METHODS ==========
  Future<Club> _getCurrentUserClub() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final currentUser = appProvider.currentUser;

    if (currentUser == null) {
      throw Exception('No user logged in');
    }

    if (currentUser.clubIds.isEmpty) {
      throw Exception('User is not associated with any club');
    }

    final clubId = currentUser.clubIds.first;
    return await _fetchClubFromFirestore(clubId);
  }

  Future<Club> _fetchClubFromFirestore(String clubId) async {
    final clubDoc = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(clubId)
        .get();

    if (clubDoc.exists) {
      return _mapDocumentToClub(clubDoc);
    } else {
      throw Exception('Club not found');
    }
  }

  Club _mapDocumentToClub(DocumentSnapshot clubDoc) {
    final data = clubDoc.data()! as Map<String, dynamic>;
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
  }

  // ========== EVENT CREATION ==========
  void _createNewEvent() {
    if (_currentClub == null) return;

    if (!_canCreateEvent()) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventFlow(club: _currentClub!),
      ),
    ).then((_) {
      _loadClubData();
    });
  }

  bool _canCreateEvent() {
    if (!_currentClub!.canCreateEvents) {
      _handleClubCreationRestriction();
      return false;
    }
    return true;
  }

  void _handleClubCreationRestriction() {
    String message = '';
    if (!_currentClub!.isApproved) {
      message = 'Your club account is pending admin approval.';
    } else {
      message = 'You do not have permission.';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ========== LOGOUT FUNCTIONALITY (RESTORED) ==========
  Future<void> _logout() async {
    // 1. Show the confirmation dialog first
    final shouldLogout = await _showLogoutConfirmation();
    
    // 2. Only proceed if user clicked "Logout"
    if (shouldLogout == true) {
      await _performLogout();
    }
  }

  Future<bool?> _showLogoutConfirmation() {
    return showDialog<bool>(
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
  }

  Future<void> _performLogout() async {
    try {
      await context.read<AppProvider>().logout();
      // The app wrapper should handle navigation to login screen based on auth state
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}