// File: lib/screens/customer/customer_dashboard_screen.dart
// UPDATE: Fixed the notification bubble to use the live unread count from NotificationProvider.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/fcm_service.dart';
import '../../providers/notification_provider.dart';

import '../../providers/theme_provider.dart';
import '../../models/address_model.dart';
import '../../models/user.dart' as app_user;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/button.dart';
import './home_screen.dart';
import './order_list_screen.dart';
import './deals_screen.dart';
import './profile_screen.dart';
import './notification_screen.dart';
import './address_list_screen.dart';
import '../../widgets/curve_painter.dart';

class CustomerDashboardShellData {
  final String customerId;
  final String customerFirstName;
  final AddressModel? currentDeliveryAddress;
  // This property is no longer used for the notification bubble,
  // but is kept to avoid breaking changes in other parts of the code that might use it.
  final bool hasUnreadNotifications;

  CustomerDashboardShellData({
    required this.customerId,
    required this.customerFirstName,
    this.currentDeliveryAddress,
    this.hasUnreadNotifications = false,
  });
}

class CustomerDashboardScreen extends StatefulWidget {
  static const String routeName = '/customer_dashboard';
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  late List<Widget> _screenOptions;
  bool _isLoadingShellData = true;
  String? _shellErrorMessage;
  CustomerDashboardShellData? _shellData;

  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final String _appDisplayName = "Gas2Door";

  @override
  void initState() {
    super.initState();
    _screenOptions = _buildScreenOptions(null);
    //FcmService().initializeFirebaseMessaging(context);
    _fetchShellData();

    WidgetsBinding.instance.addObserver(this);
    // Fetch the unread count when the dashboard first loads
    Provider.of<NotificationProvider>(context, listen: false)
        .fetchUnreadCount();

    /*// Listen for foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // ignore: avoid_print
      print('Foreground message received: ${message.notification?.title}');
      if (message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.notification!.title ?? 'New Notification'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                // TODO: navigate as needed using data payload
              },
            ),
          ),
        );
      }
    });*/
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When the app is resumed from the background, refresh the notification count
    if (state == AppLifecycleState.resumed) {
      print("[App Lifecycle] App resumed, fetching unread notification count.");
      Provider.of<NotificationProvider>(context, listen: false)
          .fetchUnreadCount();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _fetchShellData({bool isRefresh = false}) async {
    if (!isRefresh && mounted) {
      setState(() {
        _isLoadingShellData = true;
        _shellErrorMessage = null;
      });
    }

    try {
      String? customerId = await _authService.getUserId();
      app_user.User? userProfile;
      AddressModel? defaultAddress;
      bool hasNotifications = false; // This remains decoupled.

      if (customerId != null && customerId.isNotEmpty) {
        userProfile = await _authService.getCurrentUserProfile();

        if (userProfile != null) {
          if (userProfile.defaultAddressId != null &&
              userProfile.defaultAddressId!.isNotEmpty) {
            final allAddresses = await _apiService.getMyAddresses();
            if (allAddresses.isNotEmpty) {
              try {
                defaultAddress = allAddresses.firstWhere(
                  (addr) => addr.id == userProfile!.defaultAddressId,
                );
              } catch (e) {
                defaultAddress = allAddresses.first;
              }
            }
          } else {
            final allAddresses = await _apiService.getMyAddresses();
            if (allAddresses.isNotEmpty) {
              defaultAddress = allAddresses.first;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          if (customerId != null &&
              customerId.isNotEmpty &&
              userProfile != null) {
            _shellData = CustomerDashboardShellData(
              customerId: customerId,
              customerFirstName: userProfile.firstName,
              currentDeliveryAddress: defaultAddress,
              hasUnreadNotifications: hasNotifications,
            );
            _screenOptions = _buildScreenOptions(_shellData);
          } else {
            _shellErrorMessage =
                "Could not load user data. Please log in again.";
          }
          _isLoadingShellData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _shellErrorMessage =
              "Failed to load dashboard data: ${e.toString().replaceFirst("Exception: ", "")}";
          _isLoadingShellData = false;
        });
      }
    }
  }

  List<Widget> _buildScreenOptions(CustomerDashboardShellData? shellData) {
    String currentCustomerId = shellData?.customerId ?? "";
    String currentCustomerFirstName = shellData?.customerFirstName ?? "";

    return [
      HomeScreen(
        key: ValueKey(
            'home_tab_${shellData?.currentDeliveryAddress?.id ?? shellData?.customerId ?? 'loading_key'}'),
        navigatorKey: _navigatorKeys[0],
        customerIdFromShell: currentCustomerId,
        currentAddressFromShell: shellData?.currentDeliveryAddress,
        onChangeAddressTapped: _navigateToAddressList,
        isLoadingAddressFromShell: _isLoadingShellData && shellData == null,
        onSwitchTab: _onItemTapped,
        userNameFromShell: currentCustomerFirstName,
      ),
      OrderListScreen(
        navigatorKey: _navigatorKeys[1],
        customerId: currentCustomerId,
        initialHomeAddress: shellData?.currentDeliveryAddress,
      ),
      DealsScreen(
        navigatorKey: _navigatorKeys[2],
        customerId: currentCustomerId,
        initialAddress: shellData?.currentDeliveryAddress,
      ),
      ProfileScreen(
        navigatorKey: _navigatorKeys[3],
        customerId: currentCustomerId,
      ),
    ];
  }

  void _handleAddressSelectedFromList(AddressModel newAddress) {
    if (mounted && _shellData != null) {
      final bool wasAlreadyDefault = newAddress.isDefault;
      setState(() {
        _shellData = CustomerDashboardShellData(
          customerId: _shellData!.customerId,
          customerFirstName: _shellData!.customerFirstName,
          currentDeliveryAddress: newAddress,
          hasUnreadNotifications: _shellData!.hasUnreadNotifications,
        );
        _screenOptions = _buildScreenOptions(_shellData);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delivering to: ${newAddress.fullAddress}',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Provider.of<ThemeProvider>(context, listen: false)
              .gas2doorPrimaryBlue,
          duration: const Duration(seconds: 2),
        ),
      );

      if (!wasAlreadyDefault) {
        _apiService.setDefaultAddress(newAddress.id).then((_) {
          _fetchShellData(isRefresh: true);
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Could not set as default: ${error.toString().replaceFirst("Exception: ", "")}',
                  style: GoogleFonts.inter(color: Colors.white)),
              backgroundColor:
                  Provider.of<ThemeProvider>(context, listen: false).errorColor,
              duration: const Duration(seconds: 2),
            ),
          );
        });
      }
    }
  }

