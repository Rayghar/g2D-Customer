// lib/utils/app_constants.dart
import 'package:flutter/material.dart';

/// Contains durations used for animations throughout the app.
class AppDurations {
  static const screenEntryAnimation = Duration(milliseconds: 700);
  static const carouselAnimation = Duration(milliseconds: 700);
}

/// Stores constants related to the API, such as fixed query parameters.
class ApiConstants {
  static const activeOrderStatuses =
      'Pending Payment,Order Placed,Processing,Driver Assigned,Out for delivery,Driver enroute to pickup,Driver enroute to gas station,Cylinder Refilling';
}

/// Holds user-facing strings. In a larger app, this would be replaced by a full localization (i18n) solution.
class AppStrings {
  static const newOrder = 'New Order';
  static const myOrders = 'My Orders';
  static const trackActiveOrder = 'Track Active Order';
  static const orderHistory = 'Order History';
  static const viewAll = 'View All';
  static const dontMissThese = 'Don\'t Miss These!';
  static const deliveringTo = 'Delivering to:';
  static const tapToSelectAddress = 'Tap to select address';
  static const failedToLoadData = 'Failed to load data. Please try again.';
  static const retry = 'Retry';
}
