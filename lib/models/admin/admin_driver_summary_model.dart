// File: lib/models/admin/admin_driver_summary_model.dart

import 'package:intl/intl.dart';

class AdminDriverSummaryModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime registrationDate;
  String accountStatus; // e.g., "Pending Approval", "Active", "Suspended"
  bool
      isAvailableOnline; // Current work availability (online/offline for orders)
  final String? photoUrl;
  final int
      totalDeliveriesCompleted; // Renamed from totalDeliveries for clarity
  final String? vehicleDetails; // e.g., "Bike - KJA123"
  final double averageRating;

  AdminDriverSummaryModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.registrationDate,
    required this.accountStatus,
    required this.isAvailableOnline,
    this.photoUrl,
    this.totalDeliveriesCompleted = 0,
    this.vehicleDetails,
    this.averageRating = 0.0,
  });

  factory AdminDriverSummaryModel.fromJson(Map<String, dynamic> json) {
    return AdminDriverSummaryModel(
      id: json['id'] as String? ?? 'N/A',
      name: json['name'] as String? ?? 'Unknown Driver',
      email: json['email'] as String? ?? 'N/A',
      phone: json['phone'] as String? ?? 'N/A',
      registrationDate:
          DateTime.tryParse(json['registrationDate'] as String? ?? '') ??
              DateTime.now(),
      accountStatus: json['accountStatus'] as String? ?? 'Unknown',
      isAvailableOnline: (json['isAvailableOnline'] as bool?) ?? false,
      photoUrl: json['photoUrl'] as String?,
      totalDeliveriesCompleted:
          (json['totalDeliveriesCompleted'] as num?)?.toInt() ?? 0,
      vehicleDetails: json['vehicleDetails'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'registrationDate': registrationDate.toIso8601String(),
      'accountStatus': accountStatus,
      'isAvailableOnline': isAvailableOnline,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'totalDeliveriesCompleted': totalDeliveriesCompleted,
      if (vehicleDetails != null) 'vehicleDetails': vehicleDetails,
      'averageRating': averageRating,
    };
  }

  String get formattedRegistrationDate =>
      DateFormat('dd MMM yyyy').format(registrationDate.toLocal());
  String get initials => name.isNotEmpty
      ? name.trim().split(' ').map((l) => l[0]).take(2).join().toUpperCase()
      : '?';
}
