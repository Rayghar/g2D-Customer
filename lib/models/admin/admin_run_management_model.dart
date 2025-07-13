// lib/models/admin/admin_run_management_model.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:primejet_mobile/models/admin/admin_driver_summary_model.dart';
import 'package:primejet_mobile/models/admin/admin_order_summary_model.dart';

// --- NESTED AND SHARED MODELS ---

class RunDriverInfo {
  final String id;
  final String name;
  final LatLng? currentLocation;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleLicensePlate;

  RunDriverInfo({
    required this.id,
    required this.name,
    this.currentLocation,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleLicensePlate,
  });

  factory RunDriverInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return RunDriverInfo(id: '', name: 'Unknown Driver');

    final locationData = json['currentLocation'] as Map<String, dynamic>?;
    final coordinates = locationData?['coordinates'] as List<dynamic>?;

    // Defensive check for driver details
    final driverData = json['driverInfo'] as Map<String, dynamic>? ?? json;

    return RunDriverInfo(
      id: driverData['_id'] as String? ?? driverData['id'] as String? ?? '',
      name: driverData['name'] as String? ?? 'Unknown Driver',
      currentLocation: (coordinates != null && coordinates.length == 2)
          ? LatLng((coordinates[1] as num).toDouble(),
              (coordinates[0] as num).toDouble())
          : null,
      vehicleMake: driverData['vehicleMake'] as String?,
      vehicleModel: driverData['vehicleModel'] as String?,
      vehicleLicensePlate: driverData['vehicleLicensePlate'] as String?,
    );
  }
}

class AdminOptimizedStopInfo {
  final String stopId;
  final String orderId;
  final int sequence;
  final String status;
  final String recipientName;
  final String? recipientPhone;
  final String customerId;
  final String fullAddress;
  final String addressSnippet;
  final LatLng deliveryLocation;
  final String itemsPreview;
  final DateTime? estimatedPickupTime;

  AdminOptimizedStopInfo({
    required this.stopId,
    required this.orderId,
    required this.sequence,
    required this.status,
    required this.recipientName,
    this.recipientPhone,
    required this.customerId,
    required this.fullAddress,
    required this.addressSnippet,
    required this.deliveryLocation,
    required this.itemsPreview,
    this.estimatedPickupTime,
  });

  // --- UPDATED FACTORY WITH DEFENSIVE PATTERN ---
  factory AdminOptimizedStopInfo.fromJson(Map<String, dynamic> json) {
    final dynamic orderData = json['orderId'];

    // Initialize variables with safe fallbacks
    String orderIdString = '';
    String recipientNameString = 'N/A';
    String customerIdString = '';
    String itemsPreviewString = 'N/A';

    // Check if the backend sent a populated order object
    if (orderData is Map<String, dynamic>) {
      // Safely extract data from the nested order object
      orderIdString = orderData['id'] as String? ?? '';
      recipientNameString = orderData['recipientName'] as String? ?? 'N/A';
      customerIdString = orderData['customerId'] as String? ?? '';

      // Process the 'items' array to build the preview string
      if (orderData['items'] != null && orderData['items'] is List) {
        final List<dynamic> itemsList = orderData['items'] as List<dynamic>;
        if (itemsList.isNotEmpty) {
          itemsPreviewString = itemsList.map((item) {
            final itemName = item['productName'] as String? ?? 'Item';
            final quantity = item['quantity'] as int? ?? 0;
            return "$quantity x ${itemName.replaceAll('Cylinder', '').trim()}";
          }).join(', ');
        }
      }
    } else if (orderData is String) {
      // Handle the case where orderId is just a string
      orderIdString = orderData;
    }

    // These fields are properties of the "stop" itself, not the nested order
    final locationData = json['deliveryLocation'] as Map<String, dynamic>?;
    final coordinates = locationData?['coordinates'] as List<dynamic>?;

    return AdminOptimizedStopInfo(
      stopId: json['_id'] as String? ?? json['stopId'] as String? ?? '',
      sequence: json['sequence'] as int? ?? 0,
      status: json['status'] as String? ?? 'Pending',
      recipientPhone: json['recipientPhone'] as String?,
      fullAddress: json['fullAddress'] as String? ?? 'N/A',
      addressSnippet: json['addressSnippet'] as String? ?? 'N/A',
      estimatedPickupTime: json['estimatedPickupTime'] != null
          ? DateTime.tryParse(json['estimatedPickupTime'])
          : null,
      deliveryLocation: (coordinates != null && coordinates.length == 2)
          ? LatLng((coordinates[1] as num).toDouble(),
              (coordinates[0] as num).toDouble())
          : const LatLng(0.0, 0.0),
      // Use the safely parsed variables
      orderId: orderIdString,
      recipientName: recipientNameString,
      customerId: customerIdString,
      itemsPreview: itemsPreviewString,
    );
  }
}

// --- MODELS FOR THE ADMIN RUN MANAGEMENT SCREEN ---

class AdminPickupBatchSummary {
  final String id;
  final int orderCount;
  final String zoneDescription;
  final double estimatedTimeMinutes;
  final double totalWeightKg;
  final List<String> orderIds;

