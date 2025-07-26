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

  factory CustomerStatsModel.fromJson(Map<String, dynamic> json) {
    return CustomerStatsModel(
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      totalGasKg: (json['totalGasKg'] as num?)?.toDouble() ?? 0.0,
      averageDaysBetweenOrders:
          (json['averageDaysBetweenOrders'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
