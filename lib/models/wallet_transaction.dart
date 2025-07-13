// File: lib/models/wallet_transaction.dart
import 'package:intl/intl.dart';

class WalletTransaction {
  final String id;
  final String type;
  final double amount; // Amount in smallest unit (kobo)
  final String currency;
  final String status;
  final String description;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.description,
    required this.createdAt,
  });

  String get formattedDate =>
      DateFormat('MMM dd, yyyy - hh:mm a').format(createdAt.toLocal());

  // Type determines if it's a credit or debit, not the sign of the amount
  bool get isCredit => [
        'DEPOSIT',
        'REFUND_TO_WALLET',
        'REFERRAL_BONUS',
        'ADMIN_CREDIT'
      ].contains(type);

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'UNKNOWN',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'NGN',
      status: json['status'] as String? ?? 'UNKNOWN',
      description: json['description'] as String? ?? 'No description',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
