// File: lib/models/place_order_response_model.dart

import './order.dart' as app_order;

class PlaceOrderResponseModel {
  final app_order.Order order;
  final bool paymentNeeded;
  final double grandTotalToPay;
  final String message;
  // final String? accessCode; // REMOVED: accessCode is specific to Paystack, not used by OPay direct SDK

  PlaceOrderResponseModel({
    required this.order,
    required this.paymentNeeded,
    required this.grandTotalToPay,
    required this.message,
    // this.accessCode, // REMOVED from constructor
  });

  factory PlaceOrderResponseModel.fromJson(Map<String, dynamic> json) {
    // The 'order' object can come from different keys depending on the endpoint.
    // This factory handles both 'order' and a root-level response.
    final orderData =
        json['order'] != null ? json['order'] as Map<String, dynamic> : json;

    return PlaceOrderResponseModel(
      order: app_order.Order.fromJson(orderData),
      paymentNeeded: json['paymentNeeded'] as bool? ?? false,
      grandTotalToPay: (json['grandTotalToPay'] as num? ?? 0).toDouble(),
      message: json['message'] as String? ?? '',
      // accessCode: json['accessCode'] as String?, // REMOVED: No longer parsed for OPay
    );
  }
}
