// File: lib/models/admin/admin_order_detail_models.dart

import 'package:intl/intl.dart';
import './admin_order_items.dart'; // Assumes it's in the same directory

class AdminCustomerInfo {
  final String id;
  final String name;
  final String? phone;
  final String? email;

  AdminCustomerInfo({
    required this.id,
    required this.name,
    this.phone,
    this.email,
  });

  factory AdminCustomerInfo.fromJson(Map<String, dynamic> json) {
    return AdminCustomerInfo(
      id: json['id'] as String? ?? 'N/A',
      name: json['name'] as String? ?? 'Unknown Customer',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
    };
  }
}

class AdminNoteItem {
  final String note;
  final String? adminId; // The ID of the admin who left the note
  final DateTime timestamp;

  AdminNoteItem({
    required this.note,
    this.adminId,
    required this.timestamp,
  });

  factory AdminNoteItem.fromJson(Map<String, dynamic> json) {
    return AdminNoteItem(
      note: json['note'] as String? ?? '',
      adminId: json['adminId'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String get formattedTimestamp =>
      DateFormat('dd MMM, hh:mm a').format(timestamp.toLocal());
}

class AdminDriverInfo {
  final String id;
  final String name;
  final String? phone;
  final String? vehicleInfo;
  final String? photoUrl;

  AdminDriverInfo({
    required this.id,
    required this.name,
    this.phone,
    this.vehicleInfo,
    this.photoUrl,
  });

  factory AdminDriverInfo.fromJson(Map<String, dynamic> json) {
    return AdminDriverInfo(
      id: json['id'] as String? ?? 'N/A',
      name: json['name'] as String? ?? 'Unassigned',
      phone: json['phone'] as String?,
      vehicleInfo: json['vehicleInfo'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (phone != null) 'phone': phone,
      if (vehicleInfo != null) 'vehicleInfo': vehicleInfo,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
  }
}

class AdminOrderStatusHistoryItem {
  final String status;
  final DateTime timestamp;
  final String? updatedBy;
  final String? notes;

  AdminOrderStatusHistoryItem({
    required this.status,
    required this.timestamp,
    this.updatedBy,
    this.notes,
  });

  factory AdminOrderStatusHistoryItem.fromJson(Map<String, dynamic> json) {
    return AdminOrderStatusHistoryItem(
      status: json['status'] as String? ?? 'Unknown Status',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      updatedBy: json['updatedBy'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (notes != null) 'notes': notes,
    };
  }

  String get formattedTimestamp =>
      DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toLocal());
}

class AdminOrderDetailModel {
  final String id;
  final DateTime orderDate;
  String status;
  AdminCustomerInfo customer;
  AdminDriverInfo? driver;
  final List<AdminOrderItemData> items;
  final String deliveryAddressFull;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final bool isExpressDelivery;
  final double itemsSubtotal;
  final double vatAmount;
  final double serviceFeeAmount;
  final double deliveryFee;
  final double discountAmount;
  final String? promoCodeApplied;
  final double grandTotal;
  final String paymentStatus;
  final String? paymentMethodUsed;
  final String? paymentTransactionId;
  final List<AdminOrderStatusHistoryItem> statusHistory;
  final List adminNotes;

  AdminOrderDetailModel({
    required this.id,
    required this.orderDate,
    required this.status,
    required this.customer,
    this.driver,
    required this.items,
    required this.deliveryAddressFull,
    this.deliveryLatitude,
    this.deliveryLongitude,
    required this.isExpressDelivery,
    required this.itemsSubtotal,
    required this.vatAmount,
    required this.serviceFeeAmount,
    required this.deliveryFee,
    required this.discountAmount,
    this.promoCodeApplied,
    required this.grandTotal,
    required this.paymentStatus,
    this.paymentMethodUsed,
    this.paymentTransactionId,
    List<AdminOrderStatusHistoryItem>? statusHistory,
    this.adminNotes = const [],
  }) : statusHistory = statusHistory ?? [];

  factory AdminOrderDetailModel.fromJson(Map<String, dynamic> json) {
    return AdminOrderDetailModel(
      id: json['id'] as String? ?? 'N/A',
      orderDate: DateTime.tryParse(json['orderDate'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'Unknown',
      customer: AdminCustomerInfo.fromJson(
          json['customerId'] as Map<String, dynamic>? ?? {}),
      driver: json['driverId'] != null
          ? AdminDriverInfo.fromJson(json['driverId'] as Map<String, dynamic>)
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((itemJson) =>
                  AdminOrderItemData.fromJson(itemJson as Map<String, dynamic>))
              .toList() ??
          [],
      deliveryAddressFull:
          json['deliveryAddressSnapshot']?['fullAddress'] as String? ?? 'N/A',
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
      isExpressDelivery: (json['isExpressDelivery'] as bool?) ?? false,
      itemsSubtotal: (json['itemsSubtotal'] as num?)?.toDouble() ?? 0.0,
      vatAmount: (json['vatAmount'] as num?)?.toDouble() ?? 0.0,
      serviceFeeAmount: (json['serviceFeeAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      promoCodeApplied: json['promoCodeApplied'] as String?,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['paymentStatus'] as String? ?? 'Unknown',
      paymentMethodUsed: json['paymentMethodUsed'] as String?,
      paymentTransactionId: json['paymentTransactionId'] as String?,
      statusHistory: (json['statusHistory'] as List<dynamic>?)
              ?.map((historyJson) => AdminOrderStatusHistoryItem.fromJson(
                  historyJson as Map<String, dynamic>))
              .toList() ??
          [],
      adminNotes: (json['adminNotes'] as List<dynamic>? ?? [])
          .map((item) => AdminNoteItem.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderDate': orderDate.toIso8601String(),
      'status': status,
      'customer': customer.toJson(),
      if (driver != null) 'driver': driver!.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'deliveryAddressFull': deliveryAddressFull,
      if (deliveryLatitude != null) 'deliveryLatitude': deliveryLatitude,
      if (deliveryLongitude != null) 'deliveryLongitude': deliveryLongitude,
      'isExpressDelivery': isExpressDelivery,
      'itemsSubtotal': itemsSubtotal,
      'vatAmount': vatAmount,
      'serviceFeeAmount': serviceFeeAmount,
      'deliveryFee': deliveryFee,
      'discountAmount': discountAmount,
      if (promoCodeApplied != null) 'promoCodeApplied': promoCodeApplied,
      'grandTotal': grandTotal,
      'paymentStatus': paymentStatus,
      if (paymentMethodUsed != null) 'paymentMethodUsed': paymentMethodUsed,
      if (paymentTransactionId != null)
        'paymentTransactionId': paymentTransactionId,
      'statusHistory':
          statusHistory.map((history) => history.toJson()).toList(),
      if (adminNotes != null) 'adminNotes': adminNotes,
    };
  }

  String get formattedOrderDate =>
      DateFormat('dd MMM yyyy, hh:mm a').format(orderDate.toLocal());
  String get shortOrderId => id.length > 6 ? id.substring(id.length - 6) : id;
}

// Model for AvailableDriverForAssignment (used in AdminOrderDetailsScreen)
class AvailableDriverForAssignment {
  final String id;
  final String name;
  final String? currentZone;
  final int? activeLoad; // e.g., number of current orders or capacity used

  AvailableDriverForAssignment({
    required this.id,
    required this.name,
    this.currentZone,
    this.activeLoad,
  });

  factory AvailableDriverForAssignment.fromJson(Map<String, dynamic> json) {
    return AvailableDriverForAssignment(
      id: json['id'] as String? ?? 'N/A',
      name: json['name'] as String? ?? 'Unknown Driver',
      currentZone: json['currentZone'] as String?,
      activeLoad: (json['activeLoad'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (currentZone != null) 'currentZone': currentZone,
      if (activeLoad != null) 'activeLoad': activeLoad,
    };
  }
}
