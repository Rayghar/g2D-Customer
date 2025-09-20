import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import './auth_service.dart';
import './api_service.dart';

// Top-level background handler (must be a global function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // You could do lightweight logging here if needed.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _auth = AuthService();
  final _api = ApiService();

  String? _lastRegisteredToken; // to avoid spamming backend
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Firebase.initializeApp();

    // Background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // iOS permission
    if (Platform.isIOS) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[Push] iOS permission: ${settings.authorizationStatus}');
    }

    // Android 13+ notifications permission request is done by FLN on show,
    // but you may want to request explicitly in-app:
    if (Platform.isAndroid) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Local notifications (for foreground popups)
    const channel = AndroidNotificationChannel(
      'chat_default_channel',
      'Chat notifications',
      description: 'Foreground chat notifications',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iOSInit),
      onDidReceiveNotificationResponse: (resp) {
        // Handle tap on local notification (foreground)
        // You can deep-link to a chat using payload if you set it below.
      },
    );

    // Foreground messages -> show local notification bubble
    FirebaseMessaging.onMessage.listen((RemoteMessage m) async {
      final n = m.notification;
      if (n != null) {
        await _local.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          n.title ?? 'New message',
          n.body ?? '',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'chat_default_channel',
              'Chat notifications',
              channelDescription: 'Foreground chat notifications',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: m.data['chatId'], // for deep linking
        );
      }
    });

    // App opened from background by tapping a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
      // You can navigate to specific chat using m.data['chatId']
      // e.g., Navigator.of(context).pushNamed('/chat', arguments: {...})
      debugPrint('[Push] onMessageOpenedApp -> ${m.data}');
    });

    _initialized = true;
  }

  /// Call after login (user is authenticated) or whenever you need to ensure registration.
  Future<void> registerWithBackend() async {
    final jwt = await _auth.getToken();
    if (jwt == null) return; // not logged in yet

    final token = await _messaging.getToken();
    debugPrint('[Push] FCM token: $token');
    if (token == null) return;

    // Debounce double-registers
    if (_lastRegisteredToken == token) return;

    try {
      await _api.registerFcmToken(token);
      _lastRegisteredToken = token;
    } catch (e) {
      debugPrint('[Push] register error: $e');
    }

    // Watch for token rotation
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('[Push] Token refreshed: $newToken');
      try {
        // Unregister old (optional), register new
        if (_lastRegisteredToken != null) {
          await _api.unregisterFcmToken(_lastRegisteredToken!);
        }
        await _api.registerFcmToken(newToken);
        _lastRegisteredToken = newToken;
      } catch (e) {
        debugPrint('[Push] refresh register error: $e');
      }
    });
  }

  /// Call on logout (before clearing JWT), and also when user explicitly disables notifications.
  Future<void> unregisterFromBackend() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _api.unregisterFcmToken(token);
      }
    } catch (e) {
      debugPrint('[Push] unregister error: $e');
    }
    _lastRegisteredToken = null;
  }
}
