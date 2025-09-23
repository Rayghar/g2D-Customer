// lib/services/socket_service.dart
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import './auth_service.dart';

class SocketService with ChangeNotifier {
  IO.Socket? _socket;
  final AuthService _auth = AuthService();

  // Your Render host (no trailing slash)
  static const String _socketUrl = 'https://primejet-backend.onrender.com';

  bool get isConnected => _socket?.connected == true;

  /// Create the socket and connect **after** login, e.g. from your first screen's initState.
  Future<void> connect() async {
    final token = await _auth.getToken();
    if (token == null) {
      debugPrint('[SocketService] No auth token; cannot connect.');
      return;
    }

    // If already connected, do nothing.
    if (_socket != null && _socket!.connected) return;

    // Dispose stale instance (important after relogin / hot restart)
    if (_socket != null) {
      try {
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }

    _socket = IO.io(
      _socketUrl,
      <String, dynamic>{
        // Add polling fallback to survive odd networks/firewalls
        'transports': ['websocket', 'polling'],
        // We control when to connect (don’t block login)
        'autoConnect': false,
        // Backend reads this JWT in handshake.auth.token
        'auth': {'token': token},

        // Fail fast & retry sanely
        'timeout': 8000, // ms to fail initial connect
        'reconnection': true,
        'reconnectionAttempts': 8, // try a few times, not forever
        'reconnectionDelay': 800, // backoff start
        'reconnectionDelayMax': 3000, // backoff cap
      },
    );

    // ---- Lifecycle logs (no UI side-effects here) ----
    _socket!.onConnect((_) {
      debugPrint('[SocketService] Connected: ${_socket?.id}');
      notifyListeners();
    });
    _socket!.onDisconnect((_) {
      debugPrint('[SocketService] Disconnected.');
      notifyListeners();
    });
    _socket!.onReconnect((_) {
      debugPrint('[SocketService] Reconnected: ${_socket?.id}');
      notifyListeners();
    });
    _socket!.onConnectError((err) {
      debugPrint('[SocketService] ConnectError: $err');
    });
    _socket!.onError((err) {
      debugPrint('[SocketService] Error: $err');
    });

    // finally connect
    _socket!.connect();
  }

  /// Optional explicit disconnect (e.g., on logout).
  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
    } catch (_) {}
  }

  // ===== Room / Read APIs =====

  /// Join a chat room (chatId == orderId)
  void joinRoom(String chatId) {
    if (!isConnected) return;
    _socket?.emit('join_room', chatId);
    debugPrint('[SocketService] join_room -> $chatId');
  }

  /// Mark all incoming messages in this chat as read.
  void markRead(String chatId) {
    if (!isConnected) return;
    _socket?.emit('mark_read', {'chatId': chatId});
    debugPrint('[SocketService] mark_read -> $chatId');
  }

  // ===== Send message =====

  /// Send a message. Use named params to avoid call-site mistakes.
  void sendMessage({
    required String chatId,
    required String recipientId,
    required String text,
    String? tempId, // for optimistic bubble reconciliation
  }) {
    if (!isConnected) return;
    _socket?.emit('send_message', {
      'chatId': chatId,
      'recipientId': recipientId,
      'text': text,
      if (tempId != null) 'tempId': tempId,
    });
  }

  // ===== Event wiring helpers (dedup with .off before .on) =====

  /// New message arrived
  void onReceive(void Function(dynamic) handler) {
    _socket?.off('receive_message');
    _socket?.on('receive_message', handler);
  }

  /// ACK for optimistic -> real message id mapping
  void onAck(void Function(dynamic) handler) {
    _socket?.off('message_ack');
    _socket?.on('message_ack', handler);
  }

  /// Server-side send error surfaced to client
  void onErrorEvt(void Function(dynamic) handler) {
    _socket?.off('message_error');
    _socket?.on('message_error', handler);
  }

  /// Per-message status updates: { chatId, messageId, status: 'delivered'|'read' }
  void onStatus(void Function(dynamic) handler) {
    _socket?.off('message_status');
    _socket?.on('message_status', handler);
  }

  /// Whole chat read event: { chatId }
  void onChatRead(void Function(dynamic) handler) {
    _socket?.off('chat_read');
    _socket?.on('chat_read', handler);
  }

  /// Thread-level unread counters (optional, for list badges)
  /// Payloads you emit from backend could be:
  ///   thread_unread: { chatId, unread: 3 }
  ///   thread_read:   { chatId }
  void onThreadUnread(void Function(dynamic) handler) {
    _socket?.off('thread_unread');
    _socket?.on('thread_unread', handler);
  }

  void onThreadRead(void Function(dynamic) handler) {
    _socket?.off('thread_read');
    _socket?.on('thread_read', handler);
  }

  /// Back-compat alias used in a few places
  void listenForMessage(Function(dynamic) handler) => onReceive(handler);

  /// Generic event attach (handy for experiments)
  void onEvent(String event, void Function(dynamic) handler) {
    _socket?.off(event);
    _socket?.on(event, handler);
  }

  /// Generic off
  void offEvent(String event) => _socket?.off(event);

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
