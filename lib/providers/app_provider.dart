// app_provider.dart
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AppProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  ThemeMode _themeMode = ThemeMode.light;
  String? _error;
  bool _isInitialized = false;

  UserModel? get currentUser => _currentUser;
  // Expose the current user's role for UI routing (defaults to participant)
  String get userRole => _currentUser?.role ?? 'participant';
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _themeMode;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  // Initialize the app provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      print('AppProvider: Initializing...');
      // Check if user is already logged in
      _currentUser = await _authService.getCurrentUser();
      _isInitialized = true;
      print('AppProvider: Initialization complete. User: ${_currentUser?.email}');
    } catch (e) {
      _error = 'Initialization failed: $e';
      print('AppProvider: Initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('AppProvider: Attempting login for $email');
      _currentUser = await _authService.login(email, password);
      print('AppProvider: Login successful for ${_currentUser?.email}');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString(); // Use the exact error message from AuthService
      print('AppProvider: Login error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

 // In app_provider.dart - Update the register method
Future<bool> register(String email, String password, String displayName, String role,
    {String clubName = '', String clubDescription = ''}) async {
  _isLoading = true;
  _error = null;
  notifyListeners();
  
  try {
    print('AppProvider: Attempting registration for $email as $role');
    _currentUser = await _authService.register(
      email, password, displayName, role, 
      clubName: clubName, clubDescription: clubDescription
    );
    print('AppProvider: Registration successful for ${_currentUser?.email}');
    _isLoading = false;
    notifyListeners();
    return true;
  } catch (e) {
    _error = e.toString();
    print('AppProvider: Registration error: $e');
    _isLoading = false;
    notifyListeners();
    return false;
  }
}

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('AppProvider: Attempting password reset for $email');
      await _authService.resetPassword(email);
      print('AppProvider: Password reset email sent to $email');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('AppProvider: Password reset error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // In app_provider.dart - Update logout method
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      print('AppProvider: Logging out user ${_currentUser?.email}');
      
      // Clear local state FIRST
      final oldUser = _currentUser;
      _currentUser = null;
      _error = null;
      
      // Notify listeners immediately to update UI
      notifyListeners();
      
      // Then call auth service logout
      await _authService.completeLogout(); // Use the new method
      
      print('AppProvider: Logout successful for user ${oldUser?.email}');
    } catch (e) {
      _error = 'Logout failed: $e';
      print('AppProvider: Logout error: $e');
      
      // Still clear user data even if logout has issues
      _currentUser = null;
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(UserModel updatedUser) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('AppProvider: Updating profile for ${updatedUser.email}');
      _currentUser = await _authService.updateProfile(updatedUser);
      print('AppProvider: Profile update successful');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Profile update failed: $e';
      print('AppProvider: Profile update error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('AppProvider: Changing password');
      final success = await _authService.changePassword(currentPassword, newPassword);
      print('AppProvider: Password change successful: $success');
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = e.toString();
      print('AppProvider: Password change error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount(String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('AppProvider: Deleting account for ${_currentUser?.email}');
      await _authService.deleteAccount(password);
      _currentUser = null;
      _error = null;
      print('AppProvider: Account deletion successful');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('AppProvider: Account deletion error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    print('AppProvider: Theme toggled to $_themeMode');
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    print('AppProvider: Theme set to $mode');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void refreshUser() async {
    try {
      print('AppProvider: Refreshing user data');
      _currentUser = await _authService.getCurrentUser();
      print('AppProvider: User data refreshed: ${_currentUser?.email}');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to refresh user data: $e';
      print('AppProvider: User refresh error: $e');
    }
  }

  // Helper method to check if user has specific role
  bool hasRole(String role) {
    return _currentUser?.role == role;
  }

  // Helper method to check if user is admin of a specific club
  bool isClubAdmin(String clubId) {
    return _currentUser?.clubIds?.contains(clubId) == true && 
           (_currentUser?.role == 'admin' || _currentUser?.role == 'club_admin');
  }

  // Helper method to check if user is member of a club
  bool isClubMember(String clubId) {
    return _currentUser?.clubIds?.contains(clubId) == true;
  }

  // Method to add club to user's clubs
  void addUserToClub(String clubId) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        clubIds: [..._currentUser!.clubIds ?? [], clubId],
      );
      notifyListeners();
    }
  }

  // Method to remove club from user's clubs
  void removeUserFromClub(String clubId) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        clubIds: _currentUser!.clubIds?.where((id) => id != clubId).toList() ?? [],
      );
      notifyListeners();
    }
  }

  // Get user's display name with fallback
  String get displayName {
    return _currentUser?.name?.isNotEmpty == true 
        ? _currentUser!.name!
        : _currentUser?.email?.split('@').first ?? 'User';
  }

  // Get user's initial for avatar
  String get userInitial {
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
  }

  // Check if user profile is complete
  bool get isProfileComplete {
    return _currentUser?.name?.isNotEmpty == true &&
           _currentUser?.email?.isNotEmpty == true;
  }
}