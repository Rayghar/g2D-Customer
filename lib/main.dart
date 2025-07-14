// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import flutter_dotenv
import 'package:flutter_easyloading/flutter_easyloading.dart'; // Import flutter_easyloading

import 'services/fcm_service.dart'; // <<< IMPORT THE NEW SERVICE

// Screen imports
import 'screens/auth/complete_profile_screen.dart'; // Import the new screen
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
import 'providers/auth_provider.dart'; // <<< ADD THIS LINE (Please verify the path is correct for your project)
import 'screens/customer/payment_screen.dart'; // NEW: OPay payment screen
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
import 'screens/auth/otp_verification_screen.dart'; // Corrected import

// Provider and model imports
import 'providers/theme_provider.dart';
import 'models/address_model.dart';
import 'models/deal_model.dart';
import 'models/admin/admin_promotion_model.dart';
import 'models/admin/faq_item_model.dart';
import 'models/user.dart' as app_user;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file with error handling
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('Successfully loaded .env file.');
  } catch (e) {
    debugPrint('Failed to load .env file: $e');
    // Fallback to default Stripe key or handle gracefully
  }

  // Firebase initialization
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: kIsWeb
            ? const FirebaseOptions(
                apiKey: "YOUR_WEB_API_KEY",
                appId: "YOUR_WEB_APP_ID",
                messagingSenderId: "YOUR_WEB_MESSAGING_SENDER_ID",
                projectId: "YOUR_PROJECT_ID",
                authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
                storageBucket: "YOUR_PROJECT_ID.appspot.com",
              )
            : null, // Mobile uses google-services.json / GoogleService-Info.plist
      );
      debugPrint('Firebase initialized successfully.');
    } else {
      debugPrint('Firebase already initialized.');
    }
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Configure EasyLoading
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = Colors.yellow
    ..backgroundColor = Colors.green
    ..indicatorColor = Colors.yellow
    ..textColor = Colors.yellow
    ..maskColor = Colors.blue.withOpacity(0.5)
    ..userInteractions = false
    ..dismissOnTap = false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
            create: (_) => AuthProvider()), // <<< AND THIS LINE

        // Add other providers as needed
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'PrimeJet Mobile',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.currentThemeMode,
      initialRoute: '/', // Set root route explicitly
      routes: {
        '/': (_) =>
            const CustomerLoginScreen(), // Map root route to SplashScreen
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
        debugPrint('=== onGenerateRoute ===');
        debugPrint('Route Name: ${settings.name}');
        debugPrint('Arguments: $args');

        // Handle root route explicitly in onGenerateRoute
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
                  lastOrderItems:
                      (args['lastOrderItems'] as List<Map<String, dynamic>>?),
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

          case PaymentScreen.routeName: // <<< ADD THIS NEW CASE
            if (args != null &&
                args.containsKey('orderId') &&
                args.containsKey('amount') &&
                args.containsKey('customer')) {
              return MaterialPageRoute(
                builder: (_) => PaymentScreen(
                  orderId: args['orderId'] as String,
                  amount: (args['amount'] as num).toDouble(),
                  customer: args['customer'] as app_user.User,
                  itemDescription: args['itemDescription'] as String?,
                  // Pass the Interswitch keys from your arguments
                  iswMerchantId: args['iswMerchantId'] as String?,
                  iswDomainId: args['iswDomainId'] as String?,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing required arguments for PaymentScreen");

          /* // NEW: Route for OPayPaymentScreen
          case OpayPaymentScreen.routeName: // Use the new OPay route name
            if (args != null &&
                args.containsKey('orderId') &&
                args.containsKey('amount') &&
                args.containsKey('customer') &&
                args.containsKey('opayPayParams')) {
              // Expect OPay PayParams
              return MaterialPageRoute(
                builder: (_) => OpayPaymentScreen(
                  // Use the new OPay screen
                  orderId: args['orderId'] as String,
                  amount: (args['amount'] as num).toDouble(),
                  itemDescription: args['itemDescription'] as String?,
                  customer: args['customer'] as app_user.User,
                  opayPayParams: args['opayPayParams']
                      as PayParams, // Cast to OPay PayParams
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing arguments for OpayPaymentScreen");
                */

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
                  showConfirmation:
                      (args['showConfirmation'] as bool?) ?? false,
                  customerId: args['customerId'] as String,
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
            if (args != null &&
                args.containsKey('orderId') &&
                args.containsKey('currentUserId') &&
                args.containsKey('recipientId') &&
                args.containsKey('recipientName')) {
              return MaterialPageRoute(
                builder: (_) => ChatScreen(
                  orderId: args['orderId'] as String,
                  currentUserId: args['currentUserId'] as String,
                  recipientId: args['recipientId'] as String,
                  recipientName: args['recipientName'] as String,
                  recipientPhotoUrl: args['recipientPhotoUrl'] as String?,
                  recipientPhoneNumber: args['recipientPhoneNumber'] as String?,
                ),
                settings: settings,
              );
            }
            return _buildErrorRoute(
                settings, "Missing arguments for ChatScreen");

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
                args.containsKey('initialStopStatus')) {
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
                ),
                settings: settings,
              );
            }
            debugPrint(
                '--- ERROR: Missing required arguments for DriverOrderDetailsScreen ---');
            debugPrint('Route Name: ${settings.name}');
            debugPrint('Provided Arguments: $args');
            debugPrint(
                'Expected: orderId, customerName, fullAddress, driverId, cylinderDetails, initialStopStatus');
            return _buildErrorRoute(settings,
                "Missing required arguments for DriverOrderDetailsScreen");

          default:
            debugPrint('Unhandled route in onGenerateRoute: ${settings.name}');
            return _buildErrorRoute(
                settings, "Route not found: ${settings.name}");
        }
      },
      builder: EasyLoading.init(), // Initialize EasyLoading here
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
