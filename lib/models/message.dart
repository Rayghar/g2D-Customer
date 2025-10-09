// lib/models/message.dart

/// Chat message model used across customer/driver apps.
/// Compatible with:
/// - Backend REST (Mongo / Mongoose)
/// - Socket.IO payloads
/// - Optimistic "temp_*" messages on the client
class Message {
  final String id; // Mongo _id (or local temp_*)
  final String chatId; // == order UUID used as room id
  final String senderId;
  final String recipientId;
  final String text;

  /// 'sent' | 'delivered' | 'read' (nullable while migrating)
  final String? status;
  final DateTime createdAt; // always stored UTC

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.createdAt,
    this.status,
  });

  /// True if this is an optimistic local message
  bool get isTemp => id.startsWith('temp_') || id.startsWith('local_');

  /// Convenience: is this message authored by [userId]?
  bool isMine(String userId) => senderId == userId;

  /// Robust `_id` extraction:
  /// - string
  /// - Mongo Extended JSON: {"$oid":"..."}
  static String _parseId(Map<String, dynamic> json) {
    final raw = json['_id'] ?? json['id'];
    if (raw == null) {
      return 'local_${DateTime.now().microsecondsSinceEpoch}';
    }
    if (raw is Map && raw.containsKey(r'$oid')) {
      final v = raw[r'$oid'];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    final s = raw.toString();
    return s.isEmpty ? 'local_${DateTime.now().microsecondsSinceEpoch}' : s;
  }

  /// Ultra-tolerant date parser handling:
  /// - DateTime
  /// - epoch ms (int)
  /// - ISO 8601 string
  /// - numeric string (epoch ms)
  /// - Mongo Extended JSON:
  ///     {"$date":{"$numberLong":"1757896273881"}} or
  ///     {"$date": 1757896273881} or {"$date": "2025-01-01T0..."}
  static DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now().toUtc();

    if (raw is DateTime) return raw.toUtc();
    if (raw is int)
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);

    String? s;
    if (raw is String) {
      s = raw;
    } else if (raw is Map) {
      final inner = raw[r'$date'];
      if (inner is int)
        return DateTime.fromMillisecondsSinceEpoch(inner, isUtc: true);
      if (inner is String) s = inner;
      if (inner is Map && inner.containsKey(r'$numberLong')) {
        final v = inner[r'$numberLong'];
        if (v is String) {
          final ms = int.tryParse(v);
          if (ms != null)
            return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        }
      }
    }

    if (s != null && s.isNotEmpty) {
      final ms = int.tryParse(s);
      if (ms != null)
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      try {
        return DateTime.parse(s).toUtc();
      } catch (_) {}
    }

    return DateTime.now().toUtc();
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: _parseId(json),
      chatId: (json['chatId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      recipientId: (json['recipientId'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      status: json['status']?.toString(),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  /// Minimal JSON for local usage / caching.
  /// (For POSTing via sockets we emit a dedicated payload in the SocketService.)
  Map<String, dynamic> toJson() => {
        'id': id,
        'chatId': chatId,
        'senderId': senderId,
        'recipientId': recipientId,
        'text': text,
        if (status != null) 'status': status,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? recipientId,
    String? text,
    String? status,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  // For sorting newest first if needed
  int compareByCreatedDesc(Message other) =>
      other.createdAt.millisecondsSinceEpoch
          .compareTo(createdAt.millisecondsSinceEpoch);

  @override
  String toString() =>
      'Message(id:$id chatId:$chatId from:$senderId to:$recipientId "$text" status:$status @${createdAt.toIso8601String()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
