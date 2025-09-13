// File: lib/services/auth_service.dart
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import './api_service.dart'; // Your ApiService
import '../models/auth_response_model.dart'; // For LoginSuccessData
import '../models/registration_response_model.dart'; // For RegistrationResponseModel
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import '../models/user.dart'
    as app_user; // Your frontend User model for adminCreateUser response

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();

  AuthService();

  // Helper to handle login response, token storage, and role verification
  Future<LoginSuccessData> _handleLoginResponse(
      Map<String, dynamic> responseData, String expectedRole) async {
    final token = responseData['token'] as String?;
    final userId = responseData['userId'] as String?;
    final userName = responseData['name'] as String?;
    final userRole = responseData['role'] as String?;

    if (token != null &&
        userId != null &&
        userName != null &&
        userRole != null) {
      if (userRole.toLowerCase() != expectedRole.toLowerCase()) {
        await logout(); // Clear any potentially stored token if role mismatch
        throw Exception(
            'Access Denied: Expected role $expectedRole but received $userRole. Please use the correct login portal.');
      }
      await _storage.write(key: 'jwt_token', value: token);
      await _storage.write(key: 'user_id', value: userId);
      await _storage.write(key: 'user_role', value: userRole);
      await _storage.write(key: 'user_name', value: userName);
      print(
          'AuthService: $expectedRole login successful, token and user info stored for $userName.');
      return LoginSuccessData.fromJson(responseData);
    } else {
      throw Exception('Login response missing essential data.');
    }
  }

  Future<LoginSuccessData> loginCustomer(String email, String password) async {
    try {
      print('AuthService: Attempting customer login for $email');
      final responseData = await _apiService.login(email, password);
      return await _handleLoginResponse(responseData, 'customer');
    } catch (e) {
      print('AuthService: Customer login failed: ${e.toString()}');
      rethrow;
    }
  }

  Future<LoginSuccessData> loginDriver(String email, String password) async {
    try {
      print('AuthService: Attempting driver login for $email');
      final responseData = await _apiService.login(email, password);
      return await _handleLoginResponse(responseData, 'driver');
    } catch (e) {
      print('AuthService: Driver login failed: ${e.toString()}');
      rethrow;
    }
  }

  Future<LoginSuccessData> loginAdmin(String email, String password) async {
    try {
      print('AuthService: Attempting admin login for $email');
      final responseData = await _apiService.login(email, password);
      return await _handleLoginResponse(responseData, 'admin');
    } catch (e) {
      print('AuthService: Admin login failed: ${e.toString()}');
      rethrow;
    }
  }

  // ============================= MODIFIED =============================
  Future<RegistrationResponseModel> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? referralCode, // FIX: Added the optional referralCode parameter
  }) async {
    try {
      print('AuthService: Attempting customer registration for $email');
      final responseData = await _apiService.registerCustomer(
        name: name,
        email: email,
        phone: phone,
        password: password,
        referralCode: referralCode, // FIX: Pass the code to the ApiService
      );
      return RegistrationResponseModel.fromJson(responseData);
    } catch (e) {
      print('AuthService: Customer registration failed: ${e.toString()}');
      rethrow;
    }
  }

  // ========================== NEW METHOD TO FIX BUILD ERROR ==========================
  /// Verifies the 4-digit OTP for the given email by calling the ApiService.
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      return await _apiService.verifyOtp(email: email, otp: otp);
    } catch (e) {
      rethrow;
    }
  }
  // =================================================================================

  Future<RegistrationResponseModel> registerDriver({
    required String name,
    required String email,
    required String phone,
    required String password,
    required Map<String, String> bankDetails,
  }) async {
    try {
      print('AuthService: Attempting driver self-registration for $email');
      final responseData = await _apiService.registerDriver(
        name: name,
        email: email,
        phone: phone,
        password: password,
        bankDetails: bankDetails,
      );
      return RegistrationResponseModel.fromJson(responseData);
    } catch (e) {
      print('AuthService: Driver self-registration failed: ${e.toString()}');
      rethrow;
    }
  }

  Future<app_user.User> adminCreateUser({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    try {
      print(
          'AuthService: Admin attempting to create new user (Role: $role) with email: $email');
      final createdUserData = await _apiService.adminCreateUser(
        name: name,
        email: email,
        phone: phone,
        password: password,
        role: role,
      );
      print(
          'AuthService: Admin successfully created user ID: ${createdUserData.id}');
      return createdUserData;
    } catch (e) {
      print('AuthService: Admin failed to create user: ${e.toString()}');
      rethrow;
    }
  }

  // ✅ ADD THIS NEW METHOD
  Future<void> signInToFirebase() async {
    try {
      // Get the custom token from your backend
      final String customToken = await _apiService.getFirebaseToken();
      // Use the token to sign in on the device
      await _firebaseAuth.signInWithCustomToken(customToken);
      print('AuthService: Successfully signed into Firebase.');
    } catch (e) {
      print('AuthService: Firebase sign-in failed: $e');
      // Decide if you want to throw an error or fail silently
    }
  }

  Future<String> requestPasswordReset(String email) async {
    try {
      print('AuthService: Requesting password reset for $email');
      final responseData = await _apiService.requestPasswordReset(email);
      if (responseData['message'] == null) {
        print('AuthService: Warning: API response missing message field.');
      }
      return responseData['message'] as String? ??
          'Password reset request submitted. Check your email.';
    } catch (e) {
      print('AuthService: Password reset request failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyPasswordResetToken({
    required String email,
    required String token,
  }) async {
    try {
      return await _apiService.verifyPasswordResetToken(
          email: email, token: token);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> resetPassword(String token, String newPassword) async {
    try {
      print('AuthService: Attempting to reset password with token $token');
      final responseData = await _apiService.resetPassword(token, newPassword);
      print(
          'AuthService: Reset password response - $responseData'); // Log the full response
      if (responseData['message'] == null || responseData['message'].isEmpty) {
        print(
            'AuthService: Warning: API response missing or empty message field.');
        throw Exception('Password reset response invalid.');
      }
      if (responseData['message'] != 'Password has been reset successfully.') {
        print(
            'AuthService: Unexpected success message: ${responseData['message']}');
        throw Exception('Password reset failed with unexpected response.');
      }
      print('AuthService: Password successfully reset for token $token');
      return responseData['message'] as String ??
          'Password reset successfully.';
    } catch (e) {
      print('AuthService: Password reset failed: $e');
      rethrow;
    }
  }

  Future<LoginSuccessData> signInWithGoogle(String idToken) async {
    try {
      final responseData = await _apiService.googleSignIn(idToken);
      // The backend returns a standard login response after verifying the token
      return await _handleLoginResponse(responseData, 'customer');
    } catch (e) {
      rethrow;
    }
  }

  Future<app_user.User?> getCurrentUserProfile() async {
    final token = await getToken();
    if (token == null) {
      print('AuthService: No token found, cannot fetch profile.');
      return null;
    }
    try {
      print('AuthService: Fetching current user profile.');
      final userProfile = await _apiService.getMyProfile();
      return userProfile;
    } catch (e) {
      print('AuthService: Failed to fetch current user profile: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'user_name');
    print('AuthService: User logged out, token and details cleared.');
  }

  Future<String?> getToken() async => await _storage.read(key: 'jwt_token');
  Future<String?> getUserId() async => await _storage.read(key: 'user_id');
  Future<String?> getUserRole() async => await _storage.read(key: 'user_role');
  Future<String?> getUserName() async => await _storage.read(key: 'user_name');

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null;
  }
}
