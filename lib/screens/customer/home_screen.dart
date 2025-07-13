// File: lib/screens/customer/home_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../models/address_model.dart';
import '../../models/deal_model.dart';
import '../../models/order.dart' as app_order;
import '../../services/api_service.dart';
import './order_placement_screen.dart';
import './order_details_screen.dart';
import './promotion_details_screen.dart';
import '../more/refer_friend_screen.dart';
import 'chat_screen.dart';

class GasLevelData {
  final double level;
  final String displayText;
  final String etaText;
  final bool showPrompt;

  GasLevelData({
    required this.level,
    required this.displayText,
    required this.etaText,
    this.showPrompt = false,
  });
}

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

class ActiveOrderStatusSummary {
  final String orderId;
  final String status;
  final DateTime? eta;
  ActiveOrderStatusSummary({
    required this.orderId,
    required this.status,
    this.eta,
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
  late AnimationController _gasLevelController;
  late Animation<double> _gasLevelAnimation;
  PageController _promotionPageController = PageController();
  int _currentPromotionPage = 0;
  Timer? _promotionTimer;

  GasLevelData _gasLevelData = GasLevelData(
    level: 0.0,
    displayText: '--%',
    etaText: 'Calculating...',
    showPrompt: true,
  );

  List<PromotionItem> _promotionItems = [];
  ActiveOrderStatusSummary? _activeOrderStatus;
  List<app_order.Order> _recentOrders = [];
  String? _errorMessage;
  bool _isLoading = true;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _sectionSlideAnimations = List.generate(
      6,
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(
              0.1 + (index * 0.08), (0.7 + (index * 0.08)).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic),
        ),
      ),
    );
    _gasLevelController = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    _gasLevelAnimation = Tween<double>(begin: 0, end: 0.0).animate(
        CurvedAnimation(
            parent: _gasLevelController, curve: Curves.easeInOutCubic));
    _promotionPageController =
        PageController(initialPage: 0, viewportFraction: 0.9);

