import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'participant/participant_home.dart';
import 'club/club_home.dart';
import 'admin/admin_home.dart';
import 'shared/login_screen.dart';

class RoleHomeRouter extends StatelessWidget {
  const RoleHomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    print('RoleHomeRouter: building');
    final appProvider = context.watch<AppProvider>();

    // DEBUG: Print provider state
    print('RoleHomeRouter: isLoggedIn = \\${appProvider.isLoggedIn}, userRole = \\${appProvider.userRole}');

    // Optionally, check for provider initialization if needed
    if ((appProvider as dynamic).isInitialized != null && appProvider.isInitialized == false) {
      print('RoleHomeRouter: AppProvider not initialized, showing loading');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If not logged in, show login screen
    if (!appProvider.isLoggedIn) {
      print('RoleHomeRouter: not logged in, showing LoginScreen');
      return LoginScreen();
    }

    // Route based on user role
    switch (appProvider.userRole) {
      case 'admin':
        print('RoleHomeRouter: routing to AdminHomeScreen');
        return AdminHomeScreen();
      case 'club':
        print('RoleHomeRouter: routing to ClubHomeScreen');
        return ClubHomeScreen();
      case 'participant':
        print('RoleHomeRouter: routing to ParticipantHomeScreen');
        return ParticipantHomeScreen();
      default:
        print('RoleHomeRouter: unknown role, defaulting to ParticipantHomeScreen');
        return ParticipantHomeScreen();
    }
  }
}