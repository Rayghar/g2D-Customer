// File: lib/screens/customer/home_screen.dart
// ADVISORY: This version adds the Order ID to recent orders and the delivery address to the active order card.
// UPDATE: Implemented periodic polling for active order status and dynamic customer stats.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../models/address_model.dart';
import '../../models/deal_model.dart';
import '../../models/order.dart' as app_order;
import '../../models/customer_stats_model.dart'; // NEW: Import CustomerStatsModel
import '../../services/api_service.dart';
import './order_placement_screen.dart';
import './order_details_screen.dart';
import './order_summary_screen.dart';
import './promotion_details_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // NEW: Import Firebase Messaging
import '../../providers/order_provider.dart';
import './payment_screen.dart';

final _logger = Logger('HomeScreen');

class PromotionItem {
  final String title;
  final String description;
  final Color backgroundColor;
  final String? backgroundImage;
  final Color textColor;
  final String? ctaText;
  final String? ctaLink;
  final Map<String, dynamic>? ctaArgs;
  final String? promoCodeToApply;
  final DealModel dealModel;
  PromotionItem({
    required this.title,
    required this.description,
    required this.backgroundColor,
    this.backgroundImage,
    required this.textColor,
    this.ctaText,
    this.ctaLink,
    this.ctaArgs,
    this.promoCodeToApply,
    required this.dealModel,
  });
}

