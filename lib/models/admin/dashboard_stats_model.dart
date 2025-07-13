// File: lib/models/admin/dashboard_stats_model.dart

class DashboardStatsModel {
  final int totalOrdersToday;
  final int pendingOrders;
  final int activeDeliveries;
  final int registeredCustomers;
  final int activeDrivers;

  DashboardStatsModel({
    this.totalOrdersToday = 0,
    this.pendingOrders = 0,
    this.activeDeliveries = 0,
    this.registeredCustomers = 0,
    this.activeDrivers = 0,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      totalOrdersToday: (json['totalOrdersToday'] as num?)?.toInt() ?? 0,
      pendingOrders: (json['pendingOrders'] as num?)?.toInt() ?? 0,
      activeDeliveries: (json['activeDeliveries'] as num?)?.toInt() ?? 0,
      registeredCustomers: (json['registeredCustomers'] as num?)?.toInt() ?? 0,
      activeDrivers: (json['activeDrivers'] as num?)?.toInt() ?? 0,
    );
  }
}