  AdminPickupBatchSummary({
    required this.id,
    required this.orderCount,
    required this.zoneDescription,
    required this.estimatedTimeMinutes,
    required this.totalWeightKg,
    required this.orderIds,
  });

  factory AdminPickupBatchSummary.fromJson(Map<String, dynamic> json) {
    return AdminPickupBatchSummary(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      orderCount: json['orderCount'] as int? ?? 0,
      zoneDescription: json['zoneDescription'] as String? ?? 'Unknown Zone',
      estimatedTimeMinutes:
          (json['estimatedTimeMinutes'] as num?)?.toDouble() ?? 0.0,
      totalWeightKg: (json['totalWeightKg'] as num?)?.toDouble() ?? 0.0,
      orderIds: List<String>.from(json['orderIds'] ?? []),
    );
  }
}

class AdminUnassignedOrder {
  final String orderId;
  final String customerName;
  final String addressSnippet;
  final String cylinderDetails;
  final DateTime orderPlacedTime;
  final String? reasonUnassigned;

  AdminUnassignedOrder({
    required this.orderId,
    required this.customerName,
    required this.addressSnippet,
    required this.cylinderDetails,
    required this.orderPlacedTime,
    this.reasonUnassigned,
  });

  factory AdminUnassignedOrder.fromOrderSummary(
      AdminOrderSummaryModel summary) {
    return AdminUnassignedOrder(
      orderId: summary.id,
      customerName: summary.customer.name,
      addressSnippet: summary.deliveryAddressSnippet,
      cylinderDetails: summary.itemsPreview,
      orderPlacedTime: summary.orderDate,
      reasonUnassigned: summary.cancellationReason,
    );
  }
}

class AvailableDriverForMap {
  final String id;
  final String name;
  final int currentLoadKg;
  final bool isAvailableOnline;

  AvailableDriverForMap({
    required this.id,
    required this.name,
    this.currentLoadKg = 0,
    this.isAvailableOnline = false,
  });

  factory AvailableDriverForMap.fromJson(Map<String, dynamic> json) {
    return AvailableDriverForMap(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Driver',
      currentLoadKg: json['currentLoadKg'] as int? ?? 0,
      isAvailableOnline: json['isAvailableOnline'] as bool? ?? false,
    );
  }

  factory AvailableDriverForMap.fromDriverSummary(
      AdminDriverSummaryModel summary) {
    return AvailableDriverForMap(
      id: summary.id,
      name: summary.name,
      currentLoadKg: 0,
      isAvailableOnline: summary.isAvailableOnline,
    );
  }
}

class AdminActiveRunInfo {
  final String runId;
  final RunDriverInfo driverInfo;
  final int totalStops;
  final int completedStops;
  final String currentStatusSummary;
  final DateTime startTime;

  AdminActiveRunInfo({
    required this.runId,
    required this.driverInfo,
    required this.totalStops,
    required this.completedStops,
    required this.currentStatusSummary,
    required this.startTime,
  });

  factory AdminActiveRunInfo.fromJson(Map<String, dynamic> json) {
    return AdminActiveRunInfo(
      runId: json['id'] as String? ?? json['runId'] as String? ?? '',
      driverInfo:
          RunDriverInfo.fromJson(json['driverInfo'] as Map<String, dynamic>?),
      totalStops: json['totalStops'] as int? ?? 0,
      completedStops: json['completedStops'] as int? ?? 0,
      currentStatusSummary:
          json['currentStatusSummary'] as String? ?? 'Unknown',
      startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AdminActiveRunDetailModel {
  final String runId;
  final RunDriverInfo driverInfo;
  final String overallStatus;
  final int totalStops;
  final int completedStops;
  final List<AdminOptimizedStopInfo> sequencedStops;
  final String? routePolyline;
  final DateTime? estimatedCompletionTime;

  AdminActiveRunDetailModel({
    required this.runId,
    required this.driverInfo,
    required this.overallStatus,
    required this.totalStops,
    required this.completedStops,
    required this.sequencedStops,
    this.routePolyline,
    this.estimatedCompletionTime,
  });

  factory AdminActiveRunDetailModel.fromJson(Map<String, dynamic> json) {
    var stopsList = <AdminOptimizedStopInfo>[];
    // Handle both 'sequencedStops' and 'stops' as possible keys from the backend for safety
    final stopsData = json['sequencedStops'] ?? json['stops'];
    if (stopsData != null && stopsData is List) {
      stopsList = stopsData
          .map((stopJson) => AdminOptimizedStopInfo.fromJson(stopJson))
          .toList();
    }

    return AdminActiveRunDetailModel(
      runId: json['_id'] as String? ?? json['runId'] as String? ?? '',
      driverInfo:
          RunDriverInfo.fromJson(json['driverInfo'] as Map<String, dynamic>?),
      overallStatus: json['overallStatus'] as String? ?? 'Unknown',
      totalStops: json['totalStops'] as int? ?? 0,
      completedStops: json['completedStops'] as int? ?? 0,
      sequencedStops: stopsList,
      routePolyline: json['routePolyline'] as String?,
      estimatedCompletionTime: json['estimatedCompletionTime'] != null
          ? DateTime.tryParse(json['estimatedCompletionTime'])
          : null,
    );
  }
}
