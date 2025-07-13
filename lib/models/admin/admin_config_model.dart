// File: lib/models/admin/admin_config_model.dart
import 'package:flutter/material.dart';
// Import the plain data model to map from it
import '../system_config_model.dart' as data_model;

// --- Cylinder Configuration ---
class CylinderConfigItem {
  String id; // e.g., 'gc_3kg', 'gc_5kg'
  String sizeLabel; // e.g., '3 KG', '5 KG'
  TextEditingController priceController;
  TextEditingController weightController; // Actual weight of gas in KG
  bool isActive;

  CylinderConfigItem({
    required this.id,
    required this.sizeLabel,
    required double initialPrice,
    required double initialWeight,
    this.isActive = true,
  })  : priceController =
            TextEditingController(text: initialPrice.toStringAsFixed(2)),
        weightController =
            TextEditingController(text: initialWeight.toStringAsFixed(1));

  Map<String, dynamic> toJson() => {
        'id': id,
        'sizeLabel': sizeLabel,
        'price': double.tryParse(priceController.text) ?? 0.0,
        'weightKg': double.tryParse(weightController.text) ?? 0.0,
        'isActive': isActive,
      };

  factory CylinderConfigItem.fromJson(Map<String, dynamic> json) {
    return CylinderConfigItem(
      id: json['id'] as String,
      sizeLabel: json['sizeLabel'] as String,
      initialPrice: (json['price'] as num?)?.toDouble() ?? 0.0,
      initialWeight: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
      isActive: (json['isActive'] as bool?) ?? true,
    );
  }

  // New factory to create from the plain data model
  factory CylinderConfigItem.fromDataModel(data_model.CylinderSetting data) {
    return CylinderConfigItem(
      id: data.id,
      sizeLabel: data.name, // Note the mapping from name to sizeLabel
      initialPrice: data.price / 100, // Assuming price is in smallest unit
      initialWeight: data.weightKg ?? 0.0,
      isActive: data.isActive ?? true,
    );
  }
}

// --- Fee Configuration ---
class FeeConfig {
  TextEditingController baseDeliveryFeeController;
  TextEditingController expressDeliverySurchargeController;
  TextEditingController
      vatPercentageController; // Store as percentage e.g. 7.5 for 7.5%
  TextEditingController
      serviceFeePercentageController; // Store as percentage e.g. 1.0 for 1.0%

  FeeConfig({
    double baseDeliveryFee = 500,
    double expressSurcharge = 1000,
    double vatPercent = 7.5, // e.g., 7.5 for 7.5%
    double servicePercent = 1.0, // e.g., 1.0 for 1.0%
  })  : baseDeliveryFeeController =
            TextEditingController(text: baseDeliveryFee.toStringAsFixed(2)),
        expressDeliverySurchargeController =
            TextEditingController(text: expressSurcharge.toStringAsFixed(2)),
        vatPercentageController =
            TextEditingController(text: vatPercent.toStringAsFixed(1)),
        serviceFeePercentageController =
            TextEditingController(text: servicePercent.toStringAsFixed(1));

  Map<String, dynamic> toJson() => {
        'baseDeliveryFee':
            double.tryParse(baseDeliveryFeeController.text) ?? 0.0,
        'expressDeliverySurcharge':
            double.tryParse(expressDeliverySurchargeController.text) ?? 0.0,
        'vatPercentage': double.tryParse(vatPercentageController.text) ??
            0.0, // Send as 7.5 for 7.5%
        'serviceFeePercentage':
            double.tryParse(serviceFeePercentageController.text) ??
                0.0, // Send as 1.0 for 1.0%
      };

  factory FeeConfig.fromJson(Map<String, dynamic> json) {
    return FeeConfig(
      baseDeliveryFee: (json['baseDeliveryFee'] as num?)?.toDouble() ?? 500.0,
      expressSurcharge:
          (json['expressDeliverySurcharge'] as num?)?.toDouble() ?? 1000.0,
      vatPercent: (json['vatPercentage'] as num?)?.toDouble() ??
          7.5, // Expects 7.5 for 7.5%
      servicePercent: (json['serviceFeePercentage'] as num?)?.toDouble() ??
          1.0, // Expects 1.0 for 1.0%
    );
  }

  // New factory to create from the plain data model
  factory FeeConfig.fromDataModel(data_model.FeeSettings data) {
    return FeeConfig(
      baseDeliveryFee: data.baseDeliveryFee / 100,
      expressSurcharge: data.expressDeliverySurcharge / 100,
      vatPercent: data.vatPercentage,
      servicePercent: data.serviceFeePercentage,
    );
  }
}

// --- Routing Configuration (Revised) ---
class RoutingConfig {
  TextEditingController maxPickupWindowMinutesController;
  TextEditingController maxBatchWeightKgController;

  RoutingConfig({
    int maxPickupWindowMinutes = 30,
    double maxBatchWeightKg = 500,
  })  : maxPickupWindowMinutesController =
            TextEditingController(text: maxPickupWindowMinutes.toString()),
        maxBatchWeightKgController =
            TextEditingController(text: maxBatchWeightKg.toStringAsFixed(1));

  Map<String, dynamic> toJson() => {
        'maxPickupWindowMinutes':
            int.tryParse(maxPickupWindowMinutesController.text) ?? 30,
        'maxBatchWeightKg':
            double.tryParse(maxBatchWeightKgController.text) ?? 500.0,
      };

  factory RoutingConfig.fromJson(Map<String, dynamic> json) {
    return RoutingConfig(
      maxPickupWindowMinutes:
          (json['maxPickupWindowMinutes'] as num?)?.toInt() ?? 30,
      maxBatchWeightKg: (json['maxBatchWeightKg'] as num?)?.toDouble() ?? 500.0,
    );
  }
}

// --- Main System Config Model to hold all configurations ---
class SystemConfigModel {
  List<CylinderConfigItem> cylinderConfigs;
  FeeConfig feeConfig;
  RoutingConfig routingConfig;

  SystemConfigModel({
    required this.cylinderConfigs,
    required this.feeConfig,
    required this.routingConfig,
  });

  factory SystemConfigModel.fromJson(Map<String, dynamic> json) {
    return SystemConfigModel(
      cylinderConfigs: (json['cylinderSettings'] as List<dynamic>?)
              ?.map((item) =>
                  CylinderConfigItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      feeConfig: FeeConfig.fromJson(
          json['feeSettings'] as Map<String, dynamic>? ?? {}),
      routingConfig: RoutingConfig.fromJson(
          json['routingSettings'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cylinderSettings': cylinderConfigs.map((c) => c.toJson()).toList(),
      'feeSettings': feeConfig.toJson(),
      'routingSettings': routingConfig.toJson(),
    };
  }

  // New factory to create the entire admin model from the plain data model
  factory SystemConfigModel.fromDataModel(data_model.SystemConfigModel data) {
    return SystemConfigModel(
      cylinderConfigs: data.cylinderSettings
          .map((c) => CylinderConfigItem.fromDataModel(c))
          .toList(),
      feeConfig: FeeConfig.fromDataModel(data.feeSettings),
      // Assuming RoutingConfig is not part of the public SystemConfigModel
      // If it is, you would map it here as well. For now, initialize default.
      routingConfig: RoutingConfig(),
    );
  }
}
