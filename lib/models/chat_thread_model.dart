// lib/models/chat_thread_model.dart

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'message.dart';

/// Thread row for the Messages list.
/// - `chatId` == orderId (room id)
/// - `lastMessage` is a Message parsed from the server (or null if none)
/// - `recipientName`/`recipientPhone` are optional conveniences if your API sends them
class ChatThreadModel {
  final String chatId;
  final Message? lastMessage;

  /// Optional convenience fields if your API includes them
  final String? recipientName;
  final String? recipientPhone;

  /// Unread info (if your API provides it)
  final int unreadCount;
  final bool hasUnreadMessages;

  ChatThreadModel({
    required this.chatId,
    this.lastMessage,
    this.recipientName,
    this.recipientPhone,
    this.unreadCount = 0,
    this.hasUnreadMessages = false,
  });

  // -------------------------
  // JSON (REST) constructor
  // -------------------------
  ///
  /// Accepts multiple shapes, e.g.:
  /// {
  ///   "chatId": "uuid",
  ///   "lastMessage": { ...Message json... },
  ///   "recipientName": "Neme Iloh",
  ///   "recipientPhone": "0913...",
  ///   "unreadCount": 2,
  ///   "hasUnread": true
  /// }
  factory ChatThreadModel.fromJson(Map<String, dynamic> json) {
    final lm = json['lastMessage'];
    Message? parsedLast;
    if (lm is Map<String, dynamic>) {
      parsedLast = Message.fromJson(lm);
    }

    return ChatThreadModel(
      chatId: json['chatId']?.toString() ?? json['orderId']?.toString() ?? '',
      lastMessage: parsedLast,
      recipientName: json['recipientName']?.toString(),
      recipientPhone: json['recipientPhone']?.toString(),
      unreadCount: _asInt(json['unreadCount']),
      hasUnreadMessages: _asBool(json['hasUnread']),
    );
  }

  // ---------------------------------
  // Firestore (legacy) constructor
  // ---------------------------------
  ///
  /// Keeps compatibility with any old collection that looked like:
  /// {
  ///   participants: [customerId, driverId],
  ///   participantInfo: {
  ///     "<userId>": { name, role, photoUrl }
  ///   },
  ///   orderId: "<uuid>",
  ///   lastMessage: { text, senderId, timestamp },
  ///   readStatus: { "<userId>": true/false }
  /// }
  factory ChatThreadModel.fromFirestore(
    Map<String, dynamic> data,
    String docId,
    String currentUserId,
  ) {
    final List<dynamic> participants =
        (data['participants'] as List?) ?? const [];
    final String otherParticipantId = participants
            .firstWhere((id) => id != currentUserId, orElse: () => '')
            ?.toString() ??
        '';

    final Map<String, dynamic> participantInfo =
        (data['participantInfo'] as Map?)?.cast<String, dynamic>() ?? const {};
    final Map<String, dynamic> otherParticipantData =
        (participantInfo[otherParticipantId] as Map?)
                ?.cast<String, dynamic>() ??
            const {};

    final lm = (data['lastMessage'] as Map?)?.cast<String, dynamic>();
    final msg = _messageFromLegacyLast(
      lastMessageMap: lm,
      chatId: docId,
      otherParticipantId: otherParticipantId,
    );

    final bool isUnreadForMe = (lm != null &&
        (lm['senderId']?.toString() ?? '') != currentUserId &&
        !((data['readStatus'] as Map?)?[currentUserId] == true));

    return ChatThreadModel(
      chatId: docId,
      lastMessage: msg,
      recipientName: (otherParticipantData['name'] as String?)?.trim(),
      recipientPhone: (otherParticipantData['phone'] as String?)?.trim(),
      unreadCount: isUnreadForMe ? 1 : 0,
      hasUnreadMessages: isUnreadForMe,
    );
  }

  // -------------------------
  // Helpers
  // -------------------------
  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v == null) return false;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  static DateTime _parseDateFlexible(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is int)
      return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
    if (v is String) {
      final iso = DateTime.tryParse(v);
      if (iso != null) return iso.toLocal();
      final ms = int.tryParse(v);
      if (ms != null) {
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
      }
    }
    return DateTime.now();
  }

  static Message? _messageFromLegacyLast({
    required Map<String, dynamic>? lastMessageMap,
    required String chatId,
    required String otherParticipantId,
  }) {
    if (lastMessageMap == null) return null;

    final createdAt = _parseDateFlexible(
      lastMessageMap['createdAt'] ??
          lastMessageMap['timestamp'] ??
          lastMessageMap['time'],
    );

    return Message(
      id: (lastMessageMap['_id'] ??
              lastMessageMap['id'] ??
              'legacy_${createdAt.millisecondsSinceEpoch}')
          .toString(),
      chatId: chatId,
      senderId: lastMessageMap['senderId']?.toString() ?? '',
      recipientId:
          lastMessageMap['recipientId']?.toString() ?? otherParticipantId,
      text: lastMessageMap['text']?.toString() ?? '',
      createdAt: createdAt,
      status: lastMessageMap['status']?.toString() ?? 'sent',
    );
  }
}
