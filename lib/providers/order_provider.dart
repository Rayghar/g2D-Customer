// File: lib/providers/order_provider.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../models/order.dart' as app_order;

class OrderProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // --- STATE VARIABLES ---
  final Map<String, app_order.Order> _orders = {};
  final Map<String, bool> _loadingStates = {};

  // Home Screen State
  app_order.Order? _activeOrder;
  List<app_order.Order> _recentOrders = [];
  bool _isLoadingHomeScreen = true;

  // New state for the Order List Screen
  List<app_order.Order> _orderList = [];
  bool _isLoadingList = true;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;

  // --- GETTERS ---
  Map<String, app_order.Order> get orders => _orders;
  bool isLoading(String orderId) => _loadingStates[orderId] ?? false;

  app_order.Order? get activeOrder => _activeOrder;
  List<app_order.Order> get recentOrders => _recentOrders;
  bool get isLoadingHomeScreen => _isLoadingHomeScreen;

  // New Getters for Order List Screen
  List<app_order.Order> get orderList => _orderList;
  bool get isLoadingList => _isLoadingList;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get isFetchingMore => _isFetchingMore;

  // --- METHODS ---

  // ===== FIX: Add method to handle WebSocket data START =====
  /// Efficiently updates the state with fresh data from a WebSocket event.
  void updateOrderDataFromSocket(Map<String, dynamic> orderData) {
    try {
      final updatedOrder = app_order.Order.fromJson(orderData);

      // Update the main order map, which is used by the OrderDetailsScreen
      _orders[updatedOrder.id] = updatedOrder;

      // Also, update the order if it exists in the home screen lists
      if (_activeOrder?.id == updatedOrder.id) {
        _activeOrder = updatedOrder;
      }
      final recentIndex =
          _recentOrders.indexWhere((o) => o.id == updatedOrder.id);
      if (recentIndex != -1) {
        _recentOrders[recentIndex] = updatedOrder;
      }

      // Notify all listening widgets to rebuild with the new data
      notifyListeners();
    } catch (e) {
      print("Error parsing order data from socket: $e");
    }
  }
  // ===== FIX: Add method to handle WebSocket data END =====

  Future<void> fetchHomeScreenData() async {
    _isLoadingHomeScreen = true;
    notifyListeners();

    try {
      const activeOrderStatuses =
          'Order Placed,Processing,Driver Assigned,Out for Delivery,Awaiting Driver Arrival';

      final results = await Future.wait([
        _apiService.getCustomerOrders(
            limit: 1, status: activeOrderStatuses, sortBy: '-orderDate'),
        _apiService.getCustomerOrders(limit: 3, sortBy: '-orderDate'),
      ]);

      final activeOrderResponse = results[0];
      final recentOrdersResponse = results[1];

      final activeOrders =
          activeOrderResponse['orders'] as List<app_order.Order>? ?? [];
      _activeOrder = activeOrders.isNotEmpty ? activeOrders.first : null;

      _recentOrders =
          recentOrdersResponse['orders'] as List<app_order.Order>? ?? [];
    } catch (e) {
      print("Error fetching home screen data: $e");
    }

    _isLoadingHomeScreen = false;
    notifyListeners();
  }

  // New method for the OrderListScreen, handles both initial load and pagination.
  Future<void> fetchOrderList(
      {bool isRefresh = false, String? statusFilter}) async {
    // If this is a full refresh, reset everything.
    if (isRefresh) {
      _currentPage = 1;
      _orderList = [];
      _isLoadingList = true;
    } else {
      // Otherwise, we are fetching the next page.
      _isFetchingMore = true;
    }
    notifyListeners();

    try {
      final paginatedResponse = await _apiService.getCustomerOrders(
        page: _currentPage,
        limit: 15, // Standard page size for the list
        status: statusFilter,
      );

      final List<app_order.Order> fetchedOrders =
          paginatedResponse['orders'] as List<app_order.Order>;

      if (isRefresh) {
        _orderList = fetchedOrders;
      } else {
        _orderList.addAll(fetchedOrders);
      }

      _totalPages = paginatedResponse['totalPages'] as int? ?? 1;

      // Only increment the page if we are not on the last page
      if (_currentPage < _totalPages) {
        _currentPage++;
      }
    } catch (e) {
      print("Error fetching order list: $e");
    }

    _isLoadingList = false;
    _isFetchingMore = false;
    notifyListeners();
  }

  Future<void> fetchOrderDetails(String orderId) async {
    _loadingStates[orderId] = true;
    notifyListeners();
    try {
      final order = await _apiService.getOrderDetails(orderId);
      _orders[orderId] = order;
    } catch (e) {
      print("Error fetching order $orderId: $e");
    }
    _loadingStates[orderId] = false;
    notifyListeners();
  }

  void updateOrderFromRealtimeEvent(Map<String, dynamic> orderData) {
    final updatedOrder = app_order.Order.fromJson(orderData);

    _orders[updatedOrder.id] = updatedOrder;

    // Update the recent orders list on the home screen
    final indexInRecentList =
        _recentOrders.indexWhere((o) => o.id == updatedOrder.id);
    if (indexInRecentList != -1) {
      _recentOrders[indexInRecentList] = updatedOrder;
    }

    // Update the full order list
    final indexInFullList =
        _orderList.indexWhere((o) => o.id == updatedOrder.id);
    if (indexInFullList != -1) {
      _orderList[indexInFullList] = updatedOrder;
    }

    if (_activeOrder?.id == updatedOrder.id) {
      _activeOrder = updatedOrder;
    }

    print("Real-time event processed. Notifying listeners.");
    notifyListeners();
  }

  // This function allows us to manually inject a new order into the state.
  void addNewlyPlacedOrder(app_order.Order newOrder) {
    // If the new order is an "active" one, set it as the active order.
    if (newOrder.status == 'Awaiting Driver Arrival' ||
        newOrder.status == 'Order Placed') {
      _activeOrder = newOrder;

      // Add the new order to the top of the recent orders list for consistency.
      _recentOrders.insert(0, newOrder);
      if (_recentOrders.length > 3) {
        _recentOrders.removeLast();
      }

      notifyListeners(); // Notify the HomeScreen to rebuild and show the new card.
    }
  }
}
