// File: lib/models/admin/admin_customer_summary_model.dart

import 'package:intl/intl.dart';

class AdminCustomerSummaryModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime registrationDate;
  final bool isActive;
  final int totalOrders;
  final String? photoUrl; // Optional

  AdminCustomerSummaryModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.registrationDate,
    this.isActive = true,
    this.totalOrders = 0,
    this.photoUrl,
  });

  factory AdminCustomerSummaryModel.fromJson(Map<String, dynamic> json) {
    return AdminCustomerSummaryModel(
      id: json['id'] as String? ?? 'N/A',
      name: json['name'] as String? ?? 'Unknown Customer',
      email: json['email'] as String? ?? 'N/A',
      phone: json['phone'] as String? ?? 'N/A',
      registrationDate:
          DateTime.tryParse(json['registrationDate'] as String? ?? '') ??
              DateTime.now(),
      isActive: (json['isActive'] as bool?) ?? true,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'registrationDate': registrationDate.toIso8601String(),
      'isActive': isActive,
      'totalOrders': totalOrders,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
  }

  String get formattedRegistrationDate =>
      DateFormat('dd MMM yyyy').format(registrationDate.toLocal());
}
