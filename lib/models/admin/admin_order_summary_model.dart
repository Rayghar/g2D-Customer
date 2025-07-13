// lib/models/admin/admin_order_summary_model.dart

import 'package:intl/intl.dart';

class OrderParticipant {
  final String id;
  final String name;

  OrderParticipant({required this.id, required this.name});

  factory OrderParticipant.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OrderParticipant(id: '', name: 'N/A');
    return OrderParticipant(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? 'N/A',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class AdminOrderSummaryModel {
  final String id;
  final DateTime orderDate;
  final String status;
  final double totalAmount;
  final OrderParticipant customer;
  final OrderParticipant? driver;
  final String deliveryAddressSnippet;
  final int itemCount;
  final String itemsPreview;
  final bool isExpressDelivery;
  final String paymentStatus;
  // FIX: Added the missing cancellationReason property to align with its usage elsewhere.
  final String? cancellationReason;

  AdminOrderSummaryModel({
    required this.id,
    required this.orderDate,
    required this.status,
    required this.totalAmount,
    required this.customer,
    this.driver,
    required this.deliveryAddressSnippet,
    required this.itemCount,
    required this.itemsPreview,
    this.isExpressDelivery = false,
    required this.paymentStatus,
    // FIX: Added to the constructor.
    this.cancellationReason,
  });

  factory AdminOrderSummaryModel.fromJson(Map<String, dynamic> json) {
    return AdminOrderSummaryModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? 'N/A',
      orderDate: DateTime.tryParse(json['orderDate'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'Unknown',
      totalAmount: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      customer: OrderParticipant.fromJson(
          json['customer'] as Map<String, dynamic>? ??
              json['customerId'] as Map<String, dynamic>?),
      driver: json['driver'] != null
          ? OrderParticipant.fromJson(json['driver'] as Map<String, dynamic>?)
          : (json['driverId'] != null
              ? OrderParticipant.fromJson(
                  json['driverId'] as Map<String, dynamic>?)
              : null),
      deliveryAddressSnippet:
          json['deliveryAddressSnapshot']?['fullAddress'] as String? ?? 'N/A',
      itemCount: (json['items'] as List<dynamic>?)?.length ?? 0,
      itemsPreview: (json['items'] as List<dynamic>? ?? [])
          .map((item) => item['productName'])
          .join(', '),
      isExpressDelivery: (json['isExpressDelivery'] as bool?) ?? false,
      paymentStatus: json['paymentStatus'] as String? ?? 'Unknown',
      // FIX: Added logic to parse the new field from the JSON.
      cancellationReason: json['cancellationReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderDate': orderDate.toIso8601String(),
      'status': status,
      'grandTotal': totalAmount,
      'customerId': customer.toJson(),
      'driverId': driver?.toJson(),
      'deliveryAddressSnapshot': {'fullAddress': deliveryAddressSnippet},
      'items': [], // This is simplified, real app might need full item list
      'isExpressDelivery': isExpressDelivery,
      'paymentStatus': paymentStatus,
      'cancellationReason': cancellationReason,
    };
  }

  String get formattedOrderDate =>
      DateFormat('dd MMM, hh:mm a').format(orderDate.toLocal());
  String get shortOrderId =>
      id.length > 8 ? '...${id.substring(id.length - 8)}' : id;
}
