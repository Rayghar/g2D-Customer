// File: lib/main.dart
// ADVISORY: Sentry initialization is now handled directly in the main function.

import 'providers/order_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // ADDED
import 'firebase_options.dart'; // Keep this import
import 'package:provider/provider.dart';
import './providers/notification_provider.dart';

// Screen imports
import 'screens/auth/complete_profile_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/customer_login_screen.dart';
import 'screens/auth/customer_register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/driver_login_screen.dart';
import 'screens/auth/driver_register_screen.dart';
import 'screens/auth/admin_login_screen.dart';
import 'screens/auth/admin_register_screen.dart';
import 'screens/customer/customer_dashboard_screen.dart';
import 'screens/customer/order_placement_screen.dart';
import 'screens/customer/order_summary_screen.dart';
import 'screens/customer/order_details_screen.dart';
import 'screens/customer/track_driver_screen.dart';
import 'screens/customer/feedback_screen.dart';
import 'screens/customer/chat_screen.dart';
import 'screens/customer/notification_screen.dart';
import 'screens/customer/location_history_screen.dart';
import 'screens/customer/payment_screen.dart';
import 'screens/customer/address_list_screen.dart';
import 'screens/customer/add_edit_address_screen.dart';
import 'screens/customer/promotion_details_screen.dart';
import 'screens/customer/profile/wallet_screen.dart';
import 'screens/customer/profile/edit_profile_screen.dart';
import 'screens/more/refer_friend_screen.dart';
import 'screens/more/help_support_screen.dart';
import 'screens/more/about_us_screen.dart';
import 'screens/settings/notification_settings_screen.dart';
import 'screens/settings/payment_methods_screen.dart';
import 'screens/driver/driver_dashboard_screen.dart';
import 'screens/driver/driver_order_details_screen.dart';
import 'screens/driver/driver_dashboard_home_screen.dart';
import 'screens/driver/driver_profile_screen.dart';
import 'screens/driver/driver_messages_list_screen.dart';
import 'screens/driver/driver_stats_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_order_list_screen.dart';
import 'screens/admin/admin_customer_list_screen.dart';
import 'screens/admin/admin_driver_list_screen.dart';
import 'screens/admin/admin_promotions_management_screen.dart';
import 'screens/admin/admin_faq_management_screen.dart';
import 'screens/admin/admin_system_config_screen.dart';
import 'screens/admin/admin_reports_screen.dart';
import 'screens/admin/admin_run_management_screen.dart';
import 'screens/admin/admin_add_edit_user_screen.dart';
import 'screens/admin/admin_order_details_screen.dart';
import 'screens/admin/admin_customer_details_screen.dart';
import 'screens/admin/admin_driver_details_screen.dart';
import 'screens/admin/admin_add_edit_faq_screen.dart';
import 'screens/admin/admin_add_edit_promotion_screen.dart';
import 'screens/admin/admin_active_run_details_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // <-- ADD THIS IMPORT

// Provider and model imports
import 'providers/theme_provider.dart';
import 'providers/order_provider.dart'; // This was already here
import 'services/socket_service.dart'; // ✅ NEW: Import SocketService
import 'models/address_model.dart';
import 'models/deal_model.dart';
import 'models/admin/admin_promotion_model.dart';
import 'models/admin/faq_item_model.dart';
import 'models/order.dart' as app_order;
import 'models/user.dart' as app_user;
import 'services/fcm_service.dart';

