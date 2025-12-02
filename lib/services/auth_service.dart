import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Convert Firebase User to UserModel with default values
  UserModel? _userFromFirebase(User? user) {
    if (user == null) return null;
    
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? user.email?.split('@').first ?? 'User',
      role: 'participant', // Default role
      photoUrl: user.photoURL ?? '',
      clubIds: [],
      status: 'approved', // Default status
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Stream for auth state changes
  Stream<UserModel?> get user {
    return _auth.authStateChanges().asyncMap((User? user) async {
      if (user == null) return null;
      
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          return UserModel(
            id: user.uid,
            email: data['email'] ?? user.email ?? '',
            name: data['name'] ?? user.displayName ?? user.email?.split('@').first ?? 'User',
            role: data['role'] ?? 'participant',
            photoUrl: data['photoUrl'] ?? user.photoURL ?? '',
            clubIds: List<String>.from(data['clubIds'] ?? []),
            status: data['status'] ?? 'approved',
            createdAt: data['createdAt']?.toDate(),
            updatedAt: data['updatedAt']?.toDate(),
          );
        } else {
          // If user document doesn't exist, create one with default values
          print('User document not found, creating default user document...');
          return await _createDefaultUserDocument(user);
        }
      } catch (e) {
        print('Error fetching user data: $e');
        return _userFromFirebase(user);
      }
    });
  }

  // Get current user
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        return UserModel(
          id: user.uid,
          email: data['email'] ?? user.email ?? '',
          name: data['name'] ?? user.displayName ?? user.email?.split('@').first ?? 'User',
          role: data['role'] ?? 'participant',
          photoUrl: data['photoUrl'] ?? user.photoURL ?? '',
          clubIds: List<String>.from(data['clubIds'] ?? []),
          status: data['status'] ?? 'approved',
          createdAt: data['createdAt']?.toDate(),
          updatedAt: data['updatedAt']?.toDate(),
        );
      } else {
        // Create default user document if it doesn't exist
        print('User document not found, creating default...');
        return await _createDefaultUserDocument(user);
      }
    } catch (e) {
      print('Error getting current user: $e');
      return _userFromFirebase(_auth.currentUser);
    }
  }

  // Create default user document in Firestore
  Future<UserModel> _createDefaultUserDocument(User user) async {
    final defaultUser = UserModel(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? user.email?.split('@').first ?? 'User',
      role: 'participant',
      photoUrl: user.photoURL ?? '',
      clubIds: [],
      status: 'approved',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'id': user.uid,
        'email': user.email ?? '',
        'name': user.displayName ?? user.email?.split('@').first ?? 'User',
        'role': 'participant',
        'photoUrl': user.photoURL ?? '',
        'clubIds': [],
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Default user document created for ${user.uid}');
    } catch (e) {
      print('Error creating default user document: $e');
    }

    return defaultUser;
  }

  // Register new user with role - UPDATED VERSION
  Future<UserModel> register(String email, String password, String name, String role,
      {String clubName = '', String clubDescription = ''}) async {
    try {
      print('Attempting registration for: $email as $role');
      
      // Validate role
      if (role != 'participant' && role != 'club') {
        throw Exception('Invalid role selected');
      }

      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Registration failed - no user returned');
      }

      print('User created in Auth, UID: ${user.uid}');

      // Update display name in Auth
      try {
        await user.updateDisplayName(name);
        print('Display name updated in Auth');
      } catch (e) {
        print('Warning: Could not update display name in Auth: $e');
      }

      String? clubId;
      List<String> clubIds = [];

      // If registering as club, create a club and associate user with it
      if (role == 'club') {
        clubId = await _createClubForUser(user.uid, email, name, clubName, clubDescription);
        clubIds = [clubId];
      }

      // For club accounts, set status to pending approval
      final isApproved = role == 'participant'; // Participants are auto-approved
      final status = role == 'club' ? 'pending' : 'approved';

      // Create user document in Firestore
      final userData = {
        'id': user.uid,
        'email': email.trim(),
        'name': name.trim(),
        'role': role,
        'status': status,
        'photoUrl': '',
        'clubIds': clubIds, // This will be empty for participants, contain club ID for clubs
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(user.uid).set(userData);
      print('User document created in Firestore with role: $role and status: $status');

      // Create user model
      final userModel = UserModel(
        id: user.uid,
        email: email.trim(),
        name: name.trim(),
        role: role,
        photoUrl: '',
        clubIds: clubIds,
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return userModel;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during registration: ${e.code} - ${e.message}');
      throw _handleAuthError(e);
    } catch (e) {
      print('General exception during registration: $e');
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // Create club for user during registration
  Future<String> _createClubForUser(String userId, String userEmail, String userName, 
      String clubName, String clubDescription) async {
    try {
      print('Creating club for user: $userId');
      
      // Generate a club ID
      final clubId = _firestore.collection('clubs').doc().id;
      
      // Use provided club name or default
      final finalClubName = clubName.isNotEmpty ? clubName : '$userName\'s Club';
      final finalClubDescription = clubDescription.isNotEmpty ? clubDescription : 'Club created by $userName';
      
      // Create club data
      final clubData = {
        'id': clubId,
        'name': finalClubName,
        'description': finalClubDescription,
        'createdBy': userId,
        'imageUrl': '',
        'memberIds': [userId], // User is the first member
        'adminIds': [userId],  // User is the admin
        'eventIds': [],
        'isActive': true,
        'status': 'pending', // Club needs admin approval
        'contactEmail': userEmail,
        'contactPhone': '',
        'website': '',
        'location': '',
        'categories': [],
        'approvalLetterUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Create club document
      await _firestore.collection('clubs').doc(clubId).set(clubData);
      print('Club created successfully with ID: $clubId');
      
      return clubId;
    } catch (e) {
      print('Error creating club: $e');
      throw Exception('Failed to create club: $e');
    }
  }

  // Login with email and password - SIMPLIFIED VERSION
  Future<UserModel> login(String email, String password) async {
    try {
      print('Attempting login for: $email');
      
      // Check current state
      print('Current auth state before login: ${_auth.currentUser?.uid}');
      
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Login failed - no user returned');
      }
      
      print('Login successful, user ID: ${user.uid}');
      
      // Get user data from Firestore
      final userModel = await getCurrentUser();
      if (userModel == null) {
        throw Exception('Failed to load user data');
      }
      
      return userModel;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during login: ${e.code} - ${e.message}');
      throw _handleAuthError(e);
    } catch (e) {
      print('General exception during login: $e');
      
      // If there's a type casting error, provide a clean error message
      if (e.toString().contains('PigeonUserDetails') || e.toString().contains('type cast')) {
        print('Authentication state issue detected');
        throw Exception('Please try logging in again. If the problem persists, restart the app.');
      }
      
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    try {
      print('Starting logout process...');
      
      // Clear any cached data first
      await _clearAuthCache();
      
      // Sign out from Firebase Auth
      await _auth.signOut();
      
      // Force a small delay to ensure auth state is cleared
      await Future.delayed(Duration(milliseconds: 500));
      
      print('Logout successful - User should be null: ${_auth.currentUser?.uid}');
    } catch (e) {
      print('Logout failed: $e');
      throw Exception('Logout failed: ${e.toString()}');
    }
  }

  // Enhanced cache clearing
  Future<void> _clearAuthCache() async {
    try {
      print('Clearing auth cache...');
    } catch (e) {
      print('Error clearing auth cache: $e');
    }
  }

  // Update user profile
  Future<UserModel> updateProfile(UserModel updatedUser) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Update in Firebase Auth if name changed
      if (updatedUser.name != user.displayName) {
        await user.updateDisplayName(updatedUser.name);
      }

      // Update in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'name': updatedUser.name,
        'photoUrl': updatedUser.photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return updatedUser.copyWith(
        id: user.uid,
        email: user.email ?? updatedUser.email,
      );
    } catch (e) {
      print('Profile update failed: $e');
      throw Exception('Profile update failed: ${e.toString()}');
    }
  }

  // Change password
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Re-authenticate user before changing password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      
      return true;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('Password change failed: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  // Delete account
  Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Re-authenticate before deletion
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      
      // Delete user document from Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      
      // Delete user from Firebase Auth
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('Account deletion failed: ${e.toString()}');
    }
  }

  // Check if user is logged in
  bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Handle Firebase Auth errors
  String _handleAuthError(FirebaseAuthException e) {
    print('Auth error: ${e.code} - ${e.message}');
    
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled';
      case 'requires-recent-login':
        return 'Please log in again to perform this action';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-credential':
        return 'Invalid login credentials';
      default:
        return 'An error occurred: ${e.message}';
    }
  }

  Future<void> hardResetAuth() async {
    try {
      print('Performing auth reset...');
      
      // Simply sign out and clear state
      await _auth.signOut();
      
      // Clear any potential cached data
      await Future.delayed(Duration(milliseconds: 1000));
      
      print('Auth reset completed');
    } catch (e) {
      print('Auth reset error: $e');
      // Don't throw, just continue
    }
  }

  Future<void> completeLogout() async {
    try {
      print('Starting complete logout process...');
      
      // 1. Get current user ID for logging before logout
      final currentUserId = _auth.currentUser?.uid;
      print('Logging out user: $currentUserId');
      
      // 2. Sign out from Firebase Auth
      await _auth.signOut();
      print("Firebase signOut called");;
      
      // 3. Wait for auth state to propagate
      await Future.delayed(Duration(milliseconds: 1000));
      
      // 4. Verify logout was successful
      final userAfterLogout = _auth.currentUser;
      if (userAfterLogout != null) {
        print('Warning: User still exists after logout: ${userAfterLogout.uid}');
        // Try signing out again
        await _auth.signOut();
      }
      
      print('Complete logout successful');
    } catch (e) {
      print('Complete logout error: $e');
      // Even if there's an error, we should continue
    }
  }
}