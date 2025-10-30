// File: lib/models/notification_model.dart

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  // Optional fields that might be useful for notifications
  final String? type; // e.g., 'order_update', 'promotion', 'system_alert'
  final Map<String, dynamic>? data; // For navigation or payload
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.type,
    this.data,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    try {
      return NotificationModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Notification',
        body: json['body'] as String? ?? '',
        timestamp: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        type: json['type'] as String? ?? 'SYSTEM_ALERT',
        data: json['data'] != null
            ? Map<String, dynamic>.from(json['data'] as Map)
            : null,
        isRead: (json['isRead'] as bool?) ?? false,
      );
    } catch (e) {
      print('Error parsing NotificationModel from JSON: $e\nJSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      if (type != null) 'type': type,
      if (data != null) 'data': data,
      'isRead': isRead,
    };
  }
}
