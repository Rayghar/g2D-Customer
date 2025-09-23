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

  Future<void> connect() async {
    final token = await _auth.getToken();
    if (token == null) {
      debugPrint('[SocketService] No auth token; cannot connect.');
      return;
    }

    // If we already have a connected socket, keep it.
    if (_socket != null && _socket!.connected) return;

    // Dispose stale instance (important if user re-logs in)
    if (_socket != null) {
      try {
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }

    _socket = IO.io(
      _socketUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false, // we will call .connect() manually
        'auth': {'token': token}, // backend reads this
        'reconnection': true,
        'reconnectionAttempts': 50,
        'reconnectionDelay': 1000,
        'timeout': 20000,
      },
    );

    // Core lifecycle logs
    _socket!.onConnect((_) {
      debugPrint('[SocketService] Connected: ${_socket?.id}');
      notifyListeners();
    });
    _socket!.onDisconnect((_) {
      debugPrint('[SocketService] Disconnected.');
      notifyListeners();
    });
    _socket!.onConnectError((err) {
      debugPrint('[SocketService] ConnectError: $err');
    });
    _socket!.onError((err) {
      debugPrint('[SocketService] Error: $err');
    });
    _socket!.onReconnect((_) {
      debugPrint('[SocketService] Reconnected: ${_socket?.id}');
      notifyListeners();
    });

    _socket!.connect();
  }

  // ----- Room mgmt -----
  void joinRoom(String chatId) {
    if (!isConnected) return;
    _socket?.emit('join_room', chatId);
    debugPrint('[SocketService] join_room -> $chatId');
  }

  // Mark every message in the room as read on the server
  void markRead(String chatId) {
    if (!isConnected) return;
    _socket?.emit('mark_read', {'chatId': chatId});
    debugPrint('[SocketService] mark_read -> $chatId');
  }

  // ----- Send -----
  void sendMessage({
    required String chatId,
    required String recipientId,
    required String text,
    String? tempId,
  }) {
    if (!isConnected) return;
    _socket?.emit('send_message', {
      'chatId': chatId,
      'recipientId': recipientId,
      'text': text,
      if (tempId != null) 'tempId': tempId,
    });
  }

  // ----- Listen helpers (typed names) -----
  void onReceive(void Function(dynamic) handler) {
    // Avoid duplicates on hot reload/rebuild
    _socket?.off('receive_message');
    _socket?.on('receive_message', handler);
  }

  void onAck(void Function(dynamic) handler) {
    _socket?.off('message_ack');
    _socket?.on('message_ack', handler);
  }

  void onErrorEvt(void Function(dynamic) handler) {
    _socket?.off('message_error');
    _socket?.on('message_error', handler);
  }

  void onStatus(void Function(dynamic) handler) {
    _socket?.off('message_status');
    _socket?.on('message_status', handler);
  }

  void onChatRead(void Function(dynamic) handler) {
    _socket?.off('chat_read');
    _socket?.on('chat_read', handler);
  }

  // Back-compat (your code used this name in a few places)
  void listenForMessage(Function(dynamic) handler) => onReceive(handler);

  // Generic event attach (handy in experiments)
  void onEvent(String event, void Function(dynamic) handler) {
    _socket?.off(event);
    _socket?.on(event, handler);
  }

  // Generic off
  void offEvent(String event) => _socket?.off(event);

  @override
  void dispose() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    super.dispose();
  }
}
