// File: lib/models/notification_preferences_model.dart

import 'package:flutter/material.dart'; // For @required or other Flutter annotations if used

class NotificationPreferencesModel {
  final bool orderUpdates;
  final bool promotions;

  NotificationPreferencesModel({
    required this.orderUpdates,
    required this.promotions,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      orderUpdates: json['orderUpdates'] as bool? ??
          true, // Default to true if not specified
      promotions: json['promotions'] as bool? ??
          true, // Default to true if not specified
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderUpdates': orderUpdates,
      'promotions': promotions,
    };
  }
}
