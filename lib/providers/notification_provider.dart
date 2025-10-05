// File: lib/providers/notification_provider.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  // Fetches the latest count from the backend and updates the UI
  Future<void> fetchUnreadCount() async {
    try {
      final count = await _apiService.getUnreadNotificationCount();
      if (count != _unreadCount) {
        _unreadCount = count;
        notifyListeners(); // This is the crucial step that tells the UI to rebuild
      }
    } catch (e) {
      print('[NotificationProvider] Failed to fetch unread count: $e');
      // Optionally handle the error, but we don't want to crash the app
    }
  }

  // Clears the count locally for instant UI feedback when the user navigates
  // to the notification screen.
  void clearCount() {
    if (_unreadCount > 0) {
      _unreadCount = 0;
      notifyListeners();
    }
  }
}
