// File: lib/models/payment_method_model.dart
class PaymentMethodModel {
  final String id;
  final String gateway;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;
  final bool isDefault;

  PaymentMethodModel({
    required this.id,
    required this.gateway,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
    required this.isDefault,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] ?? '',
      gateway: json['gateway'] ?? 'stripe',
      brand: json['brand'] as String?,
      last4: json['last4'] as String?,
      expMonth: json['expMonth'] as int?,
      expYear: json['expYear'] as int?,
      isDefault: json['isDefault'] ?? false,
    );
  }

  String get expiryDate {
    if (expMonth != null && expYear != null) {
      return '${expMonth.toString().padLeft(2, '0')}/${expYear.toString().substring(2)}';
    }
    return 'N/A';
  }
}
