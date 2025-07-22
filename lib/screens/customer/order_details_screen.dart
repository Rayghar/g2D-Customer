// lib/screens/customer/order_details_screen.dart
// ADVISORY: This is the final version with the new, more detailed 6-step timeline.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/feedback_dialog.dart';
import './chat_screen.dart';
import '../../models/driver_info_for_order.dart';
import '../../services/api_service.dart';
import '../../models/order.dart' as app_order;

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
  app_order.Order? _orderData;
  String? _errorMessage;
  bool _feedbackPromptShown = false;

  late AnimationController _entryAnimController;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
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
    HapticFeedback.lightImpact();
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await canLaunchUrl(launchUri)) {
      _showFeedbackSnackbar('Could not launch phone dialer.', isError: true);
    } else {
      await launchUrl(launchUri);
    }
  }

  void _promptForFeedbackIfNeeded(app_order.Order order) {
    if (order.status.toLowerCase() == 'delivered' &&
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
                onFeedbackSubmitted: () => _fetchOrderDetails(isRefresh: true),
              );
            },
          );
        }
      });
    }
  }

  Future<void> _handleCancelOrder() async {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
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
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null || _orderData == null
              ? _buildErrorState(
                  themeProvider, _errorMessage ?? "Order could not be found.")
              : FadeTransition(
                  opacity: _entryAnimController,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusAndProgressCard(_orderData!, themeProvider),
                        const SizedBox(height: 16),
                        _buildItemsOrderedCard(_orderData!, themeProvider),
                        const SizedBox(height: 16),
                        if (_orderData!.driver != null)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildDriverInfoCard(_orderData!.driver!,
                                  _orderData!, themeProvider)),
                        _buildDeliveryAddressCard(_orderData!, themeProvider),
                        const SizedBox(height: 16),
                        _buildPricingSummaryCard(_orderData!, themeProvider),
                        const SizedBox(height: 24),
                        _buildActionButtons(_orderData!, themeProvider),
                      ],
                    ),
                  ),
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

  Widget _buildStatusAndProgressCard(
      app_order.Order order, ThemeProvider themeProvider) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${order.shortOrderId}',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Placed on: ${order.formattedOrderDate}',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: themeProvider.secondaryText)),
            ),
            Divider(color: themeProvider.tertiaryText.withOpacity(0.2)),
            const SizedBox(height: 16),
            _buildVisualTimeline(order, themeProvider),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // NEW: Redesigned timeline with 6 steps and original backend logic
  // =======================================================================
  Widget _buildVisualTimeline(
      app_order.Order order, ThemeProvider themeProvider) {
    final timelineSteps = [
      {
        'key': 'Order Placed',
        'title': 'Placed',
        'icon': Icons.playlist_add_check_circle_outlined
      },
      {
        'key': 'Processing',
        'title': 'Processing',
        'icon': Icons.hourglass_top_rounded
      },
      {
        'key': 'Driver on the way',
        'title': 'Driver on Way',
        'icon': Icons.person_pin_circle_outlined
      },
      {
        'key': 'Refilling',
        'title': 'Refilling',
        'icon': Icons.local_gas_station_outlined
      },
      {
        'key': 'Out for Delivery',
        'title': 'Out for Delivery',
        'icon': Icons.local_shipping_outlined
      },
      {
        'key': 'Delivered',
        'title': 'Delivered',
        'icon': Icons.check_circle_outline_rounded
      },
    ];

    final Map<String, int> statusMap = {
      // Stage 0
      'order placed': 0,
      'pending payment': 0,
      'order confirmed': 0,
      // Stage 1
      'processing': 1,
      // Stage 2
      'driver assigned': 2,
      'driver enroute to pickup': 2,
      // Stage 3
      'driver enroute to gas station': 3,
      'cylinder refilling': 3,
      // Stage 4
      'out for delivery': 4,
      // Stage 5
      'delivered': 5,
    };

    int currentStepIndex = statusMap[order.status.toLowerCase()] ?? -1;

    if (order.status.toLowerCase().contains('cancelled')) {
      return _buildTimelineStep(
          icon: Icons.cancel,
          title: "Order Cancelled",
          subtitle: "This order was cancelled.",
          themeProvider: themeProvider,
          isCurrent: true,
          isFirst: true,
          isLast: true,
          isCompleted: false);
    }

    return Column(
      children: List.generate(timelineSteps.length, (index) {
        final step = timelineSteps[index];
        final bool isCompleted = index < currentStepIndex;
        final bool isCurrent = index == currentStepIndex;
        return _buildTimelineStep(
          icon: step['icon'] as IconData,
          title: step['title'] as String,
          subtitle: isCurrent
              ? order.status
              : (isCompleted ? "Completed" : "Pending"),
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isFirst: index == 0,
          isLast: index == timelineSteps.length - 1,
          themeProvider: themeProvider,
        );
      }),
    );
  }

  Widget _buildTimelineStep(
      {required IconData icon,
      required String title,
      required String subtitle,
      required bool isFirst,
      required bool isLast,
      required bool isCompleted,
      required bool isCurrent,
      required ThemeProvider themeProvider}) {
    final Color activeColor = themeProvider.gas2doorTeal;
    final Color inactiveColor = themeProvider.tertiaryText.withOpacity(0.4);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                  width: 2,
                  height: 4,
                  color: isFirst
                      ? Colors.transparent
                      : (isCompleted || isCurrent
                          ? activeColor
                          : inactiveColor)),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted || isCurrent ? activeColor : inactiveColor,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              Expanded(
                  child: Container(
                      width: 2,
                      color: isLast
                          ? Colors.transparent
                          : (isCompleted ? activeColor : inactiveColor))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0.0 : 24.0, top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.w500,
                          fontSize: 15,
                          color: isCurrent
                              ? activeColor
                              : themeProvider.primaryText)),
                  if (isCurrent || isCompleted)
                    Text(subtitle,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: themeProvider.secondaryText)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildItemsOrderedCard(
      app_order.Order order, ThemeProvider themeProvider) {
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items Ordered (${order.items.length})',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
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
                      Icon(Icons.propane_tank_outlined,
                          color: themeProvider.gas2doorTeal, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text('${item.quantity}x ${item.productName}',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: themeProvider.primaryText,
                                  fontWeight: FontWeight.w500))),
                      Text(
                          currencyFormat
                              .format((item.unitPrice * item.quantity) / 100),
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.primaryText)),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery Address',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined,
                    color: themeProvider.gas2doorPrimaryBlue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(order.deliveryAddressSnapshot.fullAddress,
                        style: GoogleFonts.inter(
                            fontSize: 14.5,
                            color: themeProvider.secondaryText,
                            height: 1.4))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSummaryCard(
      app_order.Order order, ThemeProvider themeProvider) {
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Summary',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
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
                '+ ${currencyFormat.format(order.deliveryFee)}',
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
                      onPressed: () => _handleInitiateCall(driver.phone),
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
                      Navigator.of(context, rootNavigator: true)
                          .pushNamed(ChatScreen.routeName, arguments: {
                        'orderId': order.id,
                        'currentUserId': order.customer!.id,
                        'recipientId': driver.id,
                        'recipientName': driver.name,
                        'recipientPhoneNumber': driver.phone,
                      });
                    },
                    tooltip: "Chat with Driver")
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      app_order.Order order, ThemeProvider themeProvider) {
    List<Widget> buttons = [];
    String normalizedStatus = order.status.toLowerCase();

    if (normalizedStatus == "delivered" && order.feedback == null) {
      buttons.add(CustomButton(
        text: 'Submit Feedback',
        onPressed: () => _promptForFeedbackIfNeeded(order),
        color: themeProvider.primaryActionColor,
        icon: Icon(Icons.rate_review_outlined, color: Colors.white),
      ));
    }

    if (normalizedStatus == 'pending payment' ||
        normalizedStatus == 'order placed' ||
        normalizedStatus == 'order confirmed') {
      buttons.add(CustomButton(
          text: 'Cancel Order',
          onPressed: _isCancellingOrder ? null : _handleCancelOrder,
          color: themeProvider.errorColor.withOpacity(0.15),
          textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600, color: themeProvider.errorColor),
          icon: Icon(Icons.cancel_outlined, color: themeProvider.errorColor),
          elevation: 0));
    }

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

  Map<String, dynamic> _getStatusVisuals(
      String status, ThemeProvider themeProvider) {
    Color statusColor;
    IconData statusIcon;
    String normalizedStatus = status.toLowerCase();
    if (normalizedStatus.contains('delivered')) {
      statusIcon = Icons.check_circle;
      statusColor = themeProvider.successColor;
    } else if (normalizedStatus.contains('cancelled')) {
      statusIcon = Icons.cancel;
      statusColor = themeProvider.errorColor;
    } else if (normalizedStatus.contains('enroute') ||
        normalizedStatus.contains('out for delivery')) {
      statusIcon = Icons.local_shipping;
      statusColor = themeProvider.warningColor;
    } else if (normalizedStatus.contains('processing') ||
        normalizedStatus.contains('assigned')) {
      statusIcon = Icons.hourglass_top;
      statusColor = themeProvider.warningColor;
    } else {
      statusIcon = Icons.info;
      statusColor = themeProvider.secondaryText;
    }
    return {'icon': statusIcon, 'color': statusColor};
  }
}
