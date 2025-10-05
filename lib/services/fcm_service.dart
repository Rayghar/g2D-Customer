// File: lib/services/fcm_service.dart
// UPDATE: Enabled sound, vibration, and high-priority display for foreground notifications.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../services/api_service.dart';
import '../screens/customer/notification_screen.dart';
import '../screens/customer/order_details_screen.dart';

// This function MUST be a top-level function (outside of any class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
}

class FcmService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _lastRegisteredToken;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  Future<void> initializeFirebaseMessaging(BuildContext context) async {
    await _initializeLocalNotifications();
    await _requestPermissions();
    await _getTokenAndSave(context);

    _firebaseMessaging.onTokenRefresh.listen((token) {
      if (kDebugMode) print('FCM Token refreshed: $token');
      _lastRegisteredToken = null;
      _getTokenAndSave(context);
    });

    _setupForegroundMessageHandling(context);
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode)
        print('App opened from background by FCM: ${message.data}');
      _handleNotificationClick(message);
    });
    _setupInitialMessageHandling();
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // ✅ FIX: Explicitly request permissions for foreground iOS notifications.
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null && details.payload!.isNotEmpty) {
          if (kDebugMode)
            print('Local notification tapped with payload: ${details.payload}');
          // You can parse details.payload (which is a string of the RemoteMessage data)
          // and call a navigation handler here if needed for foreground taps.
        }
      },
    );

    // ✅ FIX: Configure the Android channel for high importance, sound, and vibration.
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max, // This enables heads-up display.
      playSound: true,
      enableVibration: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (kDebugMode) {
      print('User granted permission: ${settings.authorizationStatus}');
    }
  }

  Future<void> _getTokenAndSave(BuildContext context) async {
    String? token;
    try {
      token = await _firebaseMessaging.getToken();
    } catch (e) {
      if (kDebugMode) print('Error getting FCM token: $e');
      return;
    }
    if (kDebugMode) print('FCM Token: $token');

    if (token != null && token != _lastRegisteredToken) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        try {
          await _apiService.registerFcmToken(token);
          _lastRegisteredToken = token;
          if (kDebugMode) print('FCM Token successfully sent to backend.');
        } catch (e) {
          if (kDebugMode) print('Failed to send FCM token to backend: $e');
        }
      } else {
        if (kDebugMode)
          print('User not authenticated, deferring FCM token registration.');
      }
    }
  }

  void _setupForegroundMessageHandling(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) print('Got a message whilst in the foreground!');
      final notification = message.notification;
      if (notification != null) {
        Provider.of<NotificationProvider>(context, listen: false)
            .fetchUnreadCount();

        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max, // Ensures heads-up display
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            ),
            iOS: DarwinNotificationDetails(
                presentSound: true), // Enables sound on iOS
          ),
          payload: message.data.toString(),
        );
      }
    });
  }

  void _setupInitialMessageHandling() async {
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode)
        print(
            'App opened from terminated state by FCM: ${initialMessage.data}');
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationClick(initialMessage);
      });
    }
  }

  void _handleNotificationClick(RemoteMessage message) {
    final String? screen = message.data['screen'];
    final currentState = navigatorKey.currentState;

    if (currentState == null) {
      if (kDebugMode)
        print('Navigator key is null, cannot handle notification click.');
      return;
    }

    if (screen == 'order_details' && message.data['orderId'] != null) {
      final authProvider =
          Provider.of<AuthProvider>(currentState.context, listen: false);
      if (authProvider.isAuthenticated) {
        currentState.pushNamed(
          OrderDetailsScreen.routeName,
          arguments: {
            'orderId': message.data['orderId'],
            'customerId': authProvider.currentUser?.id,
          },
        );
      }
    } else {
      currentState.pushNamed(NotificationScreen.routeName);
    }
  }

  void reRegisterTokenOnLogin(BuildContext context) {
    _lastRegisteredToken = null;
    _getTokenAndSave(context);
  }

  Future<void> unregisterTokenOnLogout() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _apiService.unregisterFcmToken(token);
        _lastRegisteredToken = null;
        if (kDebugMode)
          print('FCM Token successfully unregistered from backend.');
      }
    } catch (e) {
      if (kDebugMode) print('Failed to unregister FCM token from backend: $e');
    }
  }
}
