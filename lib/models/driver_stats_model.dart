// lib/models/driver_stats_model.dart

import 'package:intl/intl.dart';

class DriverStatsModel {
  final int totalOrdersExecuted;
  final double totalRevenueMade;
  final int totalOrdersCancelled;
  final double averageRating;
  final double acceptanceRate;
  // FIX: This should be an integer for minutes. Changed from double.
  final int averageDeliveryTimeMinutes;

  DriverStatsModel({
    required this.totalOrdersExecuted,
    required this.totalRevenueMade,
    required this.totalOrdersCancelled,
    required this.averageRating,
    required this.acceptanceRate,
    required this.averageDeliveryTimeMinutes,
  });

  factory DriverStatsModel.empty() {
    return DriverStatsModel(
        totalOrdersExecuted: 0,
        totalRevenueMade: 0.0,
        totalOrdersCancelled: 0,
        averageRating: 0.0,
        acceptanceRate: 0.0,
        averageDeliveryTimeMinutes: 0);
  }

  factory DriverStatsModel.fromJson(Map<String, dynamic> json) {
    // FIX: This helper function prevents crashes if a number field is missing or null from the API.
    num safeJsonNum(String key) {
      return json.containsKey(key) && json[key] is num ? json[key] : 0;
    }

    return DriverStatsModel(
      totalOrdersExecuted: safeJsonNum('totalOrdersExecuted').toInt(),
      totalRevenueMade: safeJsonNum('totalRevenueMade').toDouble(),
      totalOrdersCancelled: safeJsonNum('totalOrdersCancelled').toInt(),
      averageRating: safeJsonNum('averageRating').toDouble(),
      acceptanceRate: safeJsonNum('acceptanceRate').toDouble(),
      // FIX: Correctly parse to an integer.
      averageDeliveryTimeMinutes:
          safeJsonNum('averageDeliveryTimeMinutes').toInt(),
    );
  }

  // Formatting helpers for clean UI code
  String get formattedTotalRevenue =>
      "₦${NumberFormat("#,##0").format(totalRevenueMade)}";
  String get formattedAverageRating => "${averageRating.toStringAsFixed(1)} ★";
  String get formattedAcceptanceRate =>
      "${(acceptanceRate * 100).toStringAsFixed(0)}%";
  String get formattedAvgDeliveryTime => "$averageDeliveryTimeMinutes mins";
}
