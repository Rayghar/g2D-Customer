// File: lib/models/user.dart (Enhanced)
import 'package:flutter/material.dart'; // For UniqueKey
import 'notification_preferences_model.dart'; // Import the new model

class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone; // Added
  final String?
      status; // Added for user account status (active, suspended, etc.)
  final bool? isEmailVerified; // Added for email verification status
  final String? defaultAddressId; // Added
  final double walletBalance; // Added (assuming backend sends as number)
  final NotificationPreferencesModel
      notificationPreferences; // Changed type to external model
  final bool? isAvailableOnline; // Added for driver availability
  final String? referredBy; // Added for referral tracking
  final bool? hasUsedReferralBenefit; // Added for referral benefit application
  final List<String> fcmTokens; // Added for FCM device tokens
  final String? googleId; // Added for Google Sign-in ID
  final String? gatewayCustomerId; // Added for payment gateway customer ID
  final double? latitude; // Added for location (if stored with user)
  final double? longitude; // Added for location (if stored with user)

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.status, // Initialize here
    this.isEmailVerified, // Initialize here
    this.defaultAddressId,
    this.walletBalance = 0.0,
    required this.notificationPreferences,
    this.isAvailableOnline, // Initialize here
    this.referredBy, // Initialize here
    this.hasUsedReferralBenefit, // Initialize here
    this.fcmTokens = const [], // Initialize with empty list
    this.googleId, // Initialize here
    this.gatewayCustomerId, // Initialize here
    this.latitude, // Initialize here
    this.longitude, // Initialize here
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'customer',
      phone: json['phone'] as String?,
      status: json['status'] as String?, // Parse new field
      isEmailVerified: json['isEmailVerified'] as bool?, // Parse new field
      defaultAddressId: json['defaultAddressId'] as String?,
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.0,
      notificationPreferences: NotificationPreferencesModel.fromJson(
          json['notificationPreferences'] as Map<String, dynamic>? ??
              {}), // FIX: Provide an empty map if null
      isAvailableOnline: json['isAvailableOnline'] as bool?, // Parse from JSON
      referredBy: json['referredBy'] as String?, // Parse new field
      hasUsedReferralBenefit:
          json['hasUsedReferralBenefit'] as bool?, // Parse new field
      fcmTokens: (json['fcmTokens'] as List<dynamic>?) // Parse new field
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      googleId: json['googleId'] as String?, // Parse new field
      gatewayCustomerId:
          json['gatewayCustomerId'] as String?, // Parse new field
      latitude: (json['latitude'] as num?)?.toDouble(), // Parse new field
      longitude: (json['longitude'] as num?)?.toDouble(), // Parse new field
    );
  }

  // Added copyWith method for immutable updates
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? status, // Add to copyWith
    bool? isEmailVerified, // Add to copyWith
    String? defaultAddressId,
    double? walletBalance,
    NotificationPreferencesModel?
        notificationPreferences, // Use external model type
    bool? isAvailableOnline,
    String? referredBy, // Add to copyWith
    bool? hasUsedReferralBenefit, // Add to copyWith
    List<String>? fcmTokens, // Add to copyWith
    String? googleId, // Add to copyWith
    String? gatewayCustomerId, // Add to copyWith
    double? latitude, // Add to copyWith
    double? longitude, // Add to copyWith
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      status: status ?? this.status, // Copy new field
      isEmailVerified:
          isEmailVerified ?? this.isEmailVerified, // Copy new field
      defaultAddressId: defaultAddressId ?? this.defaultAddressId,
      walletBalance: walletBalance ?? this.walletBalance,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      isAvailableOnline: isAvailableOnline ?? this.isAvailableOnline,
      referredBy: referredBy ?? this.referredBy, // Copy new field
      hasUsedReferralBenefit: hasUsedReferralBenefit ??
          this.hasUsedReferralBenefit, // Copy new field
      fcmTokens: fcmTokens ?? this.fcmTokens, // Copy new field
      googleId: googleId ?? this.googleId, // Copy new field
      gatewayCustomerId:
          gatewayCustomerId ?? this.gatewayCustomerId, // Copy new field
      latitude: latitude ?? this.latitude, // Copy new field
      longitude: longitude ?? this.longitude, // Copy new field
    );
  }

  // toJson might not be needed if this model is only for reading user profile data,
  // but good for consistency and if sending User objects back to backend (e.g., profile update)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      if (phone != null) 'phone': phone,
      if (status != null) 'status': status, // Include new field in toJson
      if (isEmailVerified != null)
        'isEmailVerified': isEmailVerified, // Include new field in toJson
      if (defaultAddressId != null) 'defaultAddressId': defaultAddressId,
      'walletBalance': walletBalance,
      'notificationPreferences': notificationPreferences.toJson(),
      if (isAvailableOnline != null) 'isAvailableOnline': isAvailableOnline,
      if (referredBy != null)
        'referredBy': referredBy, // Include new field in toJson
      if (hasUsedReferralBenefit != null)
        'hasUsedReferralBenefit':
            hasUsedReferralBenefit, // Include new field in toJson
      'fcmTokens': fcmTokens, // Include new field in toJson
      if (googleId != null) 'googleId': googleId, // Include new field in toJson
      if (gatewayCustomerId != null)
        'gatewayCustomerId': gatewayCustomerId, // Include new field in toJson
      if (latitude != null) 'latitude': latitude, // Include new field in toJson
      if (longitude != null)
        'longitude': longitude, // Include new field in toJson
    };
  }

  String get firstName => name.split(' ').first;
}
