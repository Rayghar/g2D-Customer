// lib/services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import './auth_service.dart';

class SocketService with ChangeNotifier {
  IO.Socket? _socket;
  final AuthService _authService = AuthService();

  // Replace with your Render backend URL
  static const String _socketUrl = 'https://primejet-backend.onrender.com';

  void connect() async {
    final token = await _authService.getToken();
    if (token == null) {
      print('[SocketService] No auth token found, cannot connect.');
      return;
    }

    // Disconnect if already connected before creating a new instance
    if (_socket != null && _socket!.connected) {
      _socket!.disconnect();
    }

    _socket = IO.io(_socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': token} // Send JWT for authentication
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      print(
          '[SocketService] Connected successfully. Socket ID: ${_socket!.id}');
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      print('[SocketService] Disconnected.');
      notifyListeners();
    });

    _socket!.onError((error) {
      print('[SocketService] Connection Error: $error');
    });
  }

  void joinRoom(String chatId) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('join_room', chatId);
    print('[SocketService] Emitted join_room for: $chatId');
  }

  void sendMessage(String chatId, String recipientId, String text) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('send_message', {
      'chatId': chatId,
      'recipientId': recipientId,
      'text': text,
    });
  }

  void listenForMessage(Function(dynamic) handler) {
    if (_socket == null) return;
    _socket!.on('receive_message', handler);
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
