// File: lib/models/deal_model.dart

import 'package:flutter/material.dart';
import '../screens/customer/promotion_details_screen.dart';
import '../screens/customer/order_placement_screen.dart';

class DealModel {
  final String id;
  final String title;
  final String shortDescription;
  final String? longDescription;
  final String? promoCode;
  final DateTime? validFrom; // Made optional
  final DateTime? validUntil; // Made optional
  final String? type; // Made optional
  final double? value; // Made optional
  final bool isActive;
  final String? termsAndConditions;
  final String? imageUrl;
  final Color? cardColor;
  final Color? textColor;
  final String ctaText;
  final String? ctaLink;
  final Map<String, dynamic>? ctaArgs;

  DealModel({
    required this.id,
    required this.title,
    required this.shortDescription,
    this.longDescription,
    this.promoCode,
    this.validFrom,
    this.validUntil,
    this.type,
    this.value,
    required this.isActive,
    this.termsAndConditions,
    this.imageUrl,
    this.cardColor,
    this.textColor,
    required this.ctaText,
    this.ctaLink,
    this.ctaArgs,
  });

  factory DealModel.fromBackendPromotion(
      Map<String, dynamic> backendPromotionJson) {
    String type = backendPromotionJson['type'] as String? ?? 'Unknown';
    String ctaTextVal = "View Details";
    String? ctaLinkVal = PromotionDetailsScreen.routeName;
    Map<String, dynamic>? ctaArgsVal = {
      'promotionId': backendPromotionJson['id']
    };

    String? terms = backendPromotionJson['termsAndConditions'] as String? ??
        backendPromotionJson['longDescription'] as String?;

    if (backendPromotionJson['promoCode'] != null) {
      ctaTextVal = "Use Code: ${backendPromotionJson['promoCode']}";
      ctaLinkVal = OrderPlacementScreen.routeName;
      ctaArgsVal = {'promoCode': backendPromotionJson['promoCode']};
    }

    return DealModel(
      id: backendPromotionJson['id'] as String? ?? '',
      title: backendPromotionJson['title'] as String? ?? 'Special Deal!',
      shortDescription: backendPromotionJson['shortDescription'] as String? ??
          'Amazing savings just for you.',
      longDescription: backendPromotionJson['longDescription'] as String?,
      promoCode: backendPromotionJson['promoCode'] as String?,
      validFrom:
          DateTime.tryParse(backendPromotionJson['validFrom'] as String? ?? ''),
      validUntil: DateTime.tryParse(
          backendPromotionJson['validUntil'] as String? ?? ''),
      type: type,
      value: (backendPromotionJson['value'] as num?)?.toDouble(),
      isActive: (backendPromotionJson['isActive'] as bool?) ?? false,
      termsAndConditions: terms,
      imageUrl: backendPromotionJson['imageUrl'] as String?,
      ctaText: ctaTextVal,
      ctaLink: ctaLinkVal,
      ctaArgs: ctaArgsVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'shortDescription': shortDescription,
      'longDescription': longDescription,
      'promoCode': promoCode,
      'validFrom': validFrom?.toIso8601String(),
      'validUntil': validUntil?.toIso8601String(),
      'type': type,
      'value': value,
      'isActive': isActive,
      'termsAndConditions': termsAndConditions,
      'imageUrl': imageUrl,
      'ctaText': ctaText,
      'ctaLink': ctaLink,
      'ctaArgs': ctaArgs,
    };
  }
}
