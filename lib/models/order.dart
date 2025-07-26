// lib/models/order.dart
// ADVISORY: A new helper getter has been added to OrderItemModel to resolve the error.

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'user.dart' as app_user;
import 'driver_info_for_order.dart';
import 'feedback.dart'; // Ensure feedback model is imported

var _uuid = const Uuid();

class OrderItemModel {
  final String cylinderId;
  final String productName;
  final int quantity;
  final double unitPrice;

  OrderItemModel({
    required this.cylinderId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  String? get cylinderSizeKG {
    final RegExp regex = RegExp(r'(\d+(\.\d+)?)\s*kg', caseSensitive: false);
    final match = regex.firstMatch(productName);
    return match?.group(0);
  }

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      cylinderId:
          json['cylinderId'] as String? ?? json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? 'Unknown Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DeliveryAddressSnapshotModel {
  final String fullAddress;
  final String street;
  final String city;
  final String state;
  final String country;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? deliveryInstructions;

  DeliveryAddressSnapshotModel({
    required this.fullAddress,
    required this.street,
    required this.city,
    required this.state,
    required this.country,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.deliveryInstructions,
  });

  factory DeliveryAddressSnapshotModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return DeliveryAddressSnapshotModel(
        fullAddress: 'N/A',
        street: 'N/A',
        city: 'N/A',
        state: 'N/A',
        country: 'N/A',
      );
    }
    return DeliveryAddressSnapshotModel(
      fullAddress: json['fullAddress'] as String? ?? '',
      street: json['street'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      country: json['country'] as String? ?? '',
      postalCode: json['postalCode'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      deliveryInstructions: json['deliveryInstructions'] as String?,
    );
  }
}

class Order {
  final String id;
  final app_user.User? customer;
  final DriverInfoForOrder? driver;
  final List<OrderItemModel> items;
  final DeliveryAddressSnapshotModel deliveryAddressSnapshot;
  final DateTime orderDate;
  String status;
  final String paymentStatus;
  final double itemsSubtotal;
  final double discountAmount;
  final String? promoCodeApplied;
  final double vatAmount;
  final double serviceFeeAmount;
  final double deliveryFee;
  final double walletAmountUsed;
  final double grandTotal;
  final double finalAmountPaid;
  final bool isExpressDelivery;
  final Feedback? feedback;
  final String recipientName;
  final String? recipientPhone;

  Order({
    required this.id,
    this.customer,
    this.driver,
    required this.items,
    required this.deliveryAddressSnapshot,
    required this.orderDate,
    required this.status,
    required this.paymentStatus,
    required this.itemsSubtotal,
    required this.discountAmount,
    this.promoCodeApplied,
    required this.vatAmount,
    required this.serviceFeeAmount,
    required this.deliveryFee,
    required this.walletAmountUsed,
    required this.grandTotal,
    required this.finalAmountPaid,
    required this.isExpressDelivery,
    this.feedback,
    required this.recipientName,
    this.recipientPhone,
  });

  String get shortOrderId {
    if (id.contains('-')) {
      return id.substring(id.lastIndexOf('-') + 1).toUpperCase();
    }
    if (id.contains('_')) {
      return id.substring(id.lastIndexOf('_') + 1).toUpperCase();
    }
    return id.length > 7
        ? "...${id.substring(id.length - 7).toUpperCase()}"
        : id.toUpperCase();
  }

  String get formattedOrderDate =>
      DateFormat('MMM dd, yyyy - hh:mm a').format(orderDate.toLocal());

  String get itemsPreview {
    if (items.isEmpty) return 'No items';
    final preview = items
        .map((item) =>
            "${item.quantity}x ${item.productName.replaceAll('Cylinder', '').trim()}")
        .join(', ');
    if (preview.length > 40) return "${preview.substring(0, 37)}...";
    return preview;
  }

  // FIX: Add the formattedStatus getter
  String get formattedStatus {
    switch (status) {
      case 'Pending Payment':
        return 'Pending Payment';
      case 'Order Placed':
        return 'Order Placed';
      case 'Processing':
        return 'Processing';
      case 'Driver Assigned':
        return 'Driver Assigned';
      case 'Out for delivery': // Matches the backend enum string
        return 'Out for Delivery'; // Display format
      case 'Delivered':
        return 'Delivered';
      case 'Customer Unavailable':
        return 'Customer Unavailable';
      case 'Issue Reported':
        return 'Issue Reported';
      case 'Payment Failed':
        return 'Payment Failed';
      case 'Payment Discrepancy':
        return 'Payment Discrepancy';
      case 'Refunded':
        return 'Refunded';
      case 'Partially Refunded':
        return 'Partially Refunded';
      case 'Canceled by Customer':
        return 'Canceled by Customer';
      case 'Canceled by Admin':
        return 'Canceled by Admin';
      default:
        // Fallback for any unexpected status
        return status.replaceAll('_', ' ').toTitleCase();
    }
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String? ?? _uuid.v4(),
      customer:
          json['customer'] != null && json['customer'] is Map<String, dynamic>
              ? app_user.User.fromJson(json['customer'] as Map<String, dynamic>)
              : null,
      driver: json['driver'] != null && json['driver'] is Map<String, dynamic>
          ? DriverInfoForOrder.fromJson(json['driver'] as Map<String, dynamic>)
          : null,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      deliveryAddressSnapshot: DeliveryAddressSnapshotModel.fromJson(
          json['deliveryAddressSnapshot'] as Map<String, dynamic>?),
      orderDate: DateTime.tryParse(json['orderDate'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'Unknown',
      paymentStatus: json['paymentStatus'] as String? ?? 'Unknown',
      itemsSubtotal: (json['itemsSubtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      promoCodeApplied: json['promoCodeApplied'] as String?,
      vatAmount: (json['vatAmount'] as num?)?.toDouble() ?? 0.0,
      serviceFeeAmount: (json['serviceFeeAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      walletAmountUsed: (json['walletAmountUsed'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      finalAmountPaid: (json['finalAmountPaid'] as num?)?.toDouble() ?? 0.0,
      isExpressDelivery: (json['isExpressDelivery'] as bool?) ?? false,
      feedback:
          json['feedback'] != null && json['feedback'] is Map<String, dynamic>
              ? Feedback.fromJson(json['feedback'] as Map<String, dynamic>)
              : null,
      recipientName: json['recipientName'] as String? ?? 'N/A',
      recipientPhone: json['recipientPhone'] as String?,
    );
  }
}

// Helper extension for String toTitleCase
extension StringCasingExtension on String {
  String toTitleCase() => replaceAll(RegExp(' +'), ' ')
      .split(' ')
      .map((str) => str.isNotEmpty
          ? '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}'
          : '')
      .join(' ');
}