class HomeScreen extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final String? customerIdFromShell;
  final AddressModel? currentAddressFromShell;
  final VoidCallback onChangeAddressTapped;
  final bool isLoadingAddressFromShell;
  final Function(int) onSwitchTab;
  final String? userNameFromShell;

  const HomeScreen({
    super.key,
    required this.navigatorKey,
    required this.customerIdFromShell,
    required this.currentAddressFromShell,
    required this.onChangeAddressTapped,
    required this.isLoadingAddressFromShell,
    required this.onSwitchTab,
    this.userNameFromShell,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _sectionSlideAnimations;
  final PageController _promotionPageController = PageController();
  int _currentPromotionPage = 0;
  Timer? _promotionTimer;
  //Timer? _activeOrderPollingTimer; // NEW: Timer for active order polling

  List<PromotionItem> _promotionItems = [];
  CustomerStatsModel? _customerStats; // NEW: Customer stats data
  String? _errorMessage;
  bool _isLoading = true;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _logger.info('HomeScreen initialized.');
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'lifecycle',
        message: 'HomeScreen initialized',
        level: SentryLevel.info));

    if (widget.customerIdFromShell?.isNotEmpty ?? false) {
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: widget.customerIdFromShell));
      });
    }

    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _sectionSlideAnimations = List.generate(
        6,
        (index) => Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _entryAnimController,
                curve: Interval(0.1 + (index * 0.08),
                    (0.7 + (index * 0.08)).clamp(0.0, 1.0),
                    curve: Curves.easeOutCubic))));

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.info(
          'Foreground FCM message received on HomeScreen: ${message.data}');
      // Check if the notification is an order update
      if (message.data['type'] == 'ORDER_STATUS_UPDATE' && mounted) {
        // Refresh all data to get the latest order status
        _loadAllHomeScreenData(isRefresh: true);
      }
    });

    if (widget.customerIdFromShell?.isNotEmpty ?? false) {
      _loadAllHomeScreenData();
    } else {
      setState(() => _isLoading = false);
      _logger.info('Customer ID not available, skipping initial data load.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'data_loading',
          message: 'Customer ID missing, initial data load skipped',
          level: SentryLevel.info));
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customerIdFromShell != oldWidget.customerIdFromShell &&
        (widget.customerIdFromShell?.isNotEmpty ?? false)) {
      _logger.info('Customer ID changed, reloading home screen data.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'lifecycle',
          message: 'Customer ID updated, reloading home data',
          data: {'new_customer_id': widget.customerIdFromShell},
          level: SentryLevel.info));
      _loadAllHomeScreenData(isRefresh: true);
    }
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    _promotionPageController.dispose();
    _promotionTimer?.cancel();
    //_activeOrderPollingTimer
    //?.cancel(); // NEW: Cancel active order polling timer
    _logger.info('HomeScreen disposed.');
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'lifecycle',
        message: 'HomeScreen disposed',
        level: SentryLevel.info));
    super.dispose();
  }

  Future<void> _loadAllHomeScreenData({bool isRefresh = false}) async {
    if (widget.customerIdFromShell?.isEmpty ?? true) {
      _logger
          .warning('Attempted to load home screen data without a customer ID.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'data_loading',
          message: 'Aborting data load: Customer ID is empty',
          level: SentryLevel.warning));
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (isRefresh) _errorMessage = null;
      });
    }
    if (isRefresh) _entryAnimController.reset();

    _logger.info('Loading all home screen data (isRefresh: $isRefresh).');
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'data_loading',
        message: 'Starting full home screen data fetch',
        data: {
          'is_refresh': isRefresh,
          'customer_id': widget.customerIdFromShell
        },
        level: SentryLevel.info));

    try {
      // 1. Ask the OrderProvider to fetch the order data first.
      await Provider.of<OrderProvider>(context, listen: false)
          .fetchHomeScreenData();

      // 2. Then, fetch the other non-order data like before.
      final results = await Future.wait([
        _apiService.getActivePromotions(),
        _apiService.getCustomerStats(widget.customerIdFromShell!),
      ], eagerError: false);

      if (!mounted) return;

      // 3. The process function now only handles non-order data.
      _processApiResponse(results);
    } catch (e, st) {
      _logger.severe("Failed to load home screen data: $e", e, st);
      Sentry.captureException(e,
          stackTrace: st,
          hint: Hint.withMap({
            'customer_id': widget.customerIdFromShell,
            'action': 'load_home_screen_data',
            'is_refresh': isRefresh,
          }));
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load data. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

  void _processApiResponse(List<dynamic> results) {
    if (!mounted) return;
    _logger.fine('Processing API responses for home screen.');
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final List<Color> colorCycle = [
      themeProvider.gas2doorTeal,
      themeProvider.gas2doorPurple,
      themeProvider.gas2doorPrimaryBlueLightVer
    ];

    if (results[0] is List<DealModel>) {
      _promotionItems =
          (results[0] as List<DealModel>).asMap().entries.map((entry) {
        int idx = entry.key;
        DealModel deal = entry.value;
        final cardColor = colorCycle[idx % colorCycle.length];
        final isDarkCard =
            ThemeData.estimateBrightnessForColor(cardColor) == Brightness.dark;
        return PromotionItem(
            dealModel: deal,
            title: deal.title,
            description: deal.shortDescription,
            backgroundColor: cardColor,
            backgroundImage: deal.imageUrl,
            textColor: deal.textColor ??
                (isDarkCard
                    ? Colors.white.withOpacity(0.95)
                    : themeProvider.primaryText),
            ctaText: deal.ctaText.isNotEmpty ? deal.ctaText : 'Claim Offer',
            ctaLink: deal.ctaLink,
            promoCodeToApply: deal.promoCode,
            ctaArgs: deal.ctaArgs);
      }).toList();
      _logger.info('Processed ${_promotionItems.length} promotion items.');
    } else {
      _logger.warning(
          'Expected List<DealModel> for promotions, got: ${results[0].runtimeType}');
      Sentry.captureMessage('Unexpected type for promotions API response.',
          level: SentryLevel.warning,
          hint: Hint.withMap({
            'expected_type': 'List<DealModel>',
            'received_type': results[0].runtimeType.toString(),
            'customer_id': widget.customerIdFromShell,
          }));
    }

    if (results[1] is CustomerStatsModel) {
      _customerStats = results[1] as CustomerStatsModel;
      _logger.info(
          'Processed customer stats: Total Orders: ${_customerStats!.totalOrders}');
    } else {
      _logger.warning(
          'Expected CustomerStatsModel for customer stats, got: ${results[1].runtimeType}');
      Sentry.captureMessage('Unexpected type for customer stats API response.',
          level: SentryLevel.warning,
          hint: Hint.withMap({
            'expected_type': 'CustomerStatsModel',
            'received_type': results[1].runtimeType.toString(),
            'customer_id': widget.customerIdFromShell,
          }));
    }

    setState(() => _isLoading = false);
    _entryAnimController.forward();
    _startPromotionAutoScroll();
    _logger.info('API response processing complete. UI updated.');
  }

  void _startPromotionAutoScroll() {
    _promotionTimer?.cancel();
    if (_promotionItems.length > 1) {
      _logger.fine('Starting promotion auto-scroll timer.');
      _promotionTimer =
          Timer.periodic(const Duration(seconds: 6), (Timer timer) {
        if (!_promotionPageController.hasClients || _promotionItems.isEmpty) {
          _logger.fine(
              'Promotion auto-scroll stopped: no clients or empty items.');
          timer.cancel();
          return;
        }
        int nextPage = _promotionPageController.page!.round() + 1;
        if (nextPage >= _promotionItems.length) {
          nextPage = 0;
        }
        _promotionPageController.animateToPage(nextPage,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic);
        _logger.fine('Auto-scrolling promotion to page: $nextPage');
      });
    } else {
      _logger.info(
          'Not enough promotion items to auto-scroll, timer not started.');
    }
  }

  // NEW: Method to start polling for active order status
  /*void _startActiveOrderPolling() {
    _activeOrderPollingTimer?.cancel(); // Cancel any existing timer
    if (_activeOrder == null ||
            _activeOrder!.status ==
                'Delivered' || // FIX: Check against high-level statuses
            _activeOrder!.status
                .contains('Canceled') || // FIX: Check for cancellation
            _activeOrder!.status == 'Customer Unavailable' ||
            _activeOrder!.status == 'Issue Reported' ||
            _activeOrder!.status ==
                'Payment Failed' // Any other terminal status
        ) {
      _logger.info(
          'No active order or order in terminal state, not starting active order polling.');
      return;
    }

    _logger.info(
        'Starting active order polling for order ID: ${_activeOrder!.id}');
    _activeOrderPollingTimer =
        Timer.periodic(const Duration(seconds: 15), (timer) async {
      // Poll every 15 seconds
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final fetchedOrder =
            await _apiService.getOrderDetails(_activeOrder!.id);
        if (mounted) {
          setState(() {
            _activeOrder = fetchedOrder;
          });
          // If the order has reached a terminal status, stop polling
          if (_activeOrder!.status == 'Delivered' ||
              _activeOrder!.status.contains('Canceled') ||
              _activeOrder!.status == 'Customer Unavailable' ||
              _activeOrder!.status == 'Issue Reported' ||
              _activeOrder!.status == 'Payment Failed') {
            _logger.info(
                'Active order ${_activeOrder!.id} reached terminal status: ${_activeOrder!.status}. Stopping polling.');
            timer.cancel();
          }
        }
      } catch (e) {
        _logger.warning(
            'Error during active order polling for ${_activeOrder!.id}: $e');
        // Continue polling on error, but perhaps with a backoff strategy in a real app
      }
    });
  }*/

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: isError
          ? themeProvider.errorColor
          : themeProvider.successColor.withOpacity(0.95),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
    if (isError) {
      _logger.warning('Snackbar Error: $message');
    } else {
      _logger.info('Snackbar Success/Info: $message');
    }
  }

  void _navigateToOrderPlacement(
      {String? prefilledPromoCode,
      String? refillCylinderSize,
      bool isRefill = false,
      String? preselectedCylinderIdFromDeal}) {
    HapticFeedback.mediumImpact();
    _logger.info('Attempting to navigate to OrderPlacementScreen.');
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'navigation',
        message: 'Navigating to OrderPlacementScreen',
        data: {
          'is_refill': isRefill,
          'promo_code': prefilledPromoCode,
          'cylinder_id_from_deal': preselectedCylinderIdFromDeal
        },
        level: SentryLevel.info));

    if (widget.customerIdFromShell == null) {
      _showFeedbackSnackbar("Please log in to place an order.", isError: true);
      _logger.warning(
          'Cannot navigate to order placement: Customer not logged in.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'navigation_blocked',
          message: 'Order placement blocked: Customer ID missing',
          level: SentryLevel.warning));
      return;
    }
    if (widget.currentAddressFromShell == null) {
      _showFeedbackSnackbar("Please select a delivery address first.",
          isError: true);
      widget.onChangeAddressTapped();
      _logger.warning(
          'Cannot navigate to order placement: No delivery address selected.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'navigation_blocked',
          message: 'Order placement blocked: No delivery address',
          level: SentryLevel.warning));
      return;
    }
    Navigator.of(context).pushNamed(
      OrderPlacementScreen.routeName,
      arguments: {
        'customerId': widget.customerIdFromShell,
        'initialAddress': widget.currentAddressFromShell,
        'prefilledPromoCode': prefilledPromoCode,
        'isRefill': isRefill,
        'refillCylinderSize': refillCylinderSize,
        'preselectedCylinderIdFromDeal':
            preselectedCylinderIdFromDeal, // Pass this argument
      },
    ).then((value) {
      if (value == true) {
        _logger.info('Order placement completed, refreshing home screen data.');
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'order_flow',
            message: 'Order placement successful, refreshing home screen',
            level: SentryLevel.info));
        _loadAllHomeScreenData(isRefresh: true);
      }
    });
  }

  void _navigateToReorder(app_order.Order order) {
    _logger.info('Attempting to reorder for order ID: ${order.id}');
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'order_action',
        message: 'Initiating reorder',
        data: {'original_order_id': order.id},
        level: SentryLevel.info));

    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    if (firstItem == null) {
      _showFeedbackSnackbar("Could not find item details to reorder.",
          isError: true);
      _logger.warning(
          'Reorder failed: No items found in original order ${order.id}.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'order_action',
          message: 'Reorder failed: No items in original order',
          data: {'original_order_id': order.id},
          level: SentryLevel.warning));
      return;
    }
    _navigateToOrderPlacement(
        refillCylinderSize: firstItem.cylinderSizeKG, isRefill: true);
  }

  void _handlePromotionCta(PromotionItem item) {
    HapticFeedback.mediumImpact();
    _logger.info('Handling promotion CTA for: ${item.title}');
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'promotion',
        message: 'Promotion CTA clicked',
        data: {
          'promotion_title': item.title,
          'cta_link': item.ctaLink,
          'promo_code': item.promoCodeToApply
        },
        level: SentryLevel.info));

    Map<String, dynamic> navArgs =
        Map<String, dynamic>.from(item.dealModel.ctaArgs ?? {});
    navArgs['customerId'] = widget.customerIdFromShell;
    navArgs['initialAddress'] = widget.currentAddressFromShell;
    if (item.promoCodeToApply != null) {
      navArgs['prefilledPromoCode'] = item.promoCodeToApply;
    }

    if (item.ctaLink != null) {
      Navigator.of(context).pushNamed(item.ctaLink!,
          arguments: navArgs.isNotEmpty ? navArgs : null);
      _logger.info('Navigated to ${item.ctaLink} via promotion CTA.');
    } else if (item.promoCodeToApply != null) {
      _navigateToOrderPlacement(prefilledPromoCode: item.promoCodeToApply);
      _logger.info(
          'Initiated order placement with promo code from promotion CTA.');
    } else {
      _logger.warning(
          'Promotion CTA for "${item.title}" has no valid action (ctaLink or promoCodeToApply).');
      Sentry.captureMessage(
          'Promotion CTA with no actionable link or promo code.',
          level: SentryLevel.warning,
          hint: Hint.withMap({
            'promotion_title': item.title,
            'deal_id': item.dealModel.id,
          }));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String currentUserName = widget.userNameFromShell ?? "Customer";

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      body: RefreshIndicator(
        onRefresh: () {
          _logger.info('Refresh indicator triggered.');
          Sentry.addBreadcrumb(Breadcrumb(
              category: 'ui_action',
              message: 'Pull to refresh triggered',
              level: SentryLevel.info));
          return _loadAllHomeScreenData(isRefresh: true);
        },
        color: themeProvider.gas2doorPrimaryBlue,
        backgroundColor: themeProvider.cardBackground,
        child: Consumer<OrderProvider>(
          // 1. Wrap the body with a Consumer
          builder: (context, orderProvider, child) {
            // 2. Get the order-related data from the provider
            final activeOrder = orderProvider.activeOrder;
            final recentOrders = orderProvider.recentOrders;
            final bool hasActiveOrderData = activeOrder != null;

            // 3. Your existing UI and variables for other data remain the same
            final String ordersActionCardTitle =
                hasActiveOrderData ? 'Track Active Order' : 'My Orders';
            final IconData ordersActionCardIcon = hasActiveOrderData
                ? Icons.route_outlined
                : Icons.receipt_long_outlined;

            VoidCallback ordersActionCardOnTap = () {
              if (hasActiveOrderData) {
                _navigateToOrderDetails(activeOrder.id);
              } else {
                widget.onSwitchTab(1);
              }
            };

            // 4. The rest of your build method uses these variables
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAddressDisplayWidget(themeProvider),
                  if (_isLoading) // Use the local _isLoading for overall page load
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 150.0),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: themeProvider.gas2doorPrimaryBlue)))
                  else if (_errorMessage != null)
                    Center(
                        child: Padding(
                            padding: const EdgeInsets.all(30.0),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_off_rounded,
                                      size: 50,
                                      color: themeProvider.secondaryText),
                                  const SizedBox(height: 16),
                                  Text(_errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                          color: themeProvider.secondaryText,
                                          fontSize: 16)),
                                  const SizedBox(height: 20),
                                  CustomButton(
                                      text: "Retry",
                                      onPressed: () {
                                        _logger.info(
                                            'Retry button pressed on error state.');
                                        Sentry.addBreadcrumb(Breadcrumb(
                                            category: 'error_recovery',
                                            message:
                                                'Retry button pressed on home screen error',
                                            level: SentryLevel.info));
                                        _loadAllHomeScreenData(isRefresh: true);
                                      },
                                      color: themeProvider.gas2doorPrimaryBlue)
                                ])))
                  else
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SlideTransition(
                              position: _sectionSlideAnimations[0],
                              child: Text('Hi, $currentUserName!',
                                  style: GoogleFonts.inter(
                                      fontSize: 26.0,
                                      fontWeight: FontWeight.bold,
                                      color: themeProvider.primaryText,
                                      height: 1.3))),
                          const SizedBox(height: 20.0),
                          SlideTransition(
                              position: _sectionSlideAnimations[1],
                              child: Row(
                                children: [
                                  Expanded(
                                      child: _buildActionCard(
                                          iconData:
                                              Icons.local_gas_station_outlined,
                                          title: 'New Order',
                                          backgroundColor: themeProvider
                                              .gas2doorPrimaryBlueLightVer,
                                          iconTextColor:
                                              themeProvider.infoColorOnDarkBgs,
                                          onTap: () =>
                                              _navigateToOrderPlacement(),
                                          themeProvider: themeProvider)),
                                  const SizedBox(width: 16.0),
                                  Expanded(
                                      child: _buildActionCard(
                                          iconData: ordersActionCardIcon,
                                          title: ordersActionCardTitle,
                                          backgroundColor: themeProvider
                                              .gas2doorTealLightVer,
                                          iconTextColor:
                                              themeProvider.infoColorOnDarkBgs,
                                          onTap: ordersActionCardOnTap,
                                          themeProvider: themeProvider)),
                                ],
                              )),
                          const SizedBox(height: 25.0),
                          if (_promotionItems.isNotEmpty)
                            SlideTransition(
                                position: _sectionSlideAnimations[2],
                                child: _buildPromotionsSection(themeProvider)),
                          if (hasActiveOrderData)
                            SlideTransition(
                                position: _sectionSlideAnimations[3],
                                child: _buildActiveOrderCard(
                                    themeProvider, activeOrder)),
                          if (hasActiveOrderData) const SizedBox(height: 25.0),
                          SlideTransition(
                              position: _sectionSlideAnimations[4],
                              child: _buildOrderHistorySection(
                                  themeProvider: themeProvider,
                                  orders: recentOrders)),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddressDisplayWidget(ThemeProvider themeProvider) {
    const IconData locationPinIcon = Icons.location_on_outlined;
    return InkWell(
      onTap: () {
        _logger.info('Address display widget tapped.');
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'ui_action',
            message: 'Address display widget tapped',
            level: SentryLevel.info));
        widget.onChangeAddressTapped();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        decoration: BoxDecoration(color: themeProvider.deliveryAddressBgColor),
        child: Row(
          children: [
            Icon(locationPinIcon, color: themeProvider.gas2doorTeal, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Delivering to:',
                    style: GoogleFonts.inter(
                        color: themeProvider.secondaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                widget.isLoadingAddressFromShell &&
                        widget.currentAddressFromShell == null
                    ? SizedBox(
                        height: 12,
                        child: Container(
                            width: 140,
                            decoration: BoxDecoration(
                                color: themeProvider.isDarkMode
                                    ? Colors.grey[700]!.withOpacity(0.6)
                                    : Colors.grey[300]!,
                                borderRadius: BorderRadius.circular(3))))
                    : Text(
                        widget.currentAddressFromShell?.fullAddress ??
                            'Tap to select address',
                        style: GoogleFonts.inter(
                            color: themeProvider.primaryText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
              ],
            )),
            Icon(Icons.arrow_drop_down_rounded,
                color: themeProvider.secondaryText, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionsSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('Don\'t Miss These!',
                style: GoogleFonts.inter(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText))),
        SizedBox(
          height: 183,
          child: PageView.builder(
            controller: _promotionPageController,
            itemCount: _promotionItems.length,
            onPageChanged: (int page) {
              setState(() => _currentPromotionPage = page);
              _logger.fine('Promotion carousel page changed to: $page');
              Sentry.addBreadcrumb(Breadcrumb(
                  category: 'ui_interaction',
                  message: 'Promotion carousel page changed',
                  data: {'page': page},
                  level: SentryLevel.debug));
            },
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _buildPromotionCarouselItem(
                  _promotionItems[index], context,
                  themeProvider: themeProvider),
            ),
          ),
        ),
        if (_promotionItems.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _promotionItems.length,
                (index) => Container(
                  width: _currentPromotionPage == index ? 10.0 : 8.0,
                  height: _currentPromotionPage == index ? 10.0 : 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPromotionPage == index
                          ? themeProvider.gas2doorPrimaryBlue
                          : themeProvider.secondaryText.withOpacity(0.3)),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPromotionCarouselItem(PromotionItem item, BuildContext context,
      {required ThemeProvider themeProvider}) {
    return CustomCard(
      elevation: 4.0,
      borderRadius: themeProvider.cardBorderRadiusValue,
      shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.7),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
      color: item.backgroundColor,
      child: Stack(
        children: [
          if (item.backgroundImage != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: themeProvider.cardBorderRadius,
                child: Image.network(item.backgroundImage!,
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.3),
                    colorBlendMode: BlendMode.darken),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              borderRadius: themeProvider.cardBorderRadius,
              gradient: LinearGradient(
                colors: [
                  item.backgroundColor
                      .withOpacity(item.backgroundImage != null ? 0.4 : 0.85),
                  item.backgroundColor
                      .withOpacity(item.backgroundImage != null ? 0.8 : 1.0)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.title,
                    style: GoogleFonts.inter(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: item.textColor,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6.0),
                Text(item.description,
                    style: GoogleFonts.inter(
                        fontSize: 15.0,
                        color: item.textColor.withOpacity(0.9))),
                const Spacer(),
                if (item.ctaText != null)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: () => _handlePromotionCta(item),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: item.textColor,
                          foregroundColor: item.backgroundColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25.0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          textStyle: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      child: Text(item.ctaText!),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
      {required IconData iconData,
      required String title,
      required Color backgroundColor,
      required Color iconTextColor,
      required VoidCallback onTap,
      required ThemeProvider themeProvider,
      double height = 110.0}) {
    return CustomCard(
      elevation: 3.0,
      borderRadius: themeProvider.cardBorderRadiusValue,
      shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.4),
      color: backgroundColor,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: themeProvider.cardBorderRadius,
        splashColor: Colors.white.withOpacity(0.15),
        highlightColor: Colors.white.withOpacity(0.1),
        child: SizedBox(
          height: height,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(iconData, size: 32, color: iconTextColor),
                  const SizedBox(height: 8),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: iconTextColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // MODIFIED: Active order card now includes the delivery address.
  Widget _buildActiveOrderCard(
      ThemeProvider themeProvider, app_order.Order activeOrder) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _logger
              .info('Active order card tapped for order ID: ${activeOrder.id}');
          Sentry.addBreadcrumb(Breadcrumb(
              category: 'ui_action',
              message: 'Active Order Card tapped',
              data: {'order_id': activeOrder.id},
              level: SentryLevel.info));
          _navigateToOrderDetails(activeOrder.id);
        },
        borderRadius: themeProvider.cardBorderRadius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusTag(activeOrder, themeProvider),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: themeProvider.secondaryText)
                ],
              ),
              const SizedBox(height: 16.0),
              Text('Order #${activeOrder.shortOrderId}',
                  style: GoogleFonts.inter(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.primaryText)),
              const SizedBox(height: 4.0),
              if (activeOrder.deliveryAddressSnapshot?.fullAddress != null) ...[
                const SizedBox(height: 8.0),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined,
                        color: themeProvider.secondaryText, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeOrder.deliveryAddressSnapshot!.fullAddress,
                        style: GoogleFonts.inter(
                          fontSize: 13.0,
                          color: themeProvider.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12.0),
              _buildDynamicProgressTrackerWithIcons(
                  activeOrder.status, themeProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicProgressTrackerWithIcons(
      String currentStatus, ThemeProvider themeProvider) {
    final stages = [
      {
        'text': 'Order Placed',
        'icon': Icons.playlist_add_check_circle_outlined
      },
      {'text': 'Processing', 'icon': Icons.hourglass_top_rounded},
      {'text': 'En-route', 'icon': Icons.local_shipping_outlined},
      {'text': 'Delivered', 'icon': Icons.check_circle_outline_rounded},
    ];
    final statusMap = {
      'Pending Payment': 0,
      'Order Placed': 0,
      'Processing': 1,
      'Driver Assigned': 1,
      'Out for Delivery': 2,
      'Delivered': 3,
      'Customer Unavailable': 3,
      'Issue Reported': 3,
      'Payment Failed': 3,
      'Canceled by Customer': 3,
      'Canceled by Admin': 3,
    };

    int currentStageIndex = statusMap[currentStatus] ?? 0;

    String currentStageText = stages[currentStageIndex]['text'] as String;
    IconData currentStageIcon = stages[currentStageIndex]['icon'] as IconData;
    String? nextStageText = currentStageIndex < stages.length - 1
        ? stages[currentStageIndex + 1]['text'] as String
        : null;

    if (currentStatus == 'Driver Assigned') {
      currentStageText = 'Driver Assigned';
    }
    if (currentStatus == 'Out for delivery') {
      currentStageText = 'Out for Delivery';
    }

    return Column(
      children: [
        Row(
          children: [
            Icon(currentStageIcon, color: themeProvider.gas2doorTeal, size: 18),
            const SizedBox(width: 8),
            Text(currentStageText,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const Spacer(),
            if (nextStageText != null)
              Text(nextStageText,
                  style: GoogleFonts.inter(color: themeProvider.secondaryText)),
          ],
        ),
        const SizedBox(height: 8),
        if (currentStageIndex < stages.length - 1)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (currentStageIndex + 0.5) / stages.length,
              backgroundColor: themeProvider.tertiaryText.withOpacity(0.2),
              valueColor:
                  AlwaysStoppedAnimation<Color>(themeProvider.gas2doorTeal),
              minHeight: 6,
            ),
          ),
      ],
    );
  }

  Widget _buildOrderHistorySection({
    required ThemeProvider themeProvider,
    required List<app_order.Order> orders,
  }) {
    return CustomCard(
      color: themeProvider.cardBackground,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Order History',
                  style: GoogleFonts.inter(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.primaryText)),
              TextButton(
                  onPressed: () {
                    _logger.info('View All Orders button pressed.');
                    Sentry.addBreadcrumb(Breadcrumb(
                        category: 'ui_action',
                        message: 'View All Orders button pressed',
                        level: SentryLevel.info));
                    widget.onSwitchTab(1);
                  },
                  child: const Text('View All')),
            ]),
            const SizedBox(height: 16.0),
            _buildPerformanceStats(themeProvider, _customerStats),
            const SizedBox(height: 8.0),
            Divider(color: themeProvider.tertiaryText.withOpacity(0.2)),
            if (orders.isEmpty)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30.0),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 48,
                                color: themeProvider.secondaryText
                                    .withOpacity(0.6)),
                            const SizedBox(height: 10),
                            Text('No recent orders to show here.',
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: themeProvider.secondaryText)),
                          ])))
            else
              Column(
                children: orders
                    .map((order) => _buildRecentOrderItemCard(
                        order: order, themeProvider: themeProvider))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  // In lib/screens/customer/home_screen.dart

  Widget _buildRecentOrderItemCard(
      {required app_order.Order order, required ThemeProvider themeProvider}) {
    bool isCompleted = order.status == 'Delivered';
    return CustomCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: themeProvider.cardBackground,
      surfaceTintColor: themeProvider.gas2doorPurple.withOpacity(0.05),
      elevation: 2,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _logger.info('Recent order item tapped for order ID: ${order.id}');

          if (order.status == 'Verifying Payment') {
            // If payment is being verified, always go to the verification screen.
            Navigator.of(context, rootNavigator: true).pushNamed(
              OrderSummaryScreen.routeName,
              arguments: {
                'orderId': order.id,
                'customerId': widget.customerIdFromShell!,
                'isVerifyingPayment': true,
                'orderPayload': order,
              },
            );
          } else if (order.status == 'Pending Payment') {
            // ======================= FIX APPLIED HERE =======================
            if (order.paymentMethod == 'payOnPickup') {
              // POA orders go to details screen for the "Pay Now" button.
              _navigateToOrderDetails(order.id);
            } else {
              // Regular online orders go to the PaymentScreen to try paying again.
              if (order.customer == null) {
                _showFeedbackSnackbar(
                    "Cannot proceed to payment: User details missing.",
                    isError: true);
                return;
              }
              Navigator.of(context, rootNavigator: true).pushNamed(
                PaymentScreen.routeName,
                arguments: {
                  'orderId': order.id,
                  'amount': order.grandTotal,
                  'customer': order.customer!,
                  'order': order,
                },
              );
            }
            // ================================================================
          } else {
            // For all other statuses, go to the details screen.
            _navigateToOrderDetails(order.id);
          }
        },
        borderRadius: themeProvider.cardBorderRadius,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order #${order.shortOrderId}',
                            style: GoogleFonts.inter(
                                color: themeProvider.secondaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Text(order.itemsPreview,
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: themeProvider.primaryText,
                                fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          order.formattedOrderDate,
                          style: GoogleFonts.inter(
                              color: themeProvider.secondaryText, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusTag(order, themeProvider),
                ],
              ),
              if (isCompleted) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.bottomRight,
                  child: SizedBox(
                    width: 100,
                    child: CustomButton(
                      text: 'Reorder',
                      onPressed: () {
                        _logger.info(
                            'Reorder button pressed for order: ${order.id}');
                        _navigateToReorder(order);
                      },
                      height: 36,
                      icon: const Icon(Icons.replay_rounded,
                          size: 16, color: Colors.white),
                      color: themeProvider.gas2doorTeal,
                      textStyle: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTag(app_order.Order order, ThemeProvider themeProvider) {
    Color statusColor;
    String statusText = order.formattedStatus;
    String rawStatus = order.status;

    if (rawStatus == 'Delivered') {
      statusColor = themeProvider.successColor;
    } else if (rawStatus.contains('Canceled') ||
        rawStatus.contains('Unavailable') ||
        rawStatus.contains('Issue') ||
        rawStatus.contains('Failed')) {
      statusColor = themeProvider.errorColor;
    } else if (rawStatus == 'Pending Payment') {
      statusColor = themeProvider.warningColor;
    } else {
      statusColor = themeProvider.gas2doorTeal;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(statusText,
          style: GoogleFonts.inter(
              color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  // FIX: Update _buildPerformanceStats to use CustomerStatsModel
  Widget _buildPerformanceStats(
      ThemeProvider themeProvider, CustomerStatsModel? stats) {
    final int totalOrders = stats?.totalOrders ?? 0;
    final String totalKg = stats?.totalGasKg != null
        ? "${stats!.totalGasKg.toStringAsFixed(1)}kg"
        : "N/A";
    final String avgDays = stats?.averageDaysBetweenOrders != null
        ? "${stats!.averageDaysBetweenOrders.toStringAsFixed(1)} days"
        : "N/A";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(themeProvider, totalOrders.toString(), "Total Orders",
            Icons.shopping_bag_outlined),
        _buildStatItem(
            themeProvider, totalKg, "Total KG", Icons.scale_outlined),
        _buildStatItem(themeProvider, avgDays, "Avg. Between Orders",
            Icons.timelapse_outlined),
      ],
    );
  }

  Widget _buildStatItem(
      ThemeProvider themeProvider, String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: themeProvider.gas2doorTeal, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: themeProvider.primaryText)),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: themeProvider.secondaryText)),
      ],
    );
  }

  void _navigateToOrderDetails(String orderId) {
    _logger.info('Navigating to OrderDetailsScreen for order ID: $orderId');

    if (widget.customerIdFromShell != null) {
      // FIX: Use .then() to refresh data after returning from the sub-screen
      Navigator.of(context).pushNamed(
        OrderDetailsScreen.routeName,
        arguments: {
          'orderId': orderId,
          'customerId': widget.customerIdFromShell,
        },
      ).then((result) {
        _logger.info('Returned from OrderDetailsScreen, refreshing home data.');
        _loadAllHomeScreenData(isRefresh: true);
      });
    } else {
      _logger.warning('Cannot navigate to OrderDetails: Customer ID is null.');
      _showFeedbackSnackbar(
        "Customer ID is missing, cannot view order details.",
        isError: true,
      );
    }
  }
}
