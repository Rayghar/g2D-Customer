// lib/models/message.dart

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      // The backend 'toJSON' plugin converts '_id' to 'id'
      id: json['id'] as String? ?? '',
      chatId: json['chatId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      recipientId: json['recipientId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      // Parse the ISO 8601 string from the server into a DateTime object
      createdAt: DateTime.parse(
          json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
