// lib/screens/customer/order_details_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // <<< FIX 1: ADDED IMPORT

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/feedback_dialog.dart';
import './track_driver_screen.dart';
import './chat_screen.dart';
import './customer_dashboard_screen.dart';
import './call_screen.dart'; // <<< ADDED: Import the new CallScreen
import '../../models/driver_info_for_order.dart'; // Used for driver info in this screen
import '../../providers/auth_provider.dart'; // <<< ADDED: Import AuthProvider to get current user ID

import '../../services/api_service.dart';
import '../../models/order.dart' as app_order;
import '../../models/driver_info_for_order.dart';

class OrderStatusStep {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String statusKey;

  OrderStatusStep({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.statusKey,
  });
}

class OrderDetailsScreen extends StatefulWidget {
  static const String routeName = '/order_details';
  final String orderId;
  final String customerId;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.customerId,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with TickerProviderStateMixin {
  bool _isLoadingOrderDetails = true;
  bool _isCancellingOrder = false;
  bool _isInitiatingChat = false; // <<< FIX 2: DECLARED STATE VARIABLE
  app_order.Order? _orderData;
  String? _errorMessage;
  bool _feedbackPromptShown = false;

  late AnimationController _entryAnimController;
  late Animation<double> _fadeAnimation;
  late List<Animation<Offset>> _sectionSlideAnimations;
  final ApiService _apiService = ApiService();

  final List<OrderStatusStep> _statusTimelineSteps = [
    OrderStatusStep(
      statusKey: 'Order Placed',
      title: 'Order Placed',
      icon: Icons.playlist_add_check_circle_outlined,
      subtitle: "We've received your order and are processing it.",
    ),
    OrderStatusStep(
      statusKey: 'Order Confirmed',
      title: 'Order Confirmed',
      icon: Icons.thumb_up_alt_outlined,
      subtitle: 'Your order is confirmed.',
    ),
    OrderStatusStep(
      statusKey: 'Processing',
      title: 'Processing',
      icon: Icons.hourglass_top_rounded,
      subtitle: 'Your order is being prepared.',
    ),
    OrderStatusStep(
      statusKey: 'Driver Assigned',
      title: 'Driver Assigned',
      icon: Icons.person_pin_circle_outlined,
      subtitle: 'A driver has been assigned to your order.',
    ),
    OrderStatusStep(
      statusKey: 'Driver enroute to pickup cylinder',
      title: 'Driver Enroute to Pickup',
      icon: Icons.electric_moped_outlined,
      subtitle: 'Your driver is heading to pick up the cylinder.',
    ),
    OrderStatusStep(
      statusKey: 'Driver enroute to gas station',
      title: 'Driver to Gas Station',
      icon: Icons.electric_moped_outlined,
      subtitle: 'Your driver is enroute to the gas station.',
    ),
    OrderStatusStep(
      statusKey: 'Cylinder Refilling',
      title: 'Cylinder Refilling',
      icon: Icons.local_gas_station_outlined,
      subtitle: 'Your cylinder is currently being refilled.',
    ),
    OrderStatusStep(
      statusKey: 'Out for Delivery',
      title: 'Out for Delivery',
      icon: Icons.local_shipping_outlined,
      subtitle: 'Your order is on its way to you!',
    ),
    OrderStatusStep(
      statusKey: 'Delivered',
      title: 'Delivered',
      icon: Icons.check_circle_outline_rounded,
      subtitle: 'Your order has been successfully delivered.',
    ),
    OrderStatusStep(
      statusKey: 'Cancelled',
      title: 'Order Cancelled',
      icon: Icons.cancel_outlined,
      subtitle: 'This order has been cancelled.',
    ),
    OrderStatusStep(
      statusKey: 'Pending Payment',
      title: 'Pending Payment',
      icon: Icons.pending_actions_outlined,
      subtitle: 'Awaiting your payment to confirm the order.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entryAnimController, curve: Curves.easeIn));
    _sectionSlideAnimations = List.generate(
        6,
        (index) => Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _entryAnimController,
                curve: Interval(
                    0.1 * index, (0.6 + 0.1 * index).clamp(0.0, 1.0),
                    curve: Curves.easeOutCubic))));

    _fetchOrderDetails();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrderDetails({bool isRefresh = false}) async {
    if (!mounted) return;
    if (!isRefresh) {
      setState(() => _isLoadingOrderDetails = true);
    }

    try {
      final fetchedOrder = await _apiService.getOrderDetails(widget.orderId);
      if (mounted) {
        setState(() {
          _orderData = fetchedOrder;
          _isLoadingOrderDetails = false;
          _errorMessage = null;
        });
        _entryAnimController.forward(from: 0.0);
        _promptForFeedbackIfNeeded(fetchedOrder);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOrderDetails = false;
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
        });
      }
    }
  }

  Future<void> _handleInitiateCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showFeedbackSnackbar("Driver's phone number is not available.",
          isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw Exception('Could not launch dialer');
      }
    } catch (e) {
      _showFeedbackSnackbar('Could not launch phone dialer.', isError: true);
    }
  }

  Future<void> _handleInitiateChat() async {
    if (widget.customerId.isEmpty || _orderData?.driver == null) {
      _showFeedbackSnackbar("Driver details not available to start chat.",
          isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _isInitiatingChat = true);

    try {
      final chatId = await _apiService.initiateChatSession(
        orderId: widget.orderId,
        recipientId: _orderData!.driver!.id,
      );

      if (mounted) {
        Navigator.of(context).pushNamed(ChatScreen.routeName, arguments: {
          'orderId': chatId,
          'currentUserId': widget.customerId,
          'recipientId': _orderData!.driver!.id,
          'recipientName': _orderData!.driver!.name,
          'recipientPhoneNumber': _orderData!.driver!.phone,
          'recipientPhotoUrl': null, // <<< FIX 3: PASS NULL, NO PHOTOURL
        });
      }
    } catch (e) {
      _showFeedbackSnackbar(
          "Could not start chat: ${e.toString().replaceFirst("Exception: ", "")}",
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isInitiatingChat = false);
      }
    }
  }

  void _promptForFeedbackIfNeeded(app_order.Order order) {
    if (order.status == 'Delivered' &&
        order.feedback == null &&
        !_feedbackPromptShown) {
      setState(() => _feedbackPromptShown = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return FeedbackDialog(
                orderId: order.id,
                customerId: widget.customerId,
                onFeedbackSubmitted: () {
                  _fetchOrderDetails(isRefresh: true);
                },
              );
            },
          );
        }
      });
    }
  }

  Future<void> _handleCancelOrder() async {
    if (_orderData == null) return;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        return AlertDialog(
          backgroundColor: themeProvider.cardBackground,
          title: Text('Confirm Cancellation',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: themeProvider.primaryText)),
          content: Text('Are you sure you want to cancel this order?',
              style: GoogleFonts.inter(color: themeProvider.secondaryText)),
          actions: <Widget>[
            TextButton(
                child: Text('No',
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
                onPressed: () => Navigator.of(context).pop(false)),
            TextButton(
                child: Text('Yes, Cancel',
                    style: GoogleFonts.inter(color: themeProvider.errorColor)),
                onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );

    if (shouldCancel == true) {
      setState(() => _isCancellingOrder = true);
      try {
        final result = await _apiService.cancelOrder(_orderData!.id);
        _showFeedbackSnackbar(
            result['message'] ?? 'Order cancelled successfully.',
            isSuccess: true);
        await _fetchOrderDetails(isRefresh: true);
      } catch (e) {
        _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
            isError: true);
      } finally {
        if (mounted) setState(() => _isCancellingOrder = false);
      }
    }
  }

  void _showFeedbackSnackbar(String message,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: isError
          ? themeProvider.errorColor
          : (isSuccess
              ? themeProvider.successColor
              : themeProvider.gas2doorPrimaryBlue),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        title: Text('Order Details',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, color: themeProvider.primaryText)),
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: themeProvider.primaryText),
            onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
              icon:
                  Icon(Icons.refresh_rounded, color: themeProvider.primaryText),
              onPressed: () => _fetchOrderDetails(isRefresh: true),
              tooltip: "Refresh")
        ],
      ),
      body: _isLoadingOrderDetails
          ? _buildLoadingState(themeProvider)
          : _errorMessage != null || _orderData == null
              ? _buildErrorState(
                  themeProvider, _errorMessage ?? "Order could not be found.")
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SlideTransition(
                            position: _sectionSlideAnimations[0],
                            child: _buildOrderInfoCard(
                                _orderData!, themeProvider)),
                        const SizedBox(height: 16),
                        SlideTransition(
                            position: _sectionSlideAnimations[1],
                            child: _buildOrderStatusTimelineCard(
                                _orderData!, themeProvider)),
                        const SizedBox(height: 16),
                        SlideTransition(
                            position: _sectionSlideAnimations[2],
                            child: _buildItemsOrderedCard(
                                _orderData!, themeProvider)),
                        const SizedBox(height: 16),
                        if (_orderData!.driver != null)
                          SlideTransition(
                              position: _sectionSlideAnimations[3],
                              child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: _buildDriverInfoCard(
                                      _orderData!.driver!,
                                      _orderData!,
                                      themeProvider))),
                        SlideTransition(
                            position: _sectionSlideAnimations[4],
                            child: _buildDeliveryAddressCard(
                                _orderData!, themeProvider)),
                        const SizedBox(height: 16),
                        SlideTransition(
                            position: _sectionSlideAnimations[5],
                            child: _buildPricingSummaryCard(
                                _orderData!, themeProvider)),
                        const SizedBox(height: 24),
                        SlideTransition(
                            position: _sectionSlideAnimations[5],
                            child: _buildActionButtons(
                                _orderData!, themeProvider)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildLoadingState(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSkeletonItem(height: 200, themeProvider: themeProvider),
          const SizedBox(height: 16),
          _buildSkeletonItem(height: 120, themeProvider: themeProvider),
          const SizedBox(height: 16),
          _buildSkeletonItem(height: 100, themeProvider: themeProvider),
          const SizedBox(height: 16),
          _buildSkeletonItem(height: 150, themeProvider: themeProvider),
        ],
      ),
    );
  }

  Widget _buildSkeletonItem({
    double height = 50,
    double width = double.infinity,
    required ThemeProvider themeProvider,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      height: height,
      width: width,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.grey[800]!.withOpacity(0.5)
            : Colors.grey[300]!.withOpacity(0.7),
        borderRadius: themeProvider.cardBorderRadius,
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Failed to Load Order',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                style: GoogleFonts.inter(
                    color: themeProvider.secondaryText, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            CustomButton(
                text: "Retry",
                onPressed: () => _fetchOrderDetails(isRefresh: true),
                color: themeProvider.gas2doorPrimaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard(
      app_order.Order order, ThemeProvider themeProvider) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Information',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            _buildDetailRow("Order ID:", order.shortOrderId, themeProvider),
            _buildDetailRow("Date:", order.formattedOrderDate, themeProvider),
            _buildDetailRow("Status:", order.status, themeProvider,
                valueColor: _getStatusColor(order.status, themeProvider)),
            _buildDetailRow(
                "Payment Status:", order.paymentStatus, themeProvider,
                valueColor: order.paymentStatus.toLowerCase() == 'completed'
                    ? themeProvider.successColor
                    : themeProvider.warningColor),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusTimelineCard(
      app_order.Order order, ThemeProvider themeProvider) {
    final List<OrderStatusStep> displayableTimeline = [];

    final bool isTerminal = order.status == 'Cancelled' ||
        order.status.startsWith('Pickup Failed:') ||
        order.status.startsWith('Delivery Issue');

    if (isTerminal) {
      final terminalStep = _statusTimelineSteps.firstWhere(
          (s) => s.statusKey == order.status,
          orElse: () => OrderStatusStep(
              statusKey: order.status,
              title: order.status,
              icon: Icons.info_outline));
      displayableTimeline.add(terminalStep);
    } else {
      if (order.status == 'Pending Payment') {
        displayableTimeline.add(_statusTimelineSteps
            .firstWhere((s) => s.statusKey == 'Pending Payment'));
      } else {
        int currentStatusIndex = _statusTimelineSteps
            .indexWhere((step) => step.statusKey == order.status);

        if (currentStatusIndex != -1) {
          for (int i = 0; i <= currentStatusIndex; i++) {
            if (_statusTimelineSteps[i].statusKey != 'Pending Payment') {
              displayableTimeline.add(_statusTimelineSteps[i]);
            }
          }
        } else {
          displayableTimeline.add(OrderStatusStep(
              statusKey: order.status,
              title: order.status,
              icon: Icons.info_outline,
              subtitle: "Current status"));
        }
      }
    }

    int currentDisplayStatusIndex = displayableTimeline
        .indexWhere((step) => step.statusKey == order.status);
    if (currentDisplayStatusIndex == -1 && displayableTimeline.isNotEmpty) {
      currentDisplayStatusIndex = displayableTimeline.length - 1;
    }

    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Progress',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.primaryText,
                )),
            const SizedBox(height: 16),
            if (displayableTimeline.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("Status information unavailable.",
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayableTimeline.length,
                itemBuilder: (context, index) {
                  final step = displayableTimeline[index];
                  final bool isCompleted = index < currentDisplayStatusIndex;
                  final bool isCurrent = index == currentDisplayStatusIndex;

                  Color iconColor, lineColor, titleColor;
                  FontWeight titleFontWeight = FontWeight.w500;

                  if (isCompleted) {
                    iconColor = themeProvider.gas2doorTeal;
                    lineColor = themeProvider.gas2doorTeal;
                    titleColor = themeProvider.primaryText;
                  } else if (isCurrent) {
                    iconColor = step.statusKey == 'Cancelled' ||
                            step.statusKey.startsWith('Pickup Failed:') ||
                            step.statusKey.startsWith('Delivery Issue:')
                        ? themeProvider.errorColor
                        : themeProvider.gas2doorPrimaryBlue;
                    lineColor = iconColor;
                    titleFontWeight = FontWeight.bold;
                    titleColor = iconColor;
                  } else {
                    iconColor = themeProvider.tertiaryText.withOpacity(0.6);
                    lineColor = themeProvider.tertiaryText.withOpacity(0.3);
                    titleColor = themeProvider.secondaryText;
                  }

                  return _buildTimelineStep(
                    step: step,
                    isFirst: index == 0,
                    isLast: index == displayableTimeline.length - 1,
                    iconColor: iconColor,
                    lineColor: lineColor,
                    titleFontWeight: titleFontWeight,
                    titleColor: titleColor,
                    themeProvider: themeProvider,
                    isCurrent: isCurrent,
                    isCompleted: isCompleted,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required OrderStatusStep step,
    required bool isFirst,
    required bool isLast,
    required Color iconColor,
    required Color lineColor,
    required FontWeight titleFontWeight,
    required Color titleColor,
    required ThemeProvider themeProvider,
    required bool isCurrent,
    required bool isCompleted,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isFirst)
              Container(
                  width: 2,
                  height: 10,
                  color: lineColor
                      .withOpacity(isCompleted || isCurrent ? 0.8 : 0.4)),
            Icon(
              step.icon,
              color: iconColor,
              size: isCurrent ? 26 : 22,
            ),
            if (!isLast)
              Container(
                  width: 2,
                  height: isCurrent ? 38 : 36,
                  color: lineColor.withOpacity(isCompleted ? 0.8 : 0.4)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(top: isCurrent ? 3 : 1, bottom: isLast ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: titleFontWeight,
                      color: titleColor,
                    )),
                if (step.subtitle != null && (isCurrent || isCompleted)) ...[
                  const SizedBox(height: 3),
                  Text(
                      isCurrent
                          ? (step.subtitle ?? 'In progress...')
                          : (isCompleted ? (step.subtitle ?? 'Completed') : ''),
                      style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: themeProvider.secondaryText.withOpacity(0.9),
                          height: 1.3)),
                ],
                if (!isLast) const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsOrderedCard(
      app_order.Order order, ThemeProvider themeProvider) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items Ordered (${order.items.length})',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.primaryText,
                )),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: order.items.length,
              itemBuilder: (context, index) {
                final item = order.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.propane_tank_outlined,
                        color: themeProvider.gas2doorTeal,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${item.quantity}x ${item.productName}',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: themeProvider.primaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        currencyFormat
                            .format(item.unitPrice * item.quantity / 100),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.primaryText,
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) => Divider(
                  color: themeProvider.tertiaryText.withOpacity(0.2),
                  height: 1,
                  thickness: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryAddressCard(
      app_order.Order order, ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery Address',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.primaryText,
                )),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: themeProvider.gas2doorPrimaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    order.deliveryAddressSnapshot.fullAddress,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      color: themeProvider.secondaryText,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSummaryCard(
      app_order.Order order, ThemeProvider themeProvider) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Summary',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.primaryText,
                )),
            const SizedBox(height: 12),
            _buildDetailRow(
                "Items Subtotal:",
                currencyFormat.format(order.itemsSubtotal / 100),
                themeProvider),
            _buildDetailRow(
                "VAT:",
                '+ ${currencyFormat.format(order.vatAmount / 100)}',
                themeProvider),
            _buildDetailRow(
                "Service Fee:",
                '+ ${currencyFormat.format(order.serviceFeeAmount / 100)}',
                themeProvider),
            _buildDetailRow(
                "Delivery Fee${order.isExpressDelivery ? ' (Express)' : ''}:",
                '+ ${currencyFormat.format(order.deliveryFee / 100)}',
                themeProvider),
            if (order.discountAmount > 0)
              _buildDetailRow(
                  "Discount Applied:",
                  '- ${currencyFormat.format(order.discountAmount / 100)}',
                  themeProvider,
                  isDiscount: true),
            if (order.walletAmountUsed > 0)
              _buildDetailRow(
                  "Wallet Deduction:",
                  '- ${currencyFormat.format(order.walletAmountUsed / 100)}',
                  themeProvider,
                  isDiscount: true),
            Divider(
                height: 24,
                color: themeProvider.tertiaryText.withOpacity(0.3),
                thickness: 0.5),
            _buildDetailRow(
                "Grand Total Paid:",
                currencyFormat.format(order.finalAmountPaid / 100),
                themeProvider,
                isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      String label, String value, ThemeProvider themeProvider,
      {bool isTotal = false, bool isDiscount = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: isTotal ? 16 : 14,
                  color: themeProvider.secondaryText,
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: isTotal ? 17 : 15,
                  color: valueColor ??
                      (isDiscount
                          ? themeProvider.successColor
                          : themeProvider.primaryText),
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard(DriverInfoForOrder driver, app_order.Order order,
      ThemeProvider themeProvider) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Driver',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        themeProvider.gas2doorTeal.withOpacity(0.15),
                    child: Icon(Icons.person_rounded,
                        size: 30, color: themeProvider.gas2doorTeal)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.name,
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.primaryText)),
                      if (driver.vehicleType != null &&
                          driver.licensePlate != null)
                        Text('${driver.vehicleType} - ${driver.licensePlate}',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: themeProvider.secondaryText)),
                    ],
                  ),
                ),
                if (driver.phone != null && driver.phone!.isNotEmpty)
                  IconButton(
                      icon: Icon(Icons.call_outlined,
                          color: themeProvider.gas2doorPrimaryBlue, size: 26),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _showFeedbackSnackbar(
                            'Calling driver ${driver.phone}...',
                            isSuccess: true);
                      },
                      tooltip: "Call Driver"),
                IconButton(
                    icon: Icon(Icons.chat_bubble_outline_rounded,
                        color: themeProvider.gas2doorPrimaryBlue, size: 26),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (order.customer?.id == null) {
                        _showFeedbackSnackbar(
                            "Cannot initiate chat: Customer ID missing.",
                            isError: true);
                        return;
                      }
                      Navigator.of(context, rootNavigator: true).pushNamed(
                        ChatScreen.routeName,
                        arguments: {
                          'orderId': order.id,
                          'currentUserId': order.customer!.id,
                          'recipientId': driver.id,
                          'recipientName': driver.name,
                          'recipientPhoneNumber': driver.phone,
                        },
                      );
                    },
                    tooltip: "Chat with Driver")
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================== FIX IS HERE ==========================
  Widget _buildActionButtons(
      app_order.Order order, ThemeProvider themeProvider) {
    List<Widget> buttons = [];
    String normalizedStatus = order.status.toLowerCase();

    // The 'Track My Order' button has been removed from this logic block.

    if (normalizedStatus == "delivered" && order.feedback == null) {
      buttons.add(CustomButton(
        text: 'Submit Feedback',
        onPressed: () => _promptForFeedbackIfNeeded(order),
        color: themeProvider.gas2doorPrimaryBlueLightVer,
        icon: Icon(Icons.rate_review_outlined, color: Colors.white),
      ));
    }

    if (order.status == 'Pending Payment' ||
        order.status == 'Order Placed' ||
        order.status == 'Order Confirmed') {
      buttons.add(CustomButton(
          text: 'Cancel Order',
          onPressed: _isCancellingOrder ? null : _handleCancelOrder,
          color: themeProvider.errorColor.withOpacity(0.15),
          textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600, color: themeProvider.errorColor),
          icon: Icon(Icons.cancel_outlined, color: themeProvider.errorColor),
          elevation: 0));
    }

    // A "Return to Dashboard" button is now added.
    buttons.add(
      CustomButton(
        text: 'Return to Dashboard',
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pushNamedAndRemoveUntil(
            CustomerDashboardScreen.routeName,
            (route) => false,
          );
        },
        color: themeProvider.gas2doorTeal,
        icon: Icon(Icons.dashboard_outlined, color: Colors.white),
      ),
    );

    buttons.add(
      Padding(
        padding: EdgeInsets.only(top: buttons.isNotEmpty ? 12.0 : 0.0),
        child: TextButton.icon(
          icon: Icon(Icons.support_agent_outlined,
              color: themeProvider.secondaryText),
          label: Text('Get Help / Support',
              style: GoogleFonts.inter(color: themeProvider.secondaryText)),
          onPressed: () =>
              _showFeedbackSnackbar('Support channel not yet implemented.'),
        ),
      ),
    );

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons
            .map((button) => Padding(
                padding: const EdgeInsets.only(top: 14.0), child: button))
            .toList());
  }

  Color _getStatusColor(String status, ThemeProvider themeProvider) {
    String normalizedStatus = status.toLowerCase();
    if (normalizedStatus.contains('delivered')) {
      return themeProvider.successColor;
    } else if (normalizedStatus.contains('cancelled')) {
      return themeProvider.errorColor;
    } else if (normalizedStatus.contains('confirmed')) {
      return themeProvider.gas2doorPrimaryBlue;
    } else if (normalizedStatus.contains('placed')) {
      return themeProvider.gas2doorTeal;
    } else if (normalizedStatus.contains('driver assigned')) {
      return themeProvider.warningColor;
    } else if (normalizedStatus.contains('enroute') ||
        (normalizedStatus.contains('delivery') &&
            !normalizedStatus.contains('delivered'))) {
      return themeProvider.warningColor;
    } else if (normalizedStatus.contains('processing') ||
        normalizedStatus.contains('refilling')) {
      return themeProvider.warningColor;
    } else if (normalizedStatus.contains('pending payment')) {
      return themeProvider.secondaryText.withOpacity(0.8);
    }
    return themeProvider.secondaryText;
  }
}
