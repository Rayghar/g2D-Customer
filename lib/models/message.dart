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
  ///     {"$date": 1757896273881} or {"$date": "2025-01-01T00:00:00Z"}
  /// - Firestore-like {seconds:..., nanoseconds:...} (just in case)
  static DateTime _parseDate(dynamic v) {
    DateTime _fallback() => DateTime.now().toUtc();

    if (v == null) return _fallback();

    if (v is DateTime) return v.toUtc();

    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    }

    if (v is String) {
      // numeric ms as string?
      final asInt = int.tryParse(v);
      if (asInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
      }
      // ISO
      final iso = DateTime.tryParse(v);
      if (iso != null) return iso.toUtc();
      return _fallback();
    }

    if (v is Map) {
      // Mongo Extended JSON
      if (v.containsKey(r'$date')) {
        final inner = v[r'$date'];
        if (inner is Map && inner.containsKey(r'$numberLong')) {
          final ms = int.tryParse(inner[r'$numberLong'].toString());
          if (ms != null) {
            return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
          }
        } else if (inner is int) {
          return DateTime.fromMillisecondsSinceEpoch(inner, isUtc: true);
        } else if (inner is String) {
          final ms = int.tryParse(inner);
          if (ms != null) {
            return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
          }
          final iso = DateTime.tryParse(inner);
          if (iso != null) return iso.toUtc();
        }
      }

      // Firestore-like structure
      final sec = v['seconds'];
      final ns = v['nanoseconds'];
      if (sec is int) {
        final ms = (sec * 1000) + ((ns is int) ? (ns ~/ 1e6) : 0);
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      }
    }

    return _fallback();
  }

  /// Factory from any backend/socket map
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
