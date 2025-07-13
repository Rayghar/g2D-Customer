// File: lib/models/system_config_model.dart

class CylinderSetting {
  final String id;
  final String name; // Maps to backend 'name', frontend 'sizeLabel'
  final double price; // Price in smallest currency unit
  final double? weightKg; // If backend provides this
  final bool? isActive;

  CylinderSetting({
    required this.id,
    required this.name,
    required this.price,
    this.weightKg,
    this.isActive,
  });

  factory CylinderSetting.fromJson(Map<String, dynamic> json) {
    return CylinderSetting(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '', // Backend sends 'name'
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      isActive: json['isActive'] as bool?,
    );
  }
}

class FeeSettings {
  final double vatPercentage;
  final double serviceFeePercentage;
  final double baseDeliveryFee; // In smallest currency unit
  final double expressDeliverySurcharge; // In smallest currency unit

  FeeSettings({
    required this.vatPercentage,
    required this.serviceFeePercentage,
    required this.baseDeliveryFee,
    required this.expressDeliverySurcharge,
  });

  factory FeeSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      // Provide safe defaults if backend doesn't send this, though it should
      return FeeSettings(
          vatPercentage: 0.0,
          serviceFeePercentage: 0.0,
          baseDeliveryFee: 0.0,
          expressDeliverySurcharge: 0.0);
    }
    return FeeSettings(
      vatPercentage: (json['vatPercentage'] as num?)?.toDouble() ?? 0.0,
      serviceFeePercentage:
          (json['serviceFeePercentage'] as num?)?.toDouble() ?? 0.0,
      baseDeliveryFee: (json['baseDeliveryFee'] as num?)?.toDouble() ?? 0.0,
      expressDeliverySurcharge:
          (json['expressDeliverySurcharge'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SystemConfigModel {
  final List<CylinderSetting> cylinderSettings;
  final FeeSettings feeSettings;
  // Add other config sections like referralProgram if needed by customer frontend

  SystemConfigModel({
    required this.cylinderSettings,
    required this.feeSettings,
  });

  factory SystemConfigModel.fromJson(Map<String, dynamic> json) {
    return SystemConfigModel(
      cylinderSettings: (json['cylinderSettings'] as List<dynamic>?)
              ?.map((item) =>
                  CylinderSetting.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      feeSettings:
          FeeSettings.fromJson(json['feeSettings'] as Map<String, dynamic>?),
    );
  }
}
