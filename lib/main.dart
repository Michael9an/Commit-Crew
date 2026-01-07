// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// --- SERVICE IMPORTS ---
import 'services/firebase_init.dart';
import 'services/review_service.dart'; // From main1.dart (HEAD)

// --- PROVIDER IMPORTS ---
import 'providers/app_provider.dart';

// --- SCREEN IMPORTS ---
import 'screens/role_home_router.dart';
import 'screens/events_screen.dart';
import 'screens/shared/clubs_screen.dart';  
import 'screens/shared/profile_screen.dart';
import 'screens/shared/login_screen.dart';
import 'screens/participant/notification_screen.dart'; // From main1.dart (HEAD)

import 'utils/theme.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // --- 1. INITIALIZE FIREBASE FIRST ---
  // You must do this before using ANY Firebase feature (like App Check)
  await Firebase.initializeApp(); 
  // ------------------------------------

  // Install global Flutter error handler so uncaught framework errors are logged
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Capture platform-level errors as well
  WidgetsBinding.instance.platformDispatcher.onError = (Object error, StackTrace stack) {
    print('Platform error: $error');
    print('Stack: $stack');
    return true; // handled
  };

  // --- 2. NOW ACTIVATE APP CHECK ---
  await FirebaseAppCheck.instance.activate(
    // This tells the app: "If I am on a phone, use the Debug provider"
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // Run the app
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
    print('Starting app initialization...');
    
    // Initialize Firebase
    final firebaseReady = await safeInitializeFirebase();
    print('Firebase initialized: $firebaseReady');
    
    if (!firebaseReady) {
      print('Firebase initialization failed, but continuing with app...');
    }
    
    return firebaseReady;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        // Show loading screen while initializing
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      'Initializing Event Mate...',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Setting up Firebase services',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Show error screen if initialization failed, but still allow app to run
        if (snapshot.hasError || !snapshot.data!) {
          print('App initialization completed with issues - Firebase: ${snapshot.data}');
          // We'll still run the app even if Firebase failed
        } else {
          print('App initialization completed successfully');
        }

        // Main app with Provider - always create even if Firebase failed
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
                  // Added from main1.dart (HEAD)
                  '/notification_screen': (context) => const NotificationScreen(),
                },

                // Handle unknown routes
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
    // Show detailed loading screen while AppProvider is initializing
    if (appProvider.isLoading && !appProvider.isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Loading your events...'),
            ],
          ),
        ),
      );
    }

    // Logic merged from main1.dart (HEAD) to support Notifications
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