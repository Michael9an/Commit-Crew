import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../firebase_options.dart';

/// Initialize Firebase safely across platforms.
Future<bool> safeInitializeFirebase() async {
  try {
    print('Initializing Firebase...');
    
    // Check if Firebase is already initialized
    try {
      Firebase.app();
      print('Firebase already initialized');
      return true;
    } catch (e) {
      print('Firebase not initialized, proceeding with initialization...');
    }
    
    if (kIsWeb) {
      print('Initializing for Web platform');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      print('Initializing for Mobile platform');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Test Firebase services with timeout
    print('Testing Firebase Auth...');
    final auth = FirebaseAuth.instance;
    print('Firebase Auth initialized: ${auth.app.name}');

    print('Testing Firestore...');
    final firestore = FirebaseFirestore.instance;
    print('Firestore initialized: ${firestore.app.name}');

    print('Testing Firebase Storage...');
    final storage = FirebaseStorage.instance;
    print('Firebase Storage initialized: ${storage.app.name}');

    // Configure settings with error handling
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      print('Warning: Could not configure Firestore settings: $e');
    }

    try {
      FirebaseStorage.instance.setMaxUploadRetryTime(const Duration(seconds: 15));
      FirebaseStorage.instance.setMaxOperationRetryTime(const Duration(seconds: 15));
    } catch (e) {
      print('Warning: Could not configure Storage settings: $e');
    }

    print('✅ Firebase initialization completed successfully');
    return true;
  } catch (e, stackTrace) {
    print('❌ Firebase initialization failed: $e');
    print('Stack trace: $stackTrace');
    return false;
  }
}

/// Simple initialization check
Future<bool> isFirebaseInitialized() async {
  try {
    // Try to access a Firebase service to check if it's initialized
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser; // This will throw if not initialized
    return auth.app != null;
  } catch (e) {
    return false;
  }
}

/// Legacy function for backward compatibility
Future<bool> ensureFirebaseInitialized({Duration timeout = const Duration(seconds: 10)}) async {
  try {
    // First check if already initialized
    if (await isFirebaseInitialized()) {
      return true;
    }
    
    // If not, try to initialize with timeout
    return await safeInitializeFirebase().timeout(timeout, onTimeout: () {
      print('Firebase initialization timed out after $timeout');
      return false;
    });
  } catch (e) {
    print('ensureFirebaseInitialized error: $e');
    return false;
  }
}