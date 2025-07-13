// File: lib/models/admin/admin_referral_summary_model.dart

import 'package:flutter/material.dart'; // For UniqueKey

class AdminReferralSummaryModel {
  final String id; // Referral record ID
  final String userId; // User ID
  final String userName;
  final String? userEmail;
  final String? userPhone;
  final String referralCode;
  final String programDescription;
  final String benefitSelf;
  final String benefitFriend;
  final bool isActive;
  final int totalReferredCount;
  final int successfulReferralsCount;
  final DateTime createdAt;

  AdminReferralSummaryModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.userPhone,
    required this.referralCode,
    required this.programDescription,
    required this.benefitSelf,
    required this.benefitFriend,
    required this.isActive,
    required this.totalReferredCount,
    required this.successfulReferralsCount,
    required this.createdAt,
  });

  factory AdminReferralSummaryModel.fromJson(Map<String, dynamic> json) {
    return AdminReferralSummaryModel(
      id: json['id'] as String? ?? UniqueKey().toString(),
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'N/A',
      userEmail: json['userEmail'] as String?,
      userPhone: json['userPhone'] as String?,
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
    );
  }
}
