import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/role_based_bottom_nav.dart';
import 'club_events_screen.dart';
import 'event_analytics.dart';
import 'club_profile_screen.dart';
import 'create_event/create_event_flow.dart';
import '../../../models/club.dart';
import '../../../services/firestore_service.dart';
import '../../../providers/app_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClubHomeScreen extends StatefulWidget {
  const ClubHomeScreen({super.key});

  @override
  _ClubHomeScreenState createState() => _ClubHomeScreenState();
}

class _ClubHomeScreenState extends State<ClubHomeScreen> {
  int _currentIndex = 0;
  Club? _currentClub;
  bool _isLoading = true;

  // Define screens list
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Start with loading indicators
    _screens = [
      const Center(child: CircularProgressIndicator()),
      const Center(child: CircularProgressIndicator()),
      const Center(child: CircularProgressIndicator()),
    ];
    _loadClubData();
  }

  Future<void> _loadClubData() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final currentUser = appProvider.currentUser;

    if (currentUser != null && currentUser.clubIds.isNotEmpty) {
      try {
        final clubId = currentUser.clubIds.first;
        final doc = await FirebaseFirestore.instance.collection('clubs').doc(clubId).get();
        
        if (doc.exists && mounted) {
          final clubData = Club.fromFirestore(doc.data()!);
          setState(() {
            _currentClub = clubData;
            _isLoading = false;
            // Initialize the real screens with data
            _screens = [
              ClubEventsScreen(club: _currentClub!),     // Index 0
              EventAnalyticsScreen(club: _currentClub!), // Index 1
              ClubProfileScreen(club: _currentClub!),    // Index 2
            ];
          });
        }
      } catch (e) {
        print("Error loading club: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep AppBar simple for now
      appBar: AppBar(
        title: Text(_currentClub?.name ?? 'Club Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            // Simple check: can create event?
            onPressed: (_currentClub?.isApproved ?? false) 
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CreateEventFlow(club: _currentClub!)),
                    ).then((_) => _loadClubData());
                  } 
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AppProvider>().logout(),
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : _screens[_currentIndex],
      bottomNavigationBar: RoleBasedBottomNav(
        selectedIndex: _currentIndex,
        onItemTapped: (index) => setState(() => _currentIndex = index),
        userRole: 'club',
      ),
    );
  }
}