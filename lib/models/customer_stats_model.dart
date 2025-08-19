// File: lib/models/customer_stats_model.dart

class CustomerStatsModel {
  final int totalOrders;
  final double totalGasKg;
  final double averageDaysBetweenOrders;

  CustomerStatsModel({
    this.totalOrders = 0,
    this.totalGasKg = 0.0,
    this.averageDaysBetweenOrders = 0.0,
  });

  // << MODIFIED: fromJson now handles string-to-double conversion for robustness >>
  factory CustomerStatsModel.fromJson(Map<String, dynamic> json) {
    return CustomerStatsModel(
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      totalGasKg:
          double.tryParse(json['totalGasKg']?.toString() ?? '0.0') ?? 0.0,
      averageDaysBetweenOrders: double.tryParse(
              json['averageDaysBetweenOrders']?.toString() ?? '0.0') ??
          0.0,
    );
  }
}
