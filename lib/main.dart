// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'services/firebase_init.dart';
import 'providers/app_provider.dart';
import 'screens/role_home_router.dart';
import 'screens/events_screen.dart';
import 'screens/shared/clubs_screen.dart';  
import 'screens/shared/profile_screen.dart';
import 'screens/shared/login_screen.dart';
import 'utils/theme.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Install global Flutter error handler so uncaught framework errors are logged
  FlutterError.onError = (FlutterErrorDetails details) {
    // Print to console and also forward to default handler which logs in debug
    FlutterError.presentError(details);
  };

  // Capture platform-level errors as well
  WidgetsBinding.instance.platformDispatcher.onError = (Object error, StackTrace stack) {
    print('Platform error: $error');
    print('Stack: $stack');
    return true; // handled
  };

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
    // Show loading screen while AppProvider is initializing
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

    // Show login screen or home based on auth state
    return appProvider.isLoggedIn ? const RoleHomeRouter() : const LoginScreen();
  }
}