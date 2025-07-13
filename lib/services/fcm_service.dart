// File: lib/services/fcm_service.dart

import 'package:firebase_messaging/firebase_messaging.dart'; // Add Dependency
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart'; // For Navigator, Snackbar, etc.
import 'package:google_fonts/google_fonts.dart'; // For text styling
import 'package:provider/provider.dart'; // For ThemeProvider and AuthService

import '../services/api_service.dart'; // For sending token to backend
import '../providers/auth_provider.dart'; // To check if user is logged in
import '../providers/theme_provider.dart'; // For snackbar styling

class FcmService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();

  // Constructor can take a GlobalKey<NavigatorState> if root navigation is needed
  final GlobalKey<NavigatorState>? navigatorKey;

  FcmService({this.navigatorKey});

  Future<void> initializeFirebaseMessaging(BuildContext context) async {
    // 1. Request permission for notifications
    await _requestPermissions();

    // 2. Get and save the FCM token
    await _getTokenAndSave(context);

    // 3. Handle foreground messages
    _setupForegroundMessageHandling(context);

    // 4. Handle background messages (requires top-level function)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Handle initial message (when app is opened from a terminated state)
    _setupInitialMessageHandling(context);

    // 6. Handle messages when app is in background but not terminated
    _setupOnMessageOpenedAppHandling(context);
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('User granted permission: ${settings.authorizationStatus}');
    }
  }

  Future<void> _getTokenAndSave(BuildContext context) async {
    String? token = await _firebaseMessaging.getToken();
    if (kDebugMode) {
      print('FCM Token: $token');
    }

    if (token != null) {
      // Only send token to backend if user is authenticated
      // We use Provider.of<AuthProvider>(context, listen: false) to get current auth state
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        try {
          await _apiService.registerFcmToken(token);
          if (kDebugMode) {
            print('FCM Token successfully sent to backend.');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to send FCM token to backend: $e');
          }
          // Optionally, retry later or log error to analytics
        }
      } else {
        if (kDebugMode) {
          print('User not authenticated, deferring FCM token registration.');
        }
      }
    }
  }

  // Call this after a user successfully logs in
  Future<void> reRegisterTokenOnLogin(BuildContext context) async {
    await _getTokenAndSave(context);
  }

  // Call this if a user logs out (optional, to remove token from device's list on backend)
  Future<void> removeTokenOnLogout(BuildContext context) async {
    // Implement API call to remove specific token from user's fcmTokens array on backend
    // This typically involves sending the current token to a DELETE or PUT endpoint.
    // For simplicity, we'll just delete the token locally.
    await _firebaseMessaging.deleteToken();
    if (kDebugMode) {
      print('FCM Token deleted locally on logout.');
    }
  }

  void _setupForegroundMessageHandling(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
      }

      _showLocalNotification(context, message);
    });
  }

  void _setupInitialMessageHandling(BuildContext context) async {
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print(
            'App opened from terminated state by FCM: ${initialMessage.data}');
      }
      _handleNotificationClick(context, initialMessage);
    }
  }

  void _setupOnMessageOpenedAppHandling(BuildContext context) {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('App opened from background by FCM: ${message.data}');
      }
      _handleNotificationClick(context, message);
    });
  }

  void _showLocalNotification(BuildContext context, RemoteMessage message) {
    // Use a custom snackbar for in-app notifications
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.notification?.title ?? 'Notification',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (message.notification?.body != null)
              Text(
                message.notification!.body!,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        backgroundColor: themeProvider.gas2doorPrimaryBlue.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(
            16, 0, 16, 80), // Position above bottom navigation bar
        action: SnackBarAction(
          label: 'VIEW',
          textColor: themeProvider.gas2doorTeal,
          onPressed: () {
            _handleNotificationClick(context, message);
          },
        ),
      ),
    );
  }

  void _handleNotificationClick(BuildContext context, RemoteMessage message) {
    final String? screen = message.data['screen'];
    if (screen != null && navigatorKey?.currentState != null) {
      // Example: navigate to a specific screen based on data payload
      // You'll need to define your routes appropriately
      if (screen == 'notifications_screen') {
        navigatorKey!.currentState!
            .pushNamed('/notifications'); // Assuming a route '/notifications'
      } else if (screen == 'order_details' && message.data['orderId'] != null) {
        navigatorKey!.currentState!.pushNamed('/order_details',
            arguments: {'orderId': message.data['orderId']});
      }
      // Add more specific navigation logic as needed
    } else {
      if (kDebugMode) {
        print('No specific screen to navigate to or navigatorKey is null.');
      }
      // Default: maybe navigate to the main dashboard or notifications list
      navigatorKey?.currentState?.pushNamed('/notifications'); // Fallback
    }
  }
}

// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're using other Firebase services in the background, you'll need to initialize them.
  // await Firebase.initializeApp(); // Uncomment if Firebase not already initialized in main isolate

  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
    print('Message data: ${message.data}');
  }
  // You can perform heavy lifting here, like data synchronization, but keep it minimal.
  // Note: UI updates are generally not possible from here.
  // Local notifications should be handled by a package like flutter_local_notifications if needed.
}
