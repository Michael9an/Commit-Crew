import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// --- SERVICE IMPORTS ---
import 'services/firebase_init.dart';
import 'services/review_service.dart'; 

// --- PROVIDER IMPORTS ---
import 'providers/app_provider.dart';

// --- SCREEN IMPORTS ---
import 'screens/role_home_router.dart';
import 'screens/events_screen.dart';
import 'screens/shared/clubs_screen.dart';  
import 'screens/shared/profile_screen.dart';
import 'screens/shared/login_screen.dart';
import 'screens/participant/notification_screen.dart';

import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- 1. INITIALIZE FIREBASE ---
  await Firebase.initializeApp(); 

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  WidgetsBinding.instance.platformDispatcher.onError = (Object error, StackTrace stack) {
    print('Platform error: $error');
    print('Stack: $stack');
    return true; 
  };

  // --- 2. ACTIVATE APP CHECK ---
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeApp();
  }

  Future<bool> _initializeApp() async {
    final firebaseReady = await safeInitializeFirebase();
    return firebaseReady;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return ChangeNotifierProvider(
          create: (context) => AppProvider()..initialize(),
          child: Consumer<AppProvider>(
            builder: (context, appProvider, child) {
              return MaterialApp(
                title: 'Club Events',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: appProvider.themeMode,
                
                routes: {
                  '/': (context) => _buildHomeScreen(appProvider),
                  '/home_screen': (context) => const RoleHomeRouter(),
                  '/events_screen': (context) => const EventsScreen(),
                  '/clubs_screen': (context) => const ClubsScreen(),
                  '/profile_screen': (context) => const ProfileScreen(),
                  '/login_screen': (context) => const LoginScreen(),
                  '/notification_screen': (context) => const NotificationScreen(),
                },

                onUnknownRoute: (settings) {
                  return MaterialPageRoute(
                    builder: (context) => _buildHomeScreen(
                      Provider.of<AppProvider>(context, listen: false)
                    ),
                  );
                },
                
                debugShowCheckedModeBanner: false,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHomeScreen(AppProvider appProvider) {
    if (appProvider.isLoading && !appProvider.isInitialized) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (appProvider.isLoggedIn) {
      // THIS STREAM PROVIDER MAKES NOTIFICATIONS WORK APP-WIDE
      return StreamProvider<List<Map<String, dynamic>>>(
        create: (_) => ReviewService().getNotifications(),
        initialData: const [],
        catchError: (_, __) => [], 
        child: const RoleHomeRouter(),
      );
    } 
    
    return const LoginScreen();
  }
}