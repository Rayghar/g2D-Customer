// lib/models/chat_thread_model.dart

// Note: We are keeping the fromFirestore constructor for now in case
// any part of your app still uses it, but adding the new fromJson factory.

import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.hasUnreadMessages = false,
  });

  // ✅ FACTORY CONSTRUCTOR TO PARSE JSON FROM YOUR API
  factory ChatThreadModel.fromJson(Map<String, dynamic> json) {
    return ChatThreadModel(
      chatId: json['chatId'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      otherParticipant: Participant.fromJson(
          json['otherParticipant'] as Map<String, dynamic>? ?? {}),
      lastMessage:
          LastMessage.fromJson(json['lastMessage'] as Map<String, dynamic>?),
      // You can add logic for unread status if the API provides it
      hasUnreadMessages: false,
    );
  }

  // Your existing fromFirestore factory (can be kept or removed if no longer used)
  factory ChatThreadModel.fromFirestore(
    Map<String, dynamic> data,
    String docId,
    String currentUserId,
  ) {
    // ... existing fromFirestore logic ...
    final List<dynamic> participants = data['participants'] ?? [];
    final String otherParticipantId =
        participants.firstWhere((id) => id != currentUserId, orElse: () => '');
    final Map<String, dynamic> participantInfo = data['participantInfo'] ?? {};
    final Map<String, dynamic> otherParticipantData =
        participantInfo[otherParticipantId] ?? {};

    return ChatThreadModel(
      chatId: docId,
      orderId: data['orderId'] ?? '',
      otherParticipant: Participant.fromJson(otherParticipantData),
      lastMessage: LastMessage.fromMap(data['lastMessage']),
      hasUnreadMessages: (data['lastMessage'] != null &&
          data['lastMessage']['senderId'] != currentUserId &&
          !(data['readStatus']?[currentUserId] ?? false)),
    );
  }
}

class Participant {
  final String id;
  final String name;
  final String role;
  final String? photoUrl;

  Participant({
    required this.id,
    required this.name,
    required this.role,
    this.photoUrl,
  });

  // ✅ FACTORY CONSTRUCTOR TO PARSE JSON
  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown User',
      role: json['role'] as String? ?? 'user',
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

class LastMessage {
  final String text;
  final String senderId;
  final DateTime timestamp;

  LastMessage({
    required this.text,
    required this.senderId,
    required this.timestamp,
  });

  // ✅ FACTORY CONSTRUCTOR TO PARSE JSON
  factory LastMessage.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return LastMessage(
        text: 'No messages yet.',
        senderId: '',
        timestamp: DateTime.now(),
      );
    }
    return LastMessage(
      text: json['text'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      // Use 'createdAt' from the Message model in the backend
      timestamp: DateTime.parse(
          json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  // Your existing fromMap factory
  factory LastMessage.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return LastMessage(
        text: 'No messages yet.',
        senderId: '',
        timestamp: DateTime.now(),
      );
    }
    return LastMessage(
      text: map['text'] ?? '',
      senderId: map['senderId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }
}