// This function MUST be a top-level function (outside of any class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  // Ensure Flutter bindings are initialized.
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set the background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Sentry directly, wrapping the app launch.
  await SentryFlutter.init(
    (options) {
      options.dsn = dotenv.env['SENTRY_DSN'];
      options.tracesSampleRate = 1.0;
    },
    appRunner: () {
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => OrderProvider()),
            ChangeNotifierProvider(
                create: (_) =>
                    SocketService()), // ✅ NEW: Add SocketService provider
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: const MyApp(),
        ),
      );
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final fcmService = FcmService();
    fcmService.initializeFirebaseMessaging(context);

    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'PrimeJet Mobile',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.currentThemeMode,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        SplashScreen.routeName: (_) => const SplashScreen(),
        CustomerLoginScreen.routeName: (_) => const CustomerLoginScreen(),
        CustomerRegisterScreen.routeName: (_) => const CustomerRegisterScreen(),
        ForgotPasswordScreen.routeName: (_) => const ForgotPasswordScreen(),
        ResetPasswordScreen.routeName: (_) => const ResetPasswordScreen(),
        DriverLoginScreen.routeName: (_) => const DriverLoginScreen(),
        DriverRegisterScreen.routeName: (_) => const DriverRegisterScreen(),
        AdminLoginScreen.routeName: (_) => const AdminLoginScreen(),
        AdminRegisterScreen.routeName: (_) => const AdminRegisterScreen(),
        CustomerDashboardScreen.routeName: (_) =>
            const CustomerDashboardScreen(),
        NotificationScreen.routeName: (_) => const NotificationScreen(),
        HelpSupportScreen.routeName: (_) => const HelpSupportScreen(),
        AboutUsScreen.routeName: (_) => const AboutUsScreen(),
        NotificationSettingsScreen.routeName: (_) =>
            const NotificationSettingsScreen(),
        PaymentMethodsScreen.routeName: (_) => const PaymentMethodsScreen(),
        DriverDashboardScreen.routeName: (_) => const DriverDashboardScreen(),
        AdminDashboardScreen.routeName: (_) => const AdminDashboardScreen(),
        AdminOrderListScreen.routeName: (_) => const AdminOrderListScreen(),
        AdminCustomerListScreen.routeName: (_) =>
            const AdminCustomerListScreen(),
        AdminDriverListScreen.routeName: (_) => const AdminDriverListScreen(),
        AdminPromotionManagementScreen.routeName: (_) =>
            const AdminPromotionManagementScreen(),
        AdminFaqManagementScreen.routeName: (_) =>
            const AdminFaqManagementScreen(),
        AdminSystemConfigScreen.routeName: (_) =>
            const AdminSystemConfigScreen(),
        AdminReportsScreen.routeName: (_) => const AdminReportsScreen(),
        AdminRunManagementScreen.routeName: (_) =>
            const AdminRunManagementScreen(),
      },
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;

        Sentry.addBreadcrumb(Breadcrumb(
          message: 'Navigating to route: ${settings.name}',
          level: SentryLevel.info,
          data: {'arguments': args.toString()},
        ));

        if (settings.name == '/') {
          return MaterialPageRoute(
            builder: (_) => const SplashScreen(),
            settings: settings,
          );
        }

        switch (settings.name) {
          case OrderPlacementScreen.routeName:
            if (args != null && args.containsKey('customerId')) {
              return MaterialPageRoute(
                builder: (_) => OrderPlacementScreen(
                  isRefill: (args['isRefill'] as bool?) ?? false,
                  refillCylinderSize: args['refillCylinderSize'] as String?,
                  prefilledPromoCode: args['prefilledPromoCode'] as String?,
                  initialAddress: args['initialAddress'] as AddressModel?,
                  customerId: args['customerId'] as String,
                  preselectedCylinderIdFromDeal:
                      args['preselectedCylinderIdFromDeal'] as String?,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing customerId for OrderPlacementScreen");

          case OtpVerificationScreen.routeName:
            if (args != null && args.containsKey('email')) {
              return MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(
                  email: args['email'] as String,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(settings, "Missing email for OTP Screen");

          case CompleteProfileScreen.routeName:
            if (args != null && args.containsKey('userName')) {
              return MaterialPageRoute(
                builder: (_) => CompleteProfileScreen(
                  userName: args['userName'] as String,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing user name for Complete Profile Screen");

          case PaymentScreen.routeName:
            // FIX: Ensure all four required arguments are checked
            if (args != null &&
                args.containsKey('orderId') &&
                args.containsKey('amount') &&
                args.containsKey('customer') &&
                args.containsKey('order')) {
              return MaterialPageRoute(
                builder: (_) => PaymentScreen(
                  orderId: args['orderId'] as String,
                  amount: (args['amount'] as num).toDouble(),
                  customer: args['customer'] as app_user.User,
                  order: args['order'] as app_order.Order,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing arguments for PaymentScreen");

          case OrderDetailsScreen.routeName:
            if (args != null &&
                args.containsKey('orderId') &&
                args.containsKey('customerId')) {
              return MaterialPageRoute(
                builder: (_) => OrderDetailsScreen(
                  orderId: args['orderId'] as String,
                  customerId: args['customerId'] as String,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(settings,
                "Missing orderId or customerId for OrderDetailsScreen");

          case OrderSummaryScreen.routeName:
            if (args != null &&
                args.containsKey('orderId') &&
                args.containsKey('customerId')) {
              return MaterialPageRoute(
                builder: (_) => OrderSummaryScreen(
                  orderId: args['orderId'] as String,
                  customerId: args['customerId'] as String,
                  showConfirmation:
                      (args['showConfirmation'] as bool?) ?? false,
                  transactionRef: args['transactionRef'] as String?,
                  isVerifyingPayment:
                      (args['isVerifyingPayment'] as bool?) ?? false,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing arguments for OrderSummaryScreen");

          case TrackDriverScreen.routeName:
            if (args != null &&
                args.containsKey('orderId') &&
                args.containsKey('customerId')) {
              return MaterialPageRoute(
                builder: (_) => TrackDriverScreen(
                  orderId: args['orderId'] as String,
                  customerId: args['customerId'] as String,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing arguments for TrackDriverScreen");

          case FeedbackScreen.routeName:
            if (args != null && args.containsKey('orderId')) {
              return MaterialPageRoute(
                builder: (_) =>
                    FeedbackScreen(orderId: args['orderId'] as String),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing orderId for FeedbackScreen");

          case AddressListScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => AddressListScreen(
                isSelectingAddress:
                    (args?['isSelectingAddress'] as bool?) ?? false,
              ),
              settings: settings,
            );

          case AddEditAddressScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => AddEditAddressScreen(
                address: args?['address'] as AddressModel?,
              ),
              settings: settings,
            );

          case PromotionDetailsScreen.routeName:
            if (args != null &&
                args.containsKey('promotion') &&
                args['promotion'] is DealModel &&
                args.containsKey('customerId')) {
              return MaterialPageRoute(
                builder: (_) => PromotionDetailsScreen(
                  promotion: args['promotion'] as DealModel,
                  customerId: args['customerId'] as String,
                  initialAddress: args['initialAddress'] as AddressModel?,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(settings,
                "Missing or incorrect arguments for PromotionDetailsScreen");

          case ReferFriendScreen.routeName:
            if (args != null && args.containsKey('customerId')) {
              return MaterialPageRoute(
                builder: (_) =>
                    ReferFriendScreen(customerId: args['customerId'] as String),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing customerId for ReferFriendScreen");

          case WalletScreen.routeName:
            if (args != null && args.containsKey('customerId')) {
              return MaterialPageRoute(
                builder: (_) =>
                    WalletScreen(customerId: args['customerId'] as String),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing customerId for WalletScreen");

          case EditProfileScreen.routeName:
            if (args != null && args.containsKey('customerId')) {
              return MaterialPageRoute(
                builder: (_) =>
                    EditProfileScreen(customerId: args['customerId'] as String),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing customerId for EditProfileScreen");

          case ChatScreen.routeName:
            {
              if (args == null) {
                return _buildErrorRoute(
                    settings, 'Missing arguments for ChatScreen');
              }

              final String? chatId =
                  (args['orderId'] ?? args['chatId'])?.toString();
              final String? currentUserId = args['currentUserId']?.toString();
              final String? recipientId = args['recipientId']?.toString();
              final String? recipientName = args['recipientName']?.toString();

              // Validate that all REQUIRED fields are not null before proceeding
              if (chatId == null ||
                  currentUserId == null ||
                  recipientId == null ||
                  recipientName == null) {
                return _buildErrorRoute(
                  settings,
                  'Missing required arguments for ChatScreen. '
                  'Expected: chatId, currentUserId, recipientId, recipientName. '
                  'Received: $args',
                );
              }

              // Now we can safely create the screen because we know the required args are non-null
              return MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: chatId, // Guaranteed non-null
                  currentUserId: currentUserId, // Guaranteed non-null
                  recipientId: recipientId, // Guaranteed non-null
                  recipientName: recipientName, // Guaranteed non-null
                  recipientPhotoUrl: args['recipientPhotoUrl']?.toString(),
                  recipientPhoneNumber:
                      args['recipientPhoneNumber']?.toString(),
                ),
                settings: settings,
              );
            }

          case LocationHistoryScreen.routeName:
            if (args != null &&
                args.containsKey('orderId') &&
                args.containsKey('customerId')) {
              return MaterialPageRoute(
                builder: (_) => LocationHistoryScreen(
                  orderId: args['orderId'] as String,
                  customerId: args['customerId'] as String,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing arguments for LocationHistoryScreen");

          case AdminAddEditUserScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => AdminAddEditUserScreen(
                initialRole: args?['initialRole'] as String?,
              ),
              settings: settings,
            );

          case AdminAddEditFaqScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => AdminAddEditFaqScreen(
                faq: args?['faq'] as FaqItemModel?,
              ),
              settings: settings,
            );

          case AdminAddEditPromotionScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => AdminAddEditPromotionScreen(
                promotion: args?['promotion'] as AdminPromotionModel?,
              ),
              settings: settings,
            );

          case AdminCustomerDetailsScreen.routeName:
            if (args != null && args.containsKey('customerId')) {
              return MaterialPageRoute(
                builder: (_) => AdminCustomerDetailsScreen(
                  customerId: args['customerId'] as String,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing customerId for AdminCustomerDetailsScreen");

          case AdminDriverDetailsScreen.routeName:
            if (args != null && args.containsKey('driverId')) {
              return MaterialPageRoute(
                builder: (_) => AdminDriverDetailsScreen(
                  driverId: args['driverId'] as String,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing driverId for AdminDriverDetailsScreen");

          case AdminOrderDetailsScreen.routeName:
            if (args != null && args.containsKey('orderId')) {
              return MaterialPageRoute(
                builder: (_) => AdminOrderDetailsScreen(
                  orderId: args['orderId'] as String,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing orderId for AdminOrderDetailsScreen");

          case AdminActiveRunDetailsScreen.routeName:
            if (args != null && args.containsKey('runId')) {
              return MaterialPageRoute(
                builder: (_) => AdminActiveRunDetailsScreen(
                  runId: args['runId'] as String,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing runId for AdminActiveRunDetailsScreen");

          case DriverOrderDetailsScreen.routeName:
            if (args != null &&
                args.containsKey('orderId') &&
                args.containsKey('customerName') &&
                args.containsKey('fullAddress') &&
                args.containsKey('driverId') &&
                args.containsKey('cylinderDetails') &&
                args.containsKey('initialStopStatus') &&
                args.containsKey('runId') &&
                args.containsKey('stopId') &&
                args.containsKey('paymentMethod') &&
                args.containsKey('amountToCollect')) {
              return MaterialPageRoute(
                builder: (_) => DriverOrderDetailsScreen(
                  orderId: args['orderId'] as String,
                  customerName: args['customerName'] as String,
                  fullAddress: args['fullAddress'] as String,
                  driverId: args['driverId'] as String,
                  cylinderDetails: args['cylinderDetails'] as String,
                  initialStopStatus: args['initialStopStatus'] as String,
                  customerId: args['customerId'] as String?,
                  customerPhoneNumber: args['customerPhoneNumber'] as String?,
                  sequenceNumber: args['sequenceNumber'] as int?,
                  //runId: args['runId'] as String,
                  //stopId: args['stopId'] as String,
                  //paymentMethod: args['paymentMethod'] as String,
                  //amountToCollect: (args['amountToCollect'] as num).toDouble(),
                ),
                settings: settings,
              );
            }
            // This error message is now more accurate
            return _buildErrorRoute(settings,
                "Missing required arguments for DriverOrderDetailsScreen (requires runId, stopId, paymentMethod, and amountToCollect).");
        }
        // This is the fallback for any unhandled routes.
        return _buildErrorRoute(settings, "Route not found or unhandled.");
      },
    );
  }

  MaterialPageRoute _buildErrorRoute(RouteSettings settings, String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Navigation Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 50),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Route: "${settings.name}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                if (settings.arguments != null)
                  Text(
                    'Arguments: ${settings.arguments}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