    if (widget.customerIdFromShell?.isNotEmpty ?? false) {
      _loadAllHomeScreenData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customerIdFromShell != oldWidget.customerIdFromShell &&
        (widget.customerIdFromShell?.isNotEmpty ?? false)) {
      _loadAllHomeScreenData(isRefresh: true);
    }
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    _gasLevelController.dispose();
    _promotionPageController.dispose();
    _promotionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllHomeScreenData({bool isRefresh = false}) async {
    if (widget.customerIdFromShell?.isEmpty ?? true) return;
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (isRefresh) _errorMessage = null;
      });
    }
    if (isRefresh) _entryAnimController.reset();

    try {
      final results = await Future.wait([
        _apiService.getActivePromotions(),
        _apiService.getCustomerOrders(
            limit: 1,
            status:
                'Order Placed,Processing,Driver Assigned,Out for delivery,Driver enroute to pickup,Driver enroute to gas station,Cylinder Refilling',
            sortBy: '-orderDate'),
        _apiService.getCustomerOrders(limit: 3, sortBy: '-orderDate'),
        _apiService.getCustomerConsumptionData(),
      ], eagerError: false);

      if (!mounted) return;
      _processApiResponse(results);
    } catch (e) {
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final List<Color> colorCycle = [
      themeProvider.gas2doorTeal,
      themeProvider.gas2doorPurple,
      themeProvider.gas2doorPrimaryBlueLightVer,
    ];

    if (results[0] is List<DealModel>) {
      _promotionItems =
          (results[0] as List<DealModel>).asMap().entries.map((entry) {
        int idx = entry.key;
        DealModel deal = entry.value;
        final cardColor =
            colorCycle[idx % colorCycle.length]; // Sequential color
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
          ctaArgs: deal.ctaArgs,
        );
      }).toList();
    }

    if (results[1] is Map<String, dynamic>) {
      final activeOrderResponse = results[1] as Map<String, dynamic>;
      final activeOrders =
          activeOrderResponse['orders'] as List<app_order.Order>? ?? [];
      _activeOrderStatus = activeOrders.isNotEmpty
          ? ActiveOrderStatusSummary(
              orderId: activeOrders.first.id,
              status: activeOrders.first.status,
              eta: null)
          : null;
    }

    if (results[2] is Map<String, dynamic>) {
      final recentOrdersResponse = results[2] as Map<String, dynamic>;
      _recentOrders =
          recentOrdersResponse['orders'] as List<app_order.Order>? ?? [];
    }

    if (results[3] is List<app_order.Order>) {
      _calculateGasLevel(results[3] as List<app_order.Order>);
    } else {
      print("Error processing consumption data: ${results[3]}");
      _calculateGasLevel([]);
    }

    setState(() => _isLoading = false);
    _entryAnimController.forward();
    _gasLevelController.forward(from: 0.0);
    _startPromotionAutoScroll();
  }

  // NEW: The core logic for the smart gas indicator
  void _calculateGasLevel(List<app_order.Order> deliveredOrders) {
    if (deliveredOrders.isEmpty) {
      // Case 1: No delivered orders yet
      setState(() {
        _gasLevelData = GasLevelData(
          level: 0.0,
          displayText: 'N/A',
          etaText: 'Place your first order!',
          showPrompt: true,
        );
        _gasLevelAnimation = Tween<double>(begin: 0, end: 0.0).animate(
            CurvedAnimation(
                parent: _gasLevelController, curve: Curves.easeInOutCubic));
      });
      return;
    }

    if (deliveredOrders.length == 1) {
      // Case 2: Exactly one order has been delivered
      setState(() {
        _gasLevelData = GasLevelData(
          level: 1.0,
          displayText: '100%',
          etaText: 'Usage trend starts after next order',
        );
        _gasLevelAnimation =
            Tween<double>(begin: _gasLevelAnimation.value, end: 1.0).animate(
                CurvedAnimation(
                    parent: _gasLevelController, curve: Curves.easeInOutCubic));
      });
      return;
    }

    // Case 3: Two or more delivered orders, calculate the trend
    final lastOrderDate = deliveredOrders[0].orderDate;
    final previousOrderDate = deliveredOrders[1].orderDate;

    final consumptionDuration = lastOrderDate.difference(previousOrderDate);
    final timeSinceLastOrder = DateTime.now().difference(lastOrderDate);

    if (consumptionDuration.inSeconds <= 0) {
      // Avoid division by zero
      setState(() {
        _gasLevelData = GasLevelData(
            level: 1.0,
            displayText: '100%',
            etaText: 'Ready for your next order!');
        _gasLevelAnimation =
            Tween<double>(begin: _gasLevelAnimation.value, end: 1.0).animate(
                CurvedAnimation(
                    parent: _gasLevelController, curve: Curves.easeInOutCubic));
      });
      return;
    }

    double percentage =
        1.0 - (timeSinceLastOrder.inSeconds / consumptionDuration.inSeconds);
    percentage = percentage.clamp(0.0, 1.0);

    final remainingDuration = consumptionDuration - timeSinceLastOrder;
    String etaText = 'Calculating...';
    if (remainingDuration.isNegative) {
      etaText = 'Time to re-order!';
    } else {
      final days = remainingDuration.inDays;
      etaText = days > 0
          ? 'Est. $days day${days == 1 ? '' : 's'} left'
          : 'Est. <1 day left';
    }

    setState(() {
      _gasLevelData = GasLevelData(
        level: percentage,
        displayText: '${(percentage * 100).toInt()}%',
        etaText: etaText,
      );
      _gasLevelAnimation =
          Tween<double>(begin: _gasLevelAnimation.value, end: percentage)
              .animate(CurvedAnimation(
                  parent: _gasLevelController, curve: Curves.easeInOutCubic));
    });
  }

  void _startPromotionAutoScroll() {
    _promotionTimer?.cancel();
    if (_promotionItems.length > 1) {
      _promotionTimer =
          Timer.periodic(const Duration(seconds: 6), (Timer timer) {
        if (!_promotionPageController.hasClients || _promotionItems.isEmpty)
          return;
        int nextPage = _promotionPageController.page!.round() + 1;
        if (nextPage >= _promotionItems.length) nextPage = 0;
        _promotionPageController.animateToPage(nextPage,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic);
      });
    }
  }

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError
            ? themeProvider.errorColor
            : themeProvider.successColor.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _navigateToOrderPlacement({String? prefilledPromoCode}) {
    HapticFeedback.mediumImpact();
    if (widget.customerIdFromShell == null) {
      _showFeedbackSnackbar("Please log in to place an order.", isError: true);
      return;
    }
    if (widget.currentAddressFromShell == null) {
      _showFeedbackSnackbar("Please select a delivery address first.",
          isError: true);
      widget.onChangeAddressTapped();
      return;
    }
    Navigator.of(context).pushNamed(
      OrderPlacementScreen.routeName,
      arguments: {
        'customerId': widget.customerIdFromShell,
        'initialAddress': widget.currentAddressFromShell,
        'prefilledPromoCode': prefilledPromoCode,
        'isRefill': false,
      },
    ).then((value) {
      if (value == true) {
        _loadAllHomeScreenData(isRefresh: true);
      }
    });
  }

  void _navigateToRefillOrder(app_order.Order order) {
    HapticFeedback.mediumImpact();
    if (widget.customerIdFromShell == null) {
      _showFeedbackSnackbar("Please log in to place an order.", isError: true);
      return;
    }
    if (widget.currentAddressFromShell == null) {
      _showFeedbackSnackbar("Please select a delivery address first.",
          isError: true);
      widget.onChangeAddressTapped();
      return;
    }

    // Convert the order's items to the required format for the placement screen
    final List<Map<String, dynamic>> lastOrderItems = order.items.map((item) {
      return {
        'cylinderId': item.cylinderId,
        'quantity': item.quantity,
      };
    }).toList();

    Navigator.of(context).pushNamed(
      OrderPlacementScreen.routeName,
      arguments: {
        'customerId': widget.customerIdFromShell,
        'initialAddress': widget.currentAddressFromShell,
        'isRefill': true,
        'lastOrderItems': lastOrderItems,
      },
    ).then((value) {
      // Refresh home screen data if an order was successfully placed
      if (value == true) {
        _loadAllHomeScreenData(isRefresh: true);
      }
    });
  }

  void _handlePromotionCta(PromotionItem item) {
    HapticFeedback.lightImpact();
    if (item.ctaLink == OrderPlacementScreen.routeName &&
        widget.customerIdFromShell == null) {
      _showFeedbackSnackbar("User information missing. Cannot proceed.",
          isError: true);
      return;
    }
    if (item.ctaLink == ReferFriendScreen.routeName &&
        widget.customerIdFromShell == null) {
      _showFeedbackSnackbar("User information missing for referral.",
          isError: true);
      return;
    }

    if (item.ctaLink != null) {
      Map<String, dynamic> navArgs =
          Map<String, dynamic>.from(item.ctaArgs ?? {});
      if (item.ctaLink == OrderPlacementScreen.routeName) {
        navArgs['customerId'] = widget.customerIdFromShell;
        navArgs['initialAddress'] = widget.currentAddressFromShell;
        if (item.promoCodeToApply != null) {
          navArgs['prefilledPromoCode'] = item.promoCodeToApply;
        }
        navArgs['isRefill'] = navArgs['isRefill'] ?? false;
      } else if (item.ctaLink == PromotionDetailsScreen.routeName) {
        navArgs['customerId'] = widget.customerIdFromShell;
        navArgs['initialAddress'] = widget.currentAddressFromShell;
        navArgs['promotion'] = item.dealModel;
      } else if (item.ctaLink == ReferFriendScreen.routeName) {
        navArgs['customerId'] = widget.customerIdFromShell;
      }
      Navigator.of(context).pushNamed(
        item.ctaLink!,
        arguments: navArgs.isNotEmpty ? navArgs : null,
      );
    } else if (item.promoCodeToApply != null) {
      _navigateToOrderPlacement(prefilledPromoCode: item.promoCodeToApply);
    }
  }

  // UPDATED: Now takes a level parameter
  Color _getGasLevelColor(ThemeProvider themeProvider, double level) {
    if (level > 0.6) return themeProvider.successColor;
    if (level > 0.2) return themeProvider.warningColor;
    return themeProvider.errorColor;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String currentUserName = widget.userNameFromShell ?? "Customer";
    final bool hasActiveOrderData = _activeOrderStatus != null;
    final String ordersActionCardTitle =
        hasActiveOrderData ? 'Track Active Order' : 'My Orders';
    final IconData ordersActionCardIcon =
        hasActiveOrderData ? Icons.route_outlined : Icons.receipt_long_outlined;

    VoidCallback ordersActionCardOnTap = () {
      HapticFeedback.lightImpact();
      if (hasActiveOrderData) {
        if (widget.customerIdFromShell == null || _activeOrderStatus == null) {
          _showFeedbackSnackbar("Cannot track order: Information missing.",
              isError: true);
          return;
        }
        Navigator.of(context).pushNamed(
          OrderDetailsScreen.routeName,
          arguments: {
            'orderId': _activeOrderStatus!.orderId,
            'customerId': widget.customerIdFromShell!,
          },
        );
      } else {
        widget.onSwitchTab(1);
      }
    };

    return Scaffold(
      backgroundColor: themeProvider.appPrimaryBackground,
      body: RefreshIndicator(
        onRefresh: () => _loadAllHomeScreenData(isRefresh: true),
        color: themeProvider.gas2doorPrimaryBlue,
        backgroundColor: themeProvider.cardBackground,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SlideTransition(
                  position: _sectionSlideAnimations[0],
                  child: _buildAddressDisplayWidget(themeProvider)),
              if (_isLoading)
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
                                  size: 50, color: themeProvider.secondaryText),
                              const SizedBox(height: 16),
                              Text(_errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                      color: themeProvider.secondaryText,
                                      fontSize: 16)),
                              const SizedBox(height: 20),
                              CustomButton(
                                  text: "Retry",
                                  onPressed: () =>
                                      _loadAllHomeScreenData(isRefresh: true),
                                  color: themeProvider.gas2doorPrimaryBlue)
                            ])))
              else
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SlideTransition(
                          position: _sectionSlideAnimations[1],
                          child: Text('Hi, $currentUserName!',
                              style: GoogleFonts.inter(
                                  fontSize: 26.0,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.primaryText,
                                  height: 1.3))),
                      const SizedBox(height: 20.0),
                      SlideTransition(
                          position: _sectionSlideAnimations[2],
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
                                      onTap: () => _navigateToOrderPlacement(),
                                      themeProvider: themeProvider)),
                              const SizedBox(width: 16.0),
                              Expanded(
                                  child: _buildActionCard(
                                      iconData: ordersActionCardIcon,
                                      title: ordersActionCardTitle,
                                      backgroundColor:
                                          themeProvider.gas2doorTealLightVer,
                                      iconTextColor:
                                          themeProvider.infoColorOnDarkBgs,
                                      onTap: ordersActionCardOnTap,
                                      themeProvider: themeProvider)),
                            ],
                          )),
                      const SizedBox(height: 24.0),
                      if (_promotionItems.isNotEmpty)
                        SlideTransition(
                          position: _sectionSlideAnimations[3],
                          child: Column(
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
                                height: 181,
                                child: PageView.builder(
                                  controller: _promotionPageController,
                                  itemCount: _promotionItems.length,
                                  onPageChanged: (int page) => setState(
                                      () => _currentPromotionPage = page),
                                  itemBuilder: (context, index) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0),
                                    child: SizedBox(
                                      // Add height constraint to prevent overflow
                                      height: 181,
                                      child: _buildPromotionCarouselItem(
                                          _promotionItems[index], context,
                                          themeProvider: themeProvider),
                                    ),
                                  ),
                                ),
                              ),
                              if (_promotionItems.length > 1)
                                Padding(
                                  // Reduce margin to fit within height
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      _promotionItems.length,
                                      (index) => Container(
                                        width: _currentPromotionPage == index
                                            ? 10.0
                                            : 8.0,
                                        height: _currentPromotionPage == index
                                            ? 10.0
                                            : 8.0,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal:
                                                5.0), // Remove vertical margin
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _currentPromotionPage ==
                                                    index
                                                ? themeProvider
                                                    .gas2doorPrimaryBlue
                                                : themeProvider.secondaryText
                                                    .withOpacity(0.3)),
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(
                                  height: 8), // Reduce spacing to 8 pixels
                            ],
                          ),
                        ),
                      SlideTransition(
                          position: _sectionSlideAnimations[4],
                          child: CustomCard(
                              color: themeProvider.cardBackground,
                              child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Your Gas Level',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 18.0,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: themeProvider
                                                          .primaryText))
                                            ]),
                                        const SizedBox(height: 16.0),
                                        Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              _buildGasCylinderIndicator(
                                                  themeProvider),
                                              const SizedBox(width: 16.0),
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    Text(
                                                        _gasLevelData
                                                                    .displayText ==
                                                                'N/A'
                                                            ? 'Welcome!'
                                                            : '${_gasLevelData.displayText} Remaining',
                                                        style: GoogleFonts.inter(
                                                            fontSize: 17.0,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: _getGasLevelColor(
                                                                themeProvider,
                                                                _gasLevelData
                                                                    .level))),
                                                    const SizedBox(height: 6.0),
                                                    Text(_gasLevelData.etaText,
                                                        style: GoogleFonts.inter(
                                                            fontSize: 13.0,
                                                            color: themeProvider
                                                                .secondaryText))
                                                  ])),
                                              const SizedBox(width: 8),
                                              if (_gasLevelData.level < 0.25 ||
                                                  _gasLevelData.showPrompt)
                                                CustomButton(
                                                    text: 'Refill Now',
                                                    onPressed: () =>
                                                        _navigateToOrderPlacement(),
                                                    color: themeProvider
                                                        .errorColor,
                                                    height: 40,
                                                    icon: const Icon(
                                                        Icons
                                                            .local_fire_department_rounded,
                                                        color: Colors.white,
                                                        size: 18),
                                                    textStyle:
                                                        GoogleFonts.inter(
                                                            color: Colors.white,
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600))
                                            ])
                                      ])))),
                      const SizedBox(height: 24.0),
                      if (hasActiveOrderData)
                        SlideTransition(
                            position: _sectionSlideAnimations[5],
                            child: _buildActiveOrderCard(
                                themeProvider, _activeOrderStatus!)),
                      const SizedBox(height: 24.0),
                      SlideTransition(
                          position: _sectionSlideAnimations[5],
                          child: _buildRecentOrdersSection(
                              themeProvider: themeProvider,
                              isLoading: _isLoading,
                              orders: _recentOrders)),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressDisplayWidget(ThemeProvider themeProvider) {
    const IconData locationPinIcon = Icons.location_on_outlined;
    return InkWell(
      onTap: widget.onChangeAddressTapped,
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

  Widget _buildGasCylinderIndicator(ThemeProvider themeProvider) {
    const double cylinderIconSize = 70.0;
    const double containerHeight = 80.0;
    const double containerWidth = 70.0;
    return SizedBox(
      width: containerWidth,
      height: containerHeight,
      child: AnimatedBuilder(
        animation: _gasLevelAnimation,
        builder: (context, child) {
          Color fillColor =
              _getGasLevelColor(themeProvider, _gasLevelData.level);
          return Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.propane_tank_outlined,
                  size: cylinderIconSize,
                  color: themeProvider.isDarkMode
                      ? Colors.grey[700]
                      : Colors.grey[400]),
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRect(
                  clipper: _GasCylinderFillClipper(
                      fillLevel: _gasLevelAnimation.value),
                  child: Icon(Icons.propane_tank_rounded,
                      size: cylinderIconSize, color: fillColor),
                ),
              ),
              Positioned.fill(
                  child: Center(
                child: Text(
                  _gasLevelData.displayText,
                  style: GoogleFonts.inter(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.95),
                      shadows: [
                        Shadow(
                            blurRadius: 2.0,
                            color: Colors.black.withOpacity(0.7),
                            offset: Offset(1, 1))
                      ]),
                ),
              )),
            ],
          );
        },
      ),
    );
  }

  // Updated _buildPromotionCarouselItem to call _handlePromotionCta
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
                child: Image.asset(item.backgroundImage!,
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
                if (item.ctaText !=
                    null) // CTA button always active if text is present
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: () =>
                          _handlePromotionCta(item), // Calls the new handler
                      style: ElevatedButton.styleFrom(
                          backgroundColor: item.textColor,
                          foregroundColor: item.backgroundColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25.0)),
                          // Adjusted vertical padding from 10 to 8
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

  Widget _buildActiveOrderStatusStep(
      String statusText, ThemeProvider themeProvider) {
    IconData statusIcon;
    Color statusColor;
    String normalizedStatus = statusText.toLowerCase();
    if (normalizedStatus.contains('delivered')) {
      statusIcon = Icons.check_circle_outline_rounded;
      statusColor = themeProvider.successColor;
    } else if (normalizedStatus.contains('cancelled')) {
      statusIcon = Icons.cancel_outlined;
      statusColor = themeProvider.errorColor;
    } else if (normalizedStatus.contains('confirmed')) {
      statusIcon = Icons.thumb_up_alt_outlined;
      statusColor = themeProvider.gas2doorPrimaryBlue;
    } else if (normalizedStatus.contains('placed')) {
      statusIcon = Icons.playlist_add_check_circle_outlined;
      statusColor = themeProvider.gas2doorTeal;
    } else if (normalizedStatus.contains('driver assigned')) {
      statusIcon = Icons.person_pin_circle_outlined;
      statusColor = themeProvider.warningColor;
    } else if (normalizedStatus.contains('enroute') ||
        (normalizedStatus.contains('delivery') &&
            !normalizedStatus.contains('delivered'))) {
      statusIcon = Icons.local_shipping_outlined;
      statusColor = themeProvider.warningColor;
    } else if (normalizedStatus.contains('processing') ||
        normalizedStatus.contains('refilling')) {
      statusIcon = Icons.hourglass_top_rounded;
      statusColor = themeProvider.warningColor;
    } else {
      statusIcon = Icons.info_outline;
      statusColor = themeProvider.secondaryText;
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Current Status",
                  style: GoogleFonts.inter(
                      fontSize: 13, color: themeProvider.secondaryText)),
              Text(statusText,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveOrderCard(
      ThemeProvider themeProvider, ActiveOrderStatusSummary activeOrderStatus) {
    final bool hasActiveOrderData = _activeOrderStatus != null;
    VoidCallback ordersActionCardOnTap = () {
      HapticFeedback.lightImpact();
      if (hasActiveOrderData) {
        if (widget.customerIdFromShell == null || _activeOrderStatus == null) {
          _showFeedbackSnackbar("Cannot track order: Information missing.",
              isError: true);
          return;
        }
        Navigator.of(context)
            .pushNamed(OrderDetailsScreen.routeName, arguments: {
          'orderId': _activeOrderStatus!.orderId,
          'customerId': widget.customerIdFromShell!
        });
      } else {
        widget.onSwitchTab(1);
      }
    };

    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Active Order: #${activeOrderStatus.orderId.length > 6 ? "...${activeOrderStatus.orderId.substring(activeOrderStatus.orderId.length - 4)}" : activeOrderStatus.orderId}',
                style: GoogleFonts.inter(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12.0),
            _buildActiveOrderStatusStep(
                activeOrderStatus.status, themeProvider),
            const SizedBox(height: 16.0),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: ordersActionCardOnTap,
                  child: Text('View Details',
                      style: GoogleFonts.inter(
                          color: themeProvider.gas2doorPrimaryBlue,
                          fontWeight: FontWeight.w600))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrdersSection({
    required ThemeProvider themeProvider,
    required bool isLoading,
    required List<app_order.Order> orders,
  }) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Recent Orders',
                  style: GoogleFonts.inter(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.primaryText)),
              TextButton(
                  onPressed: () => widget.onSwitchTab(1),
                  child: Text('View All',
                      style: GoogleFonts.inter(
                          color: themeProvider.gas2doorPrimaryBlue,
                          fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 12.0),
            if (isLoading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator()))
            else if (orders.isEmpty)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 48,
                                color: themeProvider.secondaryText
                                    .withOpacity(0.6)),
                            const SizedBox(height: 10),
                            Text('No recent orders.',
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: themeProvider.secondaryText)),
                          ])))
            else
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _buildRecentOrderItemEnhanced(
                      order: order,
                      themeProvider: themeProvider,
                      onTap: () => _navigateToOrderDetails(order.id));
                },
                separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: themeProvider.tertiaryText.withOpacity(0.1)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrderItemEnhanced(
      {required app_order.Order order,
      required ThemeProvider themeProvider,
      VoidCallback? onTap}) {
    Color statusColorVal;
    IconData statusIcon = Icons.info_outline;
    String orderStatus = order.status.toLowerCase();

    if (orderStatus == 'delivered') {
      statusColorVal = themeProvider.successColor;
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (orderStatus == 'processing' ||
        orderStatus == 'cylinder refilling') {
      statusColorVal = themeProvider.warningColor;
      statusIcon = Icons.hourglass_top_rounded;
    } else if (orderStatus == 'out for delivery') {
      statusColorVal = themeProvider.warningColor;
      statusIcon = Icons.local_shipping_outlined;
    } else if (orderStatus == 'cancelled') {
      statusColorVal = themeProvider.errorColor;
      statusIcon = Icons.cancel_outlined;
    } else {
      statusColorVal = themeProvider.secondaryText;
      statusIcon = Icons.info_outline;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
      leading: CircleAvatar(
          backgroundColor: statusColorVal.withOpacity(0.15),
          child: Icon(statusIcon, color: statusColorVal, size: 22)),
      title: Text('Order #${order.shortOrderId}',
          style: GoogleFonts.inter(
              fontSize: 15.0,
              fontWeight: FontWeight.w600,
              color: themeProvider.primaryText)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(order.itemsPreview,
              style: GoogleFonts.inter(
                  fontSize: 12.0, color: themeProvider.secondaryText)),
          Text(order.formattedOrderDate,
              style: GoogleFonts.inter(
                  fontSize: 12.0, color: themeProvider.secondaryText)),
        ],
      ),
      trailing: Text(order.status,
          style: GoogleFonts.inter(
              color: statusColorVal,
              fontWeight: FontWeight.w500,
              fontSize: 12)),
      onTap: onTap,
    );
  }

  Widget _buildSkeletonItem(
      {double height = 50,
      double width = double.infinity,
      EdgeInsetsGeometry? margin,
      required ThemeProvider themeProvider}) {
    return Container(
      height: height,
      width: width,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
          color: themeProvider.isDarkMode
              ? Colors.grey[800]!.withOpacity(0.5)
              : Colors.grey[300]!.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12.0)),
    );
  }

  void _navigateToOrderDetails(String orderId) {
    if (widget.customerIdFromShell != null) {
      Navigator.of(context).pushNamed(OrderDetailsScreen.routeName, arguments: {
        'orderId': orderId,
        'customerId': widget.customerIdFromShell
      });
    }
  }
}

class _GasCylinderFillClipper extends CustomClipper<Rect> {
  final double fillLevel;
  _GasCylinderFillClipper({required this.fillLevel});
  @override
  Rect getClip(Size size) => Rect.fromLTWH(
      0, size.height * (1 - fillLevel), size.width, size.height * fillLevel);
  @override
  bool shouldReclip(covariant _GasCylinderFillClipper oldClipper) =>
      oldClipper.fillLevel != fillLevel;
}
