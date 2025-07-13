// File: lib/models/admin/admin_driver_detail_model.dart

import 'package:intl/intl.dart';
import './admin_order_summary_model.dart'; // For recent orders

class AdminDriverDetailModel {
  final String id;
  String name;
  String email;
  String phone;
  final DateTime registrationDate;
  String accountStatus; // "Pending Approval", "Active", "Suspended"
  bool isAvailableOnline; // Current work availability
  final String? photoUrl;
  String? vehicleType;
  String? licensePlate;
  String? serviceZone;
  final int totalDeliveriesCompleted;
  final double averageRating; // 0.0 to 5.0
  final double totalEarnings;
  final DateTime? lastDeliveryDate;
  final List<AdminOrderSummaryModel> recentDeliveries; // Using admin summary
  // Potential future fields:
  // final List<DocumentModel> documents; // e.g., license, vehicle registration
  // final List<PerformanceMetric> performanceMetrics;

  AdminDriverDetailModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.registrationDate,
    required this.accountStatus,
    required this.isAvailableOnline,
    this.photoUrl,
    this.vehicleType,
    this.licensePlate,
    this.serviceZone,
    this.totalDeliveriesCompleted = 0,
    this.averageRating = 0.0,
    this.totalEarnings = 0.0,
    this.lastDeliveryDate,
    this.recentDeliveries = const [],
  });

  factory AdminDriverDetailModel.fromJson(Map<String, dynamic> json) {
    return AdminDriverDetailModel(
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
      vehicleType: json['vehicleType'] as String?,
      licensePlate: json['licensePlate'] as String?,
      serviceZone: json['serviceZone'] as String?,
      totalDeliveriesCompleted:
          (json['totalDeliveriesCompleted'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      lastDeliveryDate: json['lastDeliveryDate'] != null
          ? DateTime.tryParse(json['lastDeliveryDate'] as String)
          : null,
      recentDeliveries: (json['recentDeliveries'] as List<dynamic>?)
              ?.map((orderJson) => AdminOrderSummaryModel.fromJson(
                  orderJson as Map<String, dynamic>))
              .toList() ??
          [],
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
      if (vehicleType != null) 'vehicleType': vehicleType,
      if (licensePlate != null) 'licensePlate': licensePlate,
      if (serviceZone != null) 'serviceZone': serviceZone,
      'totalDeliveriesCompleted': totalDeliveriesCompleted,
      'averageRating': averageRating,
      'totalEarnings': totalEarnings,
      if (lastDeliveryDate != null)
        'lastDeliveryDate': lastDeliveryDate!.toIso8601String(),
      'recentDeliveries':
          recentDeliveries.map((order) => order.toJson()).toList(),
    };
  }

  String get formattedRegistrationDate =>
      DateFormat('dd MMM yyyy, hh:mm a').format(registrationDate.toLocal());
  String get initials => name.isNotEmpty
      ? name.trim().split(' ').map((l) => l[0]).take(2).join().toUpperCase()
      : '?';
}
