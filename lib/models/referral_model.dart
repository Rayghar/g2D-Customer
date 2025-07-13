// File: lib/models/referral_model.dart

import 'package:flutter/material.dart'; // For UniqueKey

class ReferralModel {
  final String id;
  final String userId;
  final String referralCode;
  final String programDescription;
  final String benefitSelf;
  final String benefitFriend;
  final bool isActive;
  final int totalReferredCount;
  final int successfulReferralsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReferralModel({
    required this.id,
    required this.userId,
    required this.referralCode,
    required this.programDescription,
    required this.benefitSelf,
    required this.benefitFriend,
    required this.isActive,
    required this.totalReferredCount,
    required this.successfulReferralsCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      id: json['id'] as String? ?? UniqueKey().toString(),
      userId: json['userId'] as String? ?? '',
      referralCode: json['referralCode'] as String? ?? '',
      programDescription: json['programDescription'] as String? ?? 'N/A',
      benefitSelf: json['benefitSelf'] as String? ?? 'N/A',
      benefitFriend: json['benefitFriend'] as String? ?? 'N/A',
      isActive: json['isActive'] as bool? ?? false,
      totalReferredCount: (json['totalReferredCount'] as num?)?.toInt() ?? 0,
      successfulReferralsCount:
          (json['successfulReferralsCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
