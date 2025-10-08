// lib/services/socket_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import './auth_service.dart';
import '../models/message.dart';
import '../models/user.dart' as app_user;

class SocketService with ChangeNotifier {
  IO.Socket? _socket;
  final AuthService _auth = AuthService();

  static const String _socketUrl = 'https://primejet-backend.onrender.com';

  final Map<String, List<Message>> _messagesByChat = {};
  final Set<String> _joinedChats = {};

  bool get isConnected => _socket?.connected == true;

  List<Message> messagesFor(String chatId) =>
      List.unmodifiable(_messagesByChat[chatId] ?? const []);

  Future<void> _ensureSocket() async {
    if (_socket != null && _socket!.connected) return;
    if (_socket != null && _socket!.disconnected) {
      _socket!.connect();
      return;
    }

    final token = await _auth.getToken();
    if (token == null) {
      debugPrint('[SocketService] No auth token; cannot connect.');
      return;
    }

    _socket = IO.io(
      _socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setPath('/socket.io')
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(5000)
          .setTimeout(20000)
          .build(),
    );

    _socket!.on('connect', (_) {
      debugPrint('[SocketService] Connected: ${_socket!.id}');
      notifyListeners();
      for (final chatId in _joinedChats) {
        _socket!.emit('join_room', chatId);
      }
    });
    _socket!.on('disconnect', (_) {
      debugPrint('[SocketService] Disconnected');
      notifyListeners();
    });
    _socket!.on('connect_error',
        (e) => debugPrint('[SocketService] Connect error: $e'));
    _socket!.on('error', (e) => debugPrint('[SocketService] Error: $e'));
    _socket!.on('reconnect', (attempt) {
      debugPrint('[SocketService] Reconnected after $attempt attempts');
      notifyListeners();
    });

    // --- Chat Listeners ---
    _socket!.on('receive_message', (data) {
      final msg = Message.fromJson(data);
      final list = _messagesByChat[msg.chatId] ?? <Message>[];
      list.add(msg);
      _messagesByChat[msg.chatId] = list;
      notifyListeners();
    });
    _socket!.on('message_ack', (data) {
      final serverId = data['serverId'];
      final tempId = data['tempId'];
      var changed = false;
      for (final entry in _messagesByChat.entries) {
        final list = entry.value;
        for (int i = 0; i < list.length; i++) {
          if (list[i].id == tempId) {
            list[i] = list[i].copyWith(id: serverId, status: 'sent');
            changed = true;
            break;
          }
        }
      }
      if (changed) notifyListeners();
    });
    _socket!.on('message_delivered', (data) {
      final id = data['id'];
      var changed = false;
      for (final entry in _messagesByChat.entries) {
        final list = entry.value;
        for (int i = 0; i < list.length; i++) {
          if (list[i].id == id && list[i].status == 'sent') {
            list[i] = list[i].copyWith(status: 'delivered');
            changed = true;
          }
        }
      }
      if (changed) notifyListeners();
    });
    _socket!.on('chat_read', (data) {
      final chatId = data['chatId'];
      final list = _messagesByChat[chatId] ?? const <Message>[];
      var changed = false;
      for (int i = 0; i < list.length; i++) {
        if (list[i].status != 'read') {
          list[i] = list[i].copyWith(status: 'read');
          changed = true;
        }
      }
      if (changed) notifyListeners();
    });
  }

  Future<void> connect() async {
    await _ensureSocket();
    if (!_socket!.connected) {
      _socket!.connect();
    }
  }

  Future<void> joinChat(String? chatId) async {
    if (chatId == null || chatId.isEmpty) return; // Add null/empty check
    await connect();
    _socket!.emit('join_room', chatId);
    _joinedChats.add(chatId);
  }

  void seedHistory(String chatId, List<Message> history) {
    _messagesByChat[chatId] = [...history];
    notifyListeners();
  }

  void sendMessage({
    required String chatId,
    required String text,
    required String senderId,
    String? recipientId,
  }) {
    if (text.trim().isEmpty || !isConnected) return;

    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = Message(
      id: tempId,
      chatId: chatId,
      senderId: senderId,
      recipientId: recipientId ?? '', // Ensure recipientId is not null
      text: text.trim(),
      status: 'sending',
      createdAt: DateTime.now(),
    );

    final list = _messagesByChat[chatId] ?? <Message>[];
    list.add(optimistic);
    _messagesByChat[chatId] = list;
    notifyListeners();

    _socket?.emit('send_message', {
      'chatId': chatId,
      'recipientId': recipientId,
      'text': text.trim(),
      'tempId': tempId,
    });
  }

  void markRead(String chatId) {
    _socket?.emit('mark_read', {'chatId': chatId});
  }

  // PRESERVED for other real-time features like order status updates
  void onEvent(String event, void Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void offEvent(String event) {
    _socket?.off(event);
  }

  @override
  void dispose() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    super.dispose();
  }
}
