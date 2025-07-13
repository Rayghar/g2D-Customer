// File: lib/models/admin/admin_promotion_model.dart

import 'package:flutter/material.dart'; // For Color, if used directly in model
import 'package:intl/intl.dart';

class AdminPromotionModel {
  final String id;
  String title;
  String? promoCode;
  String
      type; // e.g., "Percentage Discount", "Fixed Amount Discount", "Free Delivery"
  double value; // e.g., 20 for 20%, or 500 for N500, or 0 for Free Delivery
  DateTime validFrom;
  DateTime validUntil;
  bool isActive;
  String shortDescription;
  String? longDescription; // Added based on add/edit screen
  String? termsAndConditions; // Added based on add/edit screen
  String? imageUrl; // Added based on add/edit screen
  // Color fields were commented out in add/edit, can be added if needed
  // String? backgroundColorHex;
  // String? textColorHex;

  AdminPromotionModel({
    required this.id,
    required this.title,
    this.promoCode,
    required this.type,
    required this.value,
    required this.validFrom,
    required this.validUntil,
    required this.isActive,
    required this.shortDescription,
    this.longDescription,
    this.termsAndConditions,
    this.imageUrl,
    // this.backgroundColorHex,
    // this.textColorHex,
  });

  factory AdminPromotionModel.fromJson(Map<String, dynamic> json) {
    return AdminPromotionModel(
      id: json['id'] as String? ?? UniqueKey().toString(), // Fallback ID
      title: json['title'] as String? ?? 'Untitled Promotion',
      promoCode: json['promoCode'] as String?,
      type: json['type'] as String? ?? 'Fixed Amount Discount',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      validFrom: DateTime.tryParse(json['validFrom'] as String? ?? '') ??
          DateTime.now(),
      validUntil: DateTime.tryParse(json['validUntil'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      isActive: (json['isActive'] as bool?) ?? false,
      shortDescription: json['shortDescription'] as String? ?? '',
      longDescription: json['longDescription'] as String?,
      termsAndConditions: json['termsAndConditions'] as String?,
      imageUrl: json['imageUrl'] as String?,
      // backgroundColorHex: json['backgroundColorHex'] as String?,
      // textColorHex: json['textColorHex'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    // CORRECTED: Explicitly type the map to Map<String, dynamic>
    final Map<String, dynamic> map = {
      'id': id,
      'title': title,
      'type': type,
      'value': value,
      'validFrom': validFrom.toIso8601String(),
      'validUntil': validUntil.toIso8601String(),
      'isActive': isActive,
      'shortDescription': shortDescription,
    };
    // These conditional assignments are now safe because 'dynamic' can hold null
    if (promoCode != null) {
      map['promoCode'] = promoCode;
    }
    if (longDescription != null) {
      map['longDescription'] = longDescription;
    }
    if (termsAndConditions != null) {
      map['termsAndConditions'] = termsAndConditions;
    }
    if (imageUrl != null) {
      map['imageUrl'] = imageUrl;
    }
    // if (backgroundColorHex != null) map['backgroundColorHex'] = backgroundColorHex;
    // if (textColorHex != null) map['textColorHex'] = textColorHex;
    return map;
  }

  String get validityPeriodDisplay {
    return "${DateFormat('dd MMM, yyyy').format(validFrom)} - ${DateFormat('dd MMM, yyyy').format(validUntil)}";
  }

  String get typeAndValueDisplay {
    switch (type) {
      case "Percentage Discount":
        return "${value.toStringAsFixed(0)}% Off";
      case "Fixed Amount Discount":
        return "₦${value.toStringAsFixed(0)} Off";
      case "Free Delivery":
        return "Free Delivery";
      default:
        return type;
    }
  }
}