  Future<void> _navigateToAddressList() async {
    HapticFeedback.lightImpact();
    if (_shellData?.customerId == null || _shellData!.customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User details are loading, please wait.',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor:
              Provider.of<ThemeProvider>(context, listen: false).errorColor,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final result = await Navigator.of(context, rootNavigator: true).pushNamed(
      AddressListScreen.routeName,
      arguments: {
        'isSelectingAddress': true,
        'currentAddressId': _shellData?.currentDeliveryAddress?.id,
        'customerId': _shellData!.customerId,
      },
    );

    if (result != null && result is AddressModel) {
      _handleAddressSelectedFromList(result);
    }
  }

  void _onItemTapped(int index) {
    HapticFeedback.lightImpact();
    if (_selectedIndex == index && _navigatorKeys[index].currentState != null) {
      _navigatorKeys[index].currentState!.popUntil((route) => route.isFirst);
    }
    if (mounted) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final String appLogoPath = 'assets/images/PrimeJet_Logo.png';

    // ✅ STEP 1: Get the NotificationProvider here so the widget listens for changes.
    final notificationProvider = Provider.of<NotificationProvider>(context);

    final Color bg = themeProvider.appPrimaryBackground;
    final Color appBarGlass = (isDark
        ? Colors.black.withOpacity(0.20)
        : Colors.white.withOpacity(0.40));
    final Color navGlass = (isDark
        ? Colors.black.withOpacity(0.20)
        : Colors.white.withOpacity(0.40));
    final Color primaryText = themeProvider.primaryText;
    final Color mutedText = (isDark ? Colors.white70 : Colors.black54);
    final Color shadowColor = (isDark
        ? Colors.black.withOpacity(0.6)
        : Colors.black.withOpacity(0.1));
    final Color overlayCircle = (isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.20));
    final Color overlayIcon = (isDark ? Colors.white70 : Colors.white);

    const IconData homeIcon = Icons.home_work_outlined;
    const IconData homeActiveIcon = Icons.home_work_rounded;
    const IconData ordersIcon = Icons.receipt_long_outlined;
    const IconData ordersActiveIcon = Icons.receipt_long_rounded;
    const IconData dealsIcon = Icons.local_offer_outlined;
    const IconData dealsActiveIcon = Icons.local_offer_rounded;
    const IconData profileIcon = Icons.person_outline_rounded;
    const IconData profileActiveIcon = Icons.person_rounded;
    const IconData notificationIcon = Icons.notifications_none_rounded;

    if (_isLoadingShellData && _shellData == null) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
            child: CircularProgressIndicator(
                color: themeProvider.gas2doorPrimaryBlue)),
      );
    }
    if (_shellErrorMessage != null && _shellData == null) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded,
                    color: themeProvider.errorColor, size: 50),
                const SizedBox(height: 16),
                Text(_shellErrorMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: primaryText, fontSize: 16)),
                const SizedBox(height: 20),
                CustomButton(
                    text: "Retry",
                    onPressed: () => _fetchShellData(isRefresh: true),
                    color: themeProvider.gas2doorPrimaryBlue)
              ],
            ),
          ),
        ),
      );
    }

    Widget appBarTitleWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          appLogoPath,
          height: 28,
          color: themeProvider.gas2doorPrimaryBlue,
          errorBuilder: (ctx, err, st) => Icon(
            Icons.local_fire_department_rounded,
            color: themeProvider.gas2doorPrimaryBlue,
            size: 28,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _appDisplayName,
          style: GoogleFonts.inter(
            color: primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: appBarGlass,
        elevation: 0,
        shadowColor: shadowColor,
        automaticallyImplyLeading: false,
        title: appBarTitleWidget,
        actions: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              IconButton(
                icon: Icon(
                  notificationIcon,
                  color: mutedText,
                  size: 26.0,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context, rootNavigator: true)
                      .pushNamed(NotificationScreen.routeName);
                },
                tooltip: "Notifications",
              ),
              // ✅ STEP 2: Change the condition to use the provider's live unreadCount.
              if (notificationProvider.unreadCount > 0)
                Positioned(
                  right: 8.0,
                  top: 10.0,
                  child: Container(
                    width: 9.0,
                    height: 9.0,
                    decoration: BoxDecoration(
                      color: themeProvider.errorColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.black : Colors.white,
                        width: 1.0,
                      ),
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: -MediaQuery.of(context).size.height * 0.3,
            left: -MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.2,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          Colors.blueGrey.shade800.withOpacity(0.50),
                          Colors.deepPurple.shade700.withOpacity(0.45),
                        ]
                      : [
                          Colors.blue.shade300.withOpacity(0.70),
                          Colors.red.shade300.withOpacity(0.70),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.3, 0.7],
                ),
              ),
              child: Transform.rotate(
                angle: -0.2,
                child: CustomPaint(
                  size: Size(MediaQuery.of(context).size.width * 1.2,
                      MediaQuery.of(context).size.height * 0.8),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: MediaQuery.of(context).size.width * 0.15,
            child: Opacity(
              opacity: 0.8,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: overlayCircle,
                ),
                child: Icon(Icons.local_gas_station_outlined,
                    size: 30, color: overlayIcon),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: MediaQuery.of(context).size.width * 0.4,
            child: Opacity(
              opacity: 0.8,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: overlayCircle,
                ),
                child: Icon(Icons.local_shipping_outlined,
                    size: 30, color: overlayIcon),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.65,
            left: MediaQuery.of(context).size.width * 0.7,
            child: Opacity(
              opacity: 0.8,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: overlayCircle,
                ),
                child: Icon(Icons.location_on_outlined,
                    size: 30, color: overlayIcon),
              ),
            ),
          ),
          IndexedStack(
            index: _selectedIndex,
            children: _screenOptions,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(homeIcon),
              activeIcon: Icon(homeActiveIcon),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(ordersIcon),
              activeIcon: Icon(ordersActiveIcon),
              label: 'Orders'),
          BottomNavigationBarItem(
              icon: Icon(dealsIcon),
              activeIcon: Icon(dealsActiveIcon),
              label: 'Deals'),
          BottomNavigationBarItem(
              icon: Icon(profileIcon),
              activeIcon: Icon(profileActiveIcon),
              label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: themeProvider.gas2doorPrimaryBlue,
        unselectedItemColor: mutedText,
        selectedLabelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.0),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11.5),
        showUnselectedLabels: true,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: navGlass,
        elevation: 0,
        landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
      ),
    );
  }
}
