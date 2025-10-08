// lib/models/chat_thread_model.dart
import 'message.dart';

class ChatThreadModel {
  final String chatId;
  final String recipientId;
  final String? recipientName;
  final String? recipientPhoneNumber;

  // New contextual fields
  final String? orderStatus;
  final int? stopNumber;

  // Mutable state for the UI
  Message? lastMessage;
  int unreadCount;

  // ===== FIX: Converted constructor to use named parameters =====
  ChatThreadModel({
    required this.chatId,
    required this.recipientId,
    this.recipientName,
    this.recipientPhoneNumber,
    this.orderStatus,
    this.stopNumber,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ChatThreadModel.fromJson(Map<String, dynamic> json) {
    return ChatThreadModel(
      // The constructor now matches this structure perfectly.
      chatId: json['chatId'] as String,
      recipientId: json['recipientId'] as String,
      recipientName: json['recipientName'] as String?,
      recipientPhoneNumber: json['recipientPhoneNumber'] as String?,
      orderStatus: json['orderStatus'] as String?,
      stopNumber: json['stopNumber'] as int?,
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}
