// File: lib/models/system_config_model.dart
// << UPDATED FILE WITH LOGGING >>

import 'dart:convert';
import 'package:logging/logging.dart';

final _logger = Logger('SystemConfigModel');

class CylinderSetting {
  final String id;
  final String name;
  final double price;
  final double? weightKg;
  final bool? isActive;

  CylinderSetting({
    required this.id,
    required this.name,
    required this.price,
    this.weightKg,
    this.isActive,
  });

  factory CylinderSetting.fromJson(Map<String, dynamic> json) {
    try {
      return CylinderSetting(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        isActive: json['isActive'] as bool?,
      );
    } catch (e, st) {
      _logger.severe('Error parsing CylinderSetting from JSON: $e', e, st);
      rethrow;
    }
  }
}

class FeeSettings {
  final double vatPercentage;
  final double serviceFeePercentage;
  final double baseDeliveryFee;
  final double expressDeliverySurcharge;

  FeeSettings({
    required this.vatPercentage,
    required this.serviceFeePercentage,
    required this.baseDeliveryFee,
    required this.expressDeliverySurcharge,
  });

  factory FeeSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return FeeSettings(
          vatPercentage: 0.0,
          serviceFeePercentage: 0.0,
          baseDeliveryFee: 0.0,
          expressDeliverySurcharge: 0.0);
    }
    try {
      return FeeSettings(
        vatPercentage: (json['vatPercentage'] as num?)?.toDouble() ?? 0.0,
        serviceFeePercentage:
            (json['serviceFeePercentage'] as num?)?.toDouble() ?? 0.0,
        baseDeliveryFee: (json['baseDeliveryFee'] as num?)?.toDouble() ?? 0.0,
        expressDeliverySurcharge:
            (json['expressDeliverySurcharge'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e, st) {
      _logger.severe('Error parsing FeeSettings from JSON: $e', e, st);
      rethrow;
    }
  }
}

// <<-- NEW: Create a class to model a single price override -->>
class PriceOverride {
  final String cylinderId;
  final double newPrice; // Stored in kobo

  PriceOverride({required this.cylinderId, required this.newPrice});

  factory PriceOverride.fromJson(Map<String, dynamic> json) {
    return PriceOverride(
      cylinderId: json['cylinderId'] as String? ?? '',
      newPrice: (json['newPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ServiceZone {
  final String id;
  final String outOfZoneMessage;
  final List<List<double>> coordinates;
  final double deliveryFee;
  final double expressSurcharge;

  // <<-- NEW: Add the list of price overrides to the model -->>
  final List<PriceOverride> priceOverrides;

  ServiceZone({
    required this.id,
    required this.coordinates,
    required this.outOfZoneMessage,
    required this.deliveryFee,
    required this.expressSurcharge,
    required this.priceOverrides, // Add to constructor
  });

  factory ServiceZone.fromJson(Map<String, dynamic> json) {
    _logger.fine('Starting to parse ServiceZone JSON for ID: ${json['id']}');
    try {
      final List<dynamic> polygons =
          json['area']?['coordinates'] as List? ?? [];
      List<List<double>> finalRing = [];

      if (polygons.isNotEmpty) {
        final List<dynamic> rings = polygons.first as List? ?? [];
        if (rings.isNotEmpty) {
          final List<dynamic> points = rings as List? ?? [];
          finalRing = points.map((point) {
            final pointList = point as List? ?? [];
            if (pointList.length >= 2) {
              final lng = pointList[0] is Map
                  ? double.tryParse(
                          pointList[0]['\$numberDouble'].toString()) ??
                      0.0
                  : (pointList[0] as num).toDouble();

              final lat = pointList[1] is Map
                  ? double.tryParse(
                          pointList[1]['\$numberDouble'].toString()) ??
                      0.0
                  : (pointList[1] as num).toDouble();
              return [lng, lat];
            }
            return [0.0, 0.0];
          }).toList();
        }
      }
      _logger.fine('Successfully parsed coordinates for zone ${json['id']}.');

      return ServiceZone(
        id: json['id'] as String? ?? '',
        outOfZoneMessage: json['outOfZoneMessage'] as String? ??
            'Default out of zone message.',
        coordinates: finalRing,
        deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
        expressSurcharge: (json['expressSurcharge'] as num?)?.toDouble() ?? 0.0,

        // <<-- NEW: Parse the priceOverrides array from the JSON -->>
        priceOverrides: (json['priceOverrides'] as List<dynamic>? ?? [])
            .map((item) => PriceOverride.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    } catch (e, st) {
      _logger.severe(
          'Error parsing ServiceZone from JSON for ID: ${json['id']}: $e',
          e,
          st);
      return ServiceZone(
        id: json['id'] as String? ?? '',
        coordinates: [],
        outOfZoneMessage: 'Parsing failed.',
        // Add default values for the new fields in the error case
        deliveryFee: 0.0,
        expressSurcharge: 0.0,
        priceOverrides: [],
      );
    }
  }
}

class SystemConfigModel {
  final List<CylinderSetting> cylinderSettings;
  final FeeSettings feeSettings;
  final List<ServiceZone> activeZones;

  SystemConfigModel({
    required this.cylinderSettings,
    required this.feeSettings,
    required this.activeZones,
  });

  factory SystemConfigModel.fromJson(Map<String, dynamic> json) {
    _logger.info('Starting to parse SystemConfigModel from API response.');
    try {
      final List<dynamic> cylinderSettingsJson =
          json['cylinderSettings'] as List<dynamic>? ?? [];
      final List<CylinderSetting> cylinderSettings = cylinderSettingsJson
          .map((item) => CylinderSetting.fromJson(item as Map<String, dynamic>))
          .toList();
      _logger.fine('Parsed ${cylinderSettings.length} cylinder settings.');

      final Map<String, dynamic>? feeSettingsJson =
          json['feeSettings'] as Map<String, dynamic>?;
      final FeeSettings feeSettings = FeeSettings.fromJson(feeSettingsJson);
      _logger.fine('Parsed fee settings.');

      final List<dynamic> activeZonesJson =
          json['activeZones'] as List<dynamic>? ?? [];
      final List<ServiceZone> activeZones = activeZonesJson
          .map((item) => ServiceZone.fromJson(item as Map<String, dynamic>))
          .toList();
      _logger.info('Parsed ${activeZones.length} active service zones.');

      return SystemConfigModel(
        cylinderSettings: cylinderSettings,
        feeSettings: feeSettings,
        activeZones: activeZones,
      );
    } catch (e, st) {
      _logger.severe('Error parsing SystemConfigModel from JSON: $e', e, st);
      rethrow;
    }
  }
}
