// File: lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert'; // For jsonDecode and jsonEncode
import 'dart:async';
import 'package:crypto/crypto.dart'; // >>> ADDED (Apple)
import 'package:flutter/foundation.dart';

import '../services/api_service.dart'; // Assuming ApiService exists for login calls
import '../models/user.dart'; // Assuming User model exists to store user details
import '../models/notification_preferences_model.dart'; // Import the new notification preferences model

class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService(); // Use your ApiService instance

  User? _currentUser;
  String? _token;
  bool _isAuthenticated = false;
  bool _isAdmin = false;
  bool _isCustomer = false;
  bool _isDriver = false;

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;
  bool get isCustomer => _isCustomer;
  bool get isDriver => _isDriver;

  AuthProvider() {
    _loadAuthData(); // Load data when the provider is initialized
  }

  // Load authentication data from secure storage
  Future<void> _loadAuthData() async {
    try {
      final String? storedToken = await _storage.read(key: 'jwt_token');
      final String? storedUserId = await _storage.read(key: 'user_id');
      final String? storedUserName = await _storage.read(key: 'user_name');
      final String? storedUserRole = await _storage.read(key: 'user_role');

      // Notification preferences are not typically stored in simple login data
      // and are often fetched with the full user profile. Initialize with defaults.
      final NotificationPreferencesModel defaultNotificationPreferences =
          NotificationPreferencesModel(orderUpdates: true, promotions: true);

      if (storedToken != null &&
          storedUserId != null &&
          storedUserName != null &&
          storedUserRole != null) {
        _token = storedToken;
        _currentUser = User(
          id: storedUserId,
          name: storedUserName,
          role: storedUserRole,
          email: '', // Email not stored directly, will be fetched on demand
          notificationPreferences:
              defaultNotificationPreferences, // Provide default or dummy
        );
        _isAuthenticated = true;
        _setRoleFlags(storedUserRole);
        debugPrint(
            'AuthProvider: Loaded authenticated session for user ID: $storedUserId, role: $storedUserRole');
      } else {
        _clearAuthData();
        debugPrint('AuthProvider: No stored authentication data found.');
      }
    } catch (e) {
      debugPrint('AuthProvider: Error loading auth data: $e');
      _clearAuthData();
    } finally {
      notifyListeners(); // Notify listeners after loading, even if no data found
    }
  }

  // Set role-specific flags
  void _setRoleFlags(String role) {
    _isAdmin = (role == 'admin');
    _isCustomer = (role == 'customer');
    _isDriver = (role == 'driver');
  }

  // Handle user login
  Future<void> login(String email, String password) async {
    try {
      final Map<String, dynamic> response =
          await _apiService.login(email, password);

      _token = response['token'];
      _currentUser = User(
        id: response['userId'],
        name: response['name'],
        role: response['role'],
        email:
            email, // Assuming email is available from login response or input
        // Notification preferences are not typically returned directly by login.
        // Fetch them with the full user profile after successful login.
        notificationPreferences: NotificationPreferencesModel(
            orderUpdates: true, promotions: true), // Provide default or dummy
      );
      _isAuthenticated = true;
      _setRoleFlags(response['role']);

      // Store in secure storage
      await _storage.write(key: 'jwt_token', value: _token);
      await _storage.write(key: 'user_id', value: _currentUser!.id);
      await _storage.write(key: 'user_name', value: _currentUser!.name);
      await _storage.write(key: 'user_role', value: _currentUser!.role);

      debugPrint(
          'AuthProvider: User logged in: ${_currentUser!.id}, Role: ${_currentUser!.role}');
      // Immediately fetch full profile to get notification preferences and other details
      await fetchUserProfile();
      notifyListeners();
    } catch (e) {
      _clearAuthData(); // Clear data if login fails
      debugPrint('AuthProvider: Login failed: $e');
      rethrow; // Rethrow to let UI handle error
    }
  }

  // Handle user logout
  Future<void> logout() async {
    _clearAuthData();
    await _storage.deleteAll(); // Clear all stored sensitive data
    debugPrint('AuthProvider: User logged out.');
    notifyListeners();
  }

  // Clear authentication data in memory
  void _clearAuthData() {
    _currentUser = null;
    _token = null;
    _isAuthenticated = false;
    _isAdmin = false;
    _isCustomer = false;
    _isDriver = false;
  }

  // Update user data if profile is edited or new data is fetched
  void updateCurrentUserProfile(User updatedUser) {
    _currentUser = updatedUser;
    // Re-evaluate role flags in case role was updated (e.g., by admin)
    _setRoleFlags(updatedUser.role);
    notifyListeners();
  }

  // Fetch full user profile from API
  Future<void> fetchUserProfile() async {
    if (!isAuthenticated) return;
    try {
      final User fullProfile = await _apiService
          .getMyProfile(); // This method should fetch the full User model
      updateCurrentUserProfile(
          fullProfile); // Update the current user in provider
      debugPrint('AuthProvider: Fetched and updated full user profile.');
    } catch (e) {
      debugPrint('AuthProvider: Failed to fetch full user profile: $e');
      // Decide if this warrants logging out or just displaying an error
    }
  }
}
