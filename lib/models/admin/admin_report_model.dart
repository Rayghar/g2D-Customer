// File: lib/models/admin/admin_report_models.dart

import 'package:intl/intl.dart';

// --- Sales Overview ---
class DailyRevenue {
  final DateTime date;
  final double revenue;

  DailyRevenue({required this.date, required this.revenue});

  factory DailyRevenue.fromJson(Map<String, dynamic> json) {
    return DailyRevenue(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'revenue': revenue,
    };
  }
}

class SalesOverviewStats {
  final double totalRevenue;
  final int totalOrders;
  final double averageOrderValue;
  final List<DailyRevenue> revenueTrend; // For charts

  SalesOverviewStats({
    this.totalRevenue = 0.0,
    this.totalOrders = 0,
    this.averageOrderValue = 0.0,
    this.revenueTrend = const [],
  });

  factory SalesOverviewStats.fromJson(Map<String, dynamic> json) {
    return SalesOverviewStats(
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      averageOrderValue: (json['averageOrderValue'] as num?)?.toDouble() ?? 0.0,
      revenueTrend: (json['revenueTrend'] as List<dynamic>?)
              ?.map(
                  (item) => DailyRevenue.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'averageOrderValue': averageOrderValue,
      'revenueTrend': revenueTrend.map((item) => item.toJson()).toList(),
    };
  }
}

// --- Order Report ---
class HourlyOrders {
  // For peak times chart
  final int hour; // 0-23
  final int orderCount;

  HourlyOrders({required this.hour, required this.orderCount});

  factory HourlyOrders.fromJson(Map<String, dynamic> json) {
    return HourlyOrders(
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'orderCount': orderCount,
    };
  }
}

class OrderReportStats {
  final Map<String, int>
      ordersByStatus; // e.g., {"Pending": 10, "Delivered": 50}
  final Map<String, int> popularCylinders; // e.g., {"12.5 KG": 100, "6 KG": 50}
  final List<HourlyOrders> peakTimes; // For chart

  OrderReportStats({
    this.ordersByStatus = const {},
    this.popularCylinders = const {},
    this.peakTimes = const [],
  });

  factory OrderReportStats.fromJson(Map<String, dynamic> json) {
    return OrderReportStats(
      ordersByStatus:
          Map<String, int>.from(json['ordersByStatus'] as Map? ?? {}),
      popularCylinders:
          Map<String, int>.from(json['popularCylinders'] as Map? ?? {}),
      peakTimes: (json['peakTimes'] as List<dynamic>?)
              ?.map(
                  (item) => HourlyOrders.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'ordersByStatus': ordersByStatus,
      'popularCylinders': popularCylinders,
      'peakTimes': peakTimes.map((item) => item.toJson()).toList(),
    };
  }
}

// --- Customer Report ---
class TopCustomer {
  final String customerId;
  final String name;
  final int orderCount;
  final double totalSpent;

  TopCustomer(
      {required this.customerId,
      required this.name,
      required this.orderCount,
      required this.totalSpent});

  factory TopCustomer.fromJson(Map<String, dynamic> json) {
    return TopCustomer(
      customerId: json['customerId'] as String? ?? 'N/A',
      name: json['name'] as String? ?? 'Unknown',
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'name': name,
      'orderCount': orderCount,
      'totalSpent': totalSpent,
    };
  }
}

class CustomerReportStats {
  final int newRegistrations;
  final int totalActiveCustomers;
  final List<TopCustomer> topCustomers; // Top 5 for example

  CustomerReportStats({
    this.newRegistrations = 0,
    this.totalActiveCustomers = 0,
    this.topCustomers = const [],
  });

  factory CustomerReportStats.fromJson(Map<String, dynamic> json) {
    return CustomerReportStats(
      newRegistrations: (json['newRegistrations'] as num?)?.toInt() ?? 0,
      totalActiveCustomers:
          (json['totalActiveCustomers'] as num?)?.toInt() ?? 0,
      topCustomers: (json['topCustomers'] as List<dynamic>?)
              ?.map(
                  (item) => TopCustomer.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'newRegistrations': newRegistrations,
      'totalActiveCustomers': totalActiveCustomers,
      'topCustomers': topCustomers.map((item) => item.toJson()).toList(),
    };
  }
}

// --- Driver Report ---
class TopDriver {
  final String driverId;
  final String name;
  final int deliveryCount;
  final double averageRating;

  TopDriver(
      {required this.driverId,
      required this.name,
      required this.deliveryCount,
      required this.averageRating});

  factory TopDriver.fromJson(Map<String, dynamic> json) {
    return TopDriver(
      driverId: json['driverId'] as String? ?? 'N/A',
      name: json['name'] as String? ?? 'Unknown',
      deliveryCount: (json['deliveryCount'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'driverId': driverId,
      'name': name,
      'deliveryCount': deliveryCount,
      'averageRating': averageRating,
    };
  }
}

class DriverReportStats {
  final int totalActiveDrivers;
  final double avgDeliveriesPerDriver;
  final double avgDeliveryTimeMinutes; // In minutes
  final List<TopDriver> topDrivers; // Top 5 for example

  DriverReportStats({
    this.totalActiveDrivers = 0,
    this.avgDeliveriesPerDriver = 0.0,
    this.avgDeliveryTimeMinutes = 0.0,
    this.topDrivers = const [],
  });

  factory DriverReportStats.fromJson(Map<String, dynamic> json) {
    return DriverReportStats(
      totalActiveDrivers: (json['totalActiveDrivers'] as num?)?.toInt() ?? 0,
      avgDeliveriesPerDriver:
          (json['avgDeliveriesPerDriver'] as num?)?.toDouble() ?? 0.0,
      avgDeliveryTimeMinutes:
          (json['avgDeliveryTimeMinutes'] as num?)?.toDouble() ?? 0.0,
      topDrivers: (json['topDrivers'] as List<dynamic>?)
              ?.map((item) => TopDriver.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'totalActiveDrivers': totalActiveDrivers,
      'avgDeliveriesPerDriver': avgDeliveriesPerDriver,
      'avgDeliveryTimeMinutes': avgDeliveryTimeMinutes,
      'topDrivers': topDrivers.map((item) => item.toJson()).toList(),
    };
  }
}
