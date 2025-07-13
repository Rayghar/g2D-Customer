// File: lib/models/admin/admin_customer_detail_model.dart

import 'package:intl/intl.dart';
import './admin_order_summary_model.dart'; // For recent orders
import '../address_model.dart'; // Assuming a shared AddressModel

class AdminCustomerDetailModel {
  final String id;
  String name;
  String email;
  String phone;
  final DateTime registrationDate;
  String accountStatus; // e.g., "Active", "Suspended", "Pending Verification"
  final String? photoUrl;
  final List<AddressModel> addresses; // List of customer's addresses
  final AddressModel? defaultAddress;
  final int totalOrders;
  final double totalSpent;
  final DateTime? lastOrderDate;
  final List<AdminOrderSummaryModel>
      recentOrders; // Using the admin summary model

  AdminCustomerDetailModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.registrationDate,
    required this.accountStatus,
    this.photoUrl,
    this.addresses = const [],
    this.defaultAddress,
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    this.lastOrderDate,
    this.recentOrders = const [],
  });

  factory AdminCustomerDetailModel.fromJson(Map<String, dynamic> json) {
    return AdminCustomerDetailModel(
      id: json['id'] as String? ?? 'N/A',
      name: json['name'] as String? ?? 'Unknown Customer',
      email: json['email'] as String? ?? 'N/A',
      phone: json['phone'] as String? ?? 'N/A',
      registrationDate:
          DateTime.tryParse(json['registrationDate'] as String? ?? '') ??
              DateTime.now(),
      accountStatus: json['accountStatus'] as String? ?? 'Unknown',
      photoUrl: json['photoUrl'] as String?,
      addresses: (json['addresses'] as List<dynamic>?)
              ?.map((addrJson) =>
                  AddressModel.fromJson(addrJson as Map<String, dynamic>))
              .toList() ??
          [],
      defaultAddress: json['defaultAddress'] != null
          ? AddressModel.fromJson(
              json['defaultAddress'] as Map<String, dynamic>)
          : null,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      lastOrderDate: json['lastOrderDate'] != null
          ? DateTime.tryParse(json['lastOrderDate'] as String)
          : null,
      recentOrders: (json['recentOrders'] as List<dynamic>?)
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
      if (photoUrl != null) 'photoUrl': photoUrl,
      'addresses': addresses.map((addr) => addr.toJson()).toList(),
      if (defaultAddress != null) 'defaultAddress': defaultAddress!.toJson(),
      'totalOrders': totalOrders,
      'totalSpent': totalSpent,
      if (lastOrderDate != null)
        'lastOrderDate': lastOrderDate!.toIso8601String(),
      'recentOrders': recentOrders.map((order) => order.toJson()).toList(),
    };
  }

  String get formattedRegistrationDate =>
      DateFormat('dd MMM yyyy, hh:mm a').format(registrationDate.toLocal());
  String get initials => name.isNotEmpty
      ? name.trim().split(' ').map((l) => l[0]).take(2).join().toUpperCase()
      : '?';
}
