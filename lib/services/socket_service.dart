// File: lib/services/socket_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import './auth_service.dart';
import '../models/message.dart';

class SocketService with ChangeNotifier {
  IO.Socket? _socket;
  final AuthService _auth = AuthService();

  static const String _socketUrl = 'https://primejet-backend.onrender.com';

  final Map<String, List<Message>> _messagesByChat = {};
  final Set<String> _joinedChats = {};
  bool _isListening = false;

  bool get isConnected => _socket?.connected ?? false;

  List<Message> messagesFor(String chatId) =>
      List.unmodifiable(_messagesByChat[chatId] ?? const []);

  Future<void> _ensureSocket() async {
    if (_socket != null) return;

    final token = await _auth.getToken();
    if (token == null) {
      debugPrint('[SocketService] No auth token; connection deferred.');
      return;
    }

    _socket = IO.io(
      _socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token}) // Required by server auth middleware
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[SocketService] Connected: ${_socket!.id}');
      for (final chatId in _joinedChats) {
        _socket!.emit('join_room', chatId);
      }
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      debugPrint('[SocketService] Disconnected');
      notifyListeners();
    });

    _socket!
        .onConnectError((e) => debugPrint('[SocketService] Connect Error: $e'));

    _listenForChatEvents();
  }

  void _listenForChatEvents() {
    if (_isListening || _socket == null) return;

    _socket!.on('receive_message', (payload) {
      try {
        final msg = Message.fromJson(Map<String, dynamic>.from(payload));
        final list = _messagesByChat.putIfAbsent(msg.chatId, () => []);

        if (!list.any((m) => m.id == msg.id)) {
          list.add(msg);
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[SocketService] receive_message parse error: $e');
      }
    });

    _socket!.on('message_ack', (payload) {
      final data = Map<String, dynamic>.from(payload);
      final chatId = data['chatId'] as String?;
      final tempId = data['tempId'] as String?;
      final serverId = data['messageId'] as String?;
      if (chatId == null || tempId == null || serverId == null) return;

      final list = _messagesByChat[chatId];
      if (list == null) return;

      final idx = list.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(id: serverId, status: 'sent');
        notifyListeners();
      }
    });

    _socket!.on('message_status', (payload) {
      final data = Map<String, dynamic>.from(payload);
      final chatId = data['chatId'] as String?;
      final messageId = data['messageId'] as String?;
      final status = data['status'] as String?;
      if (chatId == null || messageId == null || status == null) return;

      final list = _messagesByChat[chatId];
      if (list == null) return;

      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx != -1 && list[idx].status != status) {
        list[idx] = list[idx].copyWith(status: status);
        notifyListeners();
      }
    });

    _socket!.on('chat_read', (payload) async {
      final data = Map<String, dynamic>.from(payload);
      final chatId = data['chatId'] as String?;
      if (chatId == null) return;

      final list = _messagesByChat[chatId];
      if (list == null) return;

      final currentUserId = await _auth.getUserId();
      if (currentUserId == null) return;

      bool changed = false;
      for (var i = 0; i < list.length; i++) {
        if (list[i].senderId == currentUserId && list[i].status != 'read') {
          list[i] = list[i].copyWith(status: 'read');
          changed = true;
        }
      }
      if (changed) notifyListeners();
    });

    _isListening = true;
  }

  Future<void> connect() async {
    await _ensureSocket();
    if (_socket != null && _socket!.disconnected) {
      _socket!.connect();
    }
  }

  Future<void> joinChat(String chatId) async {
    await connect();
    if (_joinedChats.contains(chatId)) return;
    _socket!.emit('join_room', chatId);
    _joinedChats.add(chatId);
    debugPrint('[SocketService] Joined room: $chatId');
  }

  void seedHistory(String chatId, List<Message> history) {
    final list = _messagesByChat.putIfAbsent(chatId, () => []);
    final knownIds = list.map((m) => m.id).toSet();
    for (final message in history) {
      if (!knownIds.contains(message.id)) {
        list.add(message);
      }
    }
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();
  }

  void sendMessage({
    required String chatId,
    required String text,
    required String senderId,
    required String recipientId,
  }) {
    if (text.trim().isEmpty) return;

    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final optimisticMessage = Message(
      id: tempId,
      chatId: chatId,
      senderId: senderId,
      recipientId: recipientId,
      text: text.trim(),
      status: 'sending',
      createdAt: DateTime.now().toUtc(),
    );

    final list = _messagesByChat.putIfAbsent(chatId, () => []);
    list.add(optimisticMessage);
    notifyListeners();

    _socket?.emit('send_message', {
      'chatId': chatId,
      'text': text.trim(),
      'tempId': tempId,
    });
  }

  void markRead(String chatId) {
    _socket?.emit('mark_read', {'chatId': chatId});
  }

  void onEvent(String event, void Function(dynamic) handler) =>
      _socket?.on(event, handler);
  void offEvent(String event) => _socket?.off(event);

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}
