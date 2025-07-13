// File: lib/models/chat_thread_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Participant {
  final String id;
  final String name;
  final String? photoUrl;

  Participant({required this.id, required this.name, this.photoUrl});

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown User',
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

class LastMessage {
  final String text;
  final DateTime timestamp;

  LastMessage({required this.text, required this.timestamp});

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    final ts = json['timestamp'];
    DateTime parsedDate;

    // Handles both Firestore Timestamps and ISO8601 strings from the API
    if (ts is Timestamp) {
      parsedDate = ts.toDate();
    } else if (ts is String) {
      parsedDate = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return LastMessage(
      text: json['text'] as String? ?? '...',
      timestamp: parsedDate,
    );
  }
}

class ChatThreadModel {
  final String chatId;
  final String orderId;
  final Participant otherParticipant;
  final LastMessage lastMessage;
  final bool hasUnreadMessages;

  ChatThreadModel({
    required this.chatId,
    required this.orderId,
    required this.otherParticipant,
    required this.lastMessage,
    required this.hasUnreadMessages,
  });

  // <<< FIX: The missing fromJson factory constructor is now added. >>>
  // This is used by ApiService to parse data from the REST API.
  factory ChatThreadModel.fromJson(Map<String, dynamic> json) {
    return ChatThreadModel(
      chatId: json['chatId'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      otherParticipant: Participant.fromJson(
          json['otherParticipant'] as Map<String, dynamic>? ?? {}),
      lastMessage: LastMessage.fromJson(
          json['lastMessage'] as Map<String, dynamic>? ?? {}),
      hasUnreadMessages: json['hasUnreadMessages'] as bool? ?? false,
    );
  }
}
