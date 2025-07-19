import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './track_driver_screen.dart';
import './chat_screen.dart';
import './feedback_screen.dart';
import './order_details_screen.dart';
import '../../models/order.dart' as app_order;
import '../../models/driver_info_for_order.dart';
import '../../services/api_service.dart';
import '../customer/customer_dashboard_screen.dart';
import '../../models/user.dart';

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

class OrderSummaryScreen extends StatefulWidget {
  static const String routeName = '/order_summary';
  final String orderId;
  final String customerId;
  final bool showConfirmation;
  final String? transactionRef;
  final bool isVerifyingPayment;

  const OrderSummaryScreen({
    super.key,
    required this.orderId,
    required this.customerId,
    this.showConfirmation = false,
    this.transactionRef,
    this.isVerifyingPayment = false,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  app_order.Order? _orderData;

  late AnimationController _entryAnimController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ApiService _apiService = ApiService();

  final List<OrderStatusStep> _statusTimelineSteps = [
    OrderStatusStep(
        statusKey: 'Order Placed',
        title: 'Order Placed',
        icon: Icons.playlist_add_check_circle_outlined,
        subtitle: "We've received your order."),
  ];

  int _pollAttempt = 0;
  final int _maxPollAttempts = 8; // e.g., 8 * 15s = 2 minutes
  final Duration _pollInterval = const Duration(seconds: 15);
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    print(
        '[OrderSummaryScreen] initState: Screen initialized for Order ID: ${widget.orderId}');
    print(
        '[OrderSummaryScreen] initState: showConfirmation: ${widget.showConfirmation}, isVerifyingPayment: ${widget.isVerifyingPayment}');

    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entryAnimController, curve: Curves.easeIn));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryAnimController, curve: Curves.easeOutCubic));

    _fetchOrderDetails();

    if (widget.isVerifyingPayment) {
      _startPolling();
    }
  }

  @override
  void dispose() {
    print(
        '[OrderSummaryScreen] dispose: Disposing controllers and stopping polling timer.');
    _entryAnimController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrderDetails({bool forceRefresh = false}) async {
    if (!mounted) {
      print(
          '[OrderSummaryScreen] _fetchOrderDetails: Widget not mounted, aborting fetch.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    print(
        '[OrderSummaryScreen] _fetchOrderDetails: Fetching order details for Order ID: ${widget.orderId}. Force Refresh: $forceRefresh');

    try {
      final fetchedOrder = await _apiService.getOrderDetails(widget.orderId);
      if (mounted) {
        setState(() {
          _orderData = fetchedOrder;
          _isLoading = false;
        });
        _entryAnimController.forward();
        print(
            '[OrderSummaryScreen] _fetchOrderDetails: Order details fetched successfully. Status: ${_orderData?.status}, Payment Status: ${_orderData?.paymentStatus}');
      }
    } catch (e) {
      if (mounted) {
        print("[OrderSummaryScreen] Error fetching order details: $e");
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
        _showFeedbackSnackbar(
            'Failed to load order details: ${e.toString().replaceFirst("Exception: ", "")}',
            isError: true);
      }
    }
  }

  void _startPolling() {
    print(
        '[OrderSummaryScreen] _startPolling: Starting payment verification polling.');
    _pollingTimer = Timer.periodic(_pollInterval, (timer) async {
      if (_pollAttempt >= _maxPollAttempts || !mounted) {
        timer.cancel();
        print(
            '[OrderSummaryScreen] _startPolling: Polling stopped. Attempts: $_pollAttempt, Mounted: $mounted');
        return;
      }

      _pollAttempt++;
      print(
          '[OrderSummaryScreen] _startPolling: Polling attempt $_pollAttempt...');

      try {
        final paymentStatus =
            await _apiService.getOrderPaymentStatus(widget.orderId);
        if (paymentStatus == 'Completed') {
          timer.cancel();
          await _fetchOrderDetails(forceRefresh: true);
          _showFeedbackSnackbar('Payment confirmed! Order status updated.',
              isSuccess: true);
          print(
              '[OrderSummaryScreen] _startPolling: Payment confirmed on attempt $_pollAttempt. Polling stopped.');
        }
      } catch (e) {
        print('[OrderSummaryScreen] _startPolling: Error during poll: $e');
      }
    });
  }

  void _showFeedbackSnackbar(String message,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) {
      print('[OrderSummaryScreen] Snackbar not shown, widget not mounted.');
      return;
    }
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: isError
          ? themeProvider.errorColor
          : (isSuccess
                  ? themeProvider.successColor
                  : themeProvider.gas2doorPrimaryBlue)
              .withOpacity(0.95),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      elevation: 6,
    ));
    print(
        '[OrderSummaryScreen] Showing Snackbar: "$message" (isError: $isError, isSuccess: $isSuccess)');
  }

  void _navigateToOrderDetailsScreen() {
    HapticFeedback.lightImpact();
    print(
        '[OrderSummaryScreen] _navigateToOrderDetailsScreen: User initiated navigation to Order Details.');
    if (_orderData?.id != null && widget.customerId.isNotEmpty) {
      print(
          '[OrderSummaryScreen] Navigating to OrderDetailsScreen for Order ID: ${_orderData!.id}');
      Navigator.of(context, rootNavigator: true)
          .pushNamed(OrderDetailsScreen.routeName, arguments: {
        'orderId': _orderData!.id,
        'customerId': widget.customerId,
      });
    } else {
      _showFeedbackSnackbar(
          'Tracking details are not available. Customer or Order ID missing.',
          isError: true);
      print(
          '[OrderSummaryScreen] Cannot navigate to Order Details: Order or Customer ID missing.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appBarTitle =
        widget.showConfirmation ? 'Order Confirmed!' : 'Order Summary';
    final currencyFormat =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

    print(
        '[OrderSummaryScreen] build: Rebuilding OrderSummaryScreen. AppBarTitle: $appBarTitle');

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text(appBarTitle,
            style: GoogleFonts.inter(
                color: widget.showConfirmation &&
                        _orderData?.paymentStatus == 'Completed'
                    ? themeProvider.successColor
                    : themeProvider.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: themeProvider.primaryText),
            onPressed: () {
              print(
                  '[OrderSummaryScreen] AppBar back button pressed. showConfirmation: ${widget.showConfirmation}');
              if (widget.showConfirmation) {
                Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil(
                        CustomerDashboardScreen.routeName, (route) => false);
              } else {
                Navigator.of(context).pop();
              }
            }),
      ),
      body: RefreshIndicator(
        onRefresh: () {
          print(
              '[OrderSummaryScreen] Pull-to-refresh triggered. Refetching order details.');
          return _fetchOrderDetails(forceRefresh: true);
        },
        child: _isLoading
            ? _buildLoadingState(themeProvider)
            : _errorMessage != null || _orderData == null
                ? _buildErrorState(
                    themeProvider, _errorMessage ?? "Order summary not found.")
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.showConfirmation)
                              _buildConfirmationMessage(themeProvider),
                            const SizedBox(height: 16),
                            _buildOrderInfoCard(_orderData!, themeProvider),
                            const SizedBox(height: 16),
                            _buildItemsOrderedCard(_orderData!, themeProvider),
                            const SizedBox(height: 16),
                            if (_orderData!.driver != null &&
                                ![
                                  'Order Placed',
                                  'Order Confirmed',
                                  'Processing',
                                  'Cancelled',
                                  'Pending Payment'
                                ].contains(_orderData!.status))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: _buildDriverInfoCard(_orderData!.driver!,
                                    _orderData!, themeProvider, context),
                              ),
                            _buildDeliveryAddressCard(
                                _orderData!, themeProvider),
                            const SizedBox(height: 16),
                            _buildPricingSummaryCard(
                                _orderData!, themeProvider),
                            const SizedBox(height: 24),
                            _buildActionButtons(
                                _orderData!, themeProvider, context),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeProvider themeProvider) {
    print('[OrderSummaryScreen] Displaying loading state.');
    return Center(
      child:
          CircularProgressIndicator(color: themeProvider.gas2doorPrimaryBlue),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String message) {
    print('[OrderSummaryScreen] Displaying error state: $message');
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline_rounded,
                  color: themeProvider.errorColor, size: 50),
              const SizedBox(height: 16),
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
                  text: 'Retry',
                  onPressed: () {
                    print('[OrderSummaryScreen] Retry button pressed.');
                    _fetchOrderDetails();
                  },
                  color: themeProvider.gas2doorPrimaryBlue),
            ])));
  }

  Widget _buildConfirmationMessage(ThemeProvider themeProvider) {
    String message = '';
    IconData icon = Icons.check_circle_outline_rounded;
    Color color = themeProvider.successColor;

    if (_orderData?.paymentStatus == 'Completed') {
      message = 'Your order has been placed and payment confirmed!';
      icon = Icons.check_circle_outline_rounded;
      color = themeProvider.successColor;
      print('[OrderSummaryScreen] Confirmation message: Payment Completed.');
    } else if (_orderData?.paymentStatus == 'Pending') {
      message = 'Order placed. Payment is pending confirmation.';
      icon = Icons.pending_actions_outlined;
      color = themeProvider.warningColor;
      print('[OrderSummaryScreen] Confirmation message: Payment Pending.');
    } else if (_orderData?.paymentStatus == 'Failed') {
      message = 'Order placed, but payment failed. Please try again.';
      icon = Icons.error_outline_rounded;
      color = themeProvider.errorColor;
      print('[OrderSummaryScreen] Confirmation message: Payment Failed.');
    } else if (_orderData?.paymentStatus?.contains('Discrepancy') ?? false) {
      message =
          'Order placed, but payment amount mismatch. Please contact support.';
      icon = Icons.warning_amber_rounded;
      color = themeProvider.errorColor;
      print('[OrderSummaryScreen] Confirmation message: Payment Discrepancy.');
    } else {
      message = 'Order placed. Verifying payment...';
      icon = Icons.info_outline;
      color = themeProvider.gas2doorPrimaryBlue;
      print('[OrderSummaryScreen] Confirmation message: Payment Verifying.');
    }

    return CustomCard(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard(
      app_order.Order order, ThemeProvider themeProvider) {
    Color statusColor;
    IconData statusIcon;
    String normalizedStatus = order.status.toLowerCase();

    switch (normalizedStatus) {
      case 'delivered':
        statusIcon = Icons.check_circle_outline_rounded;
        statusColor = themeProvider.successColor;
        break;
      case 'order confirmed':
        statusIcon = Icons.thumb_up_alt_outlined;
        statusColor = themeProvider.gas2doorPrimaryBlue;
        break;
      case 'processing':
      case 'cylinder refilling':
        statusIcon = Icons.hourglass_top_rounded;
        statusColor = themeProvider.warningColor;
        break;
      case 'driver assigned':
        statusIcon = Icons.person_pin_circle_outlined;
        statusColor = themeProvider.warningColor;
        break;
      case 'driver enroute to pickup cylinder':
      case 'driver enroute to gas station':
        statusIcon = Icons.electric_moped_outlined;
        statusColor = themeProvider.warningColor;
        break;
      case 'out for delivery':
        statusIcon = Icons.local_shipping_outlined;
        statusColor = themeProvider.warningColor;
        break;
      case 'cancelled':
      case 'canceled by customer':
      case 'canceled by admin':
        statusIcon = Icons.cancel_outlined;
        statusColor = themeProvider.errorColor;
        break;
      case 'order placed':
        statusIcon = Icons.playlist_add_check_circle_outlined;
        statusColor = themeProvider.gas2doorTeal;
        break;
      case 'pending payment':
        statusIcon = Icons.payment_outlined;
        statusColor = themeProvider.warningColor.withOpacity(0.8);
        break;
      case 'payment discrepancy':
        statusIcon = Icons.warning_amber_rounded;
        statusColor = themeProvider.errorColor;
        break;
      case 'failed':
        statusIcon = Icons.error_outline_rounded;
        statusColor = themeProvider.errorColor;
        break;
      default:
        statusIcon = Icons.info_outline;
        statusColor = themeProvider.secondaryText;
    }
    print(
        '[OrderSummaryScreen] Order Info Card: Order ID: ${order.shortOrderId}, Status: ${order.status}, Payment Status: ${order.paymentStatus}');

    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
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
            _buildDetailRow(
                "Date:",
                DateFormat('MMM dd, yyyy - hh:mm a')
                    .format(order.orderDate.toLocal()),
                themeProvider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Status:",
                      style: GoogleFonts.inter(
                          fontSize: 14, color: themeProvider.secondaryText)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 5),
                      Text(order.status,
                          style: GoogleFonts.inter(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Payment Status:",
                      style: GoogleFonts.inter(
                          fontSize: 14, color: themeProvider.secondaryText)),
                  Text(order.paymentStatus,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color:
                              order.paymentStatus.toLowerCase() == 'completed'
                                  ? themeProvider.successColor
                                  : (order.paymentStatus.toLowerCase() ==
                                              'failed' ||
                                          order.paymentStatus
                                              .toLowerCase()
                                              .contains('discrepancy')
                                      ? themeProvider.errorColor
                                      : themeProvider.warningColor))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsOrderedCard(
      app_order.Order order, ThemeProvider themeProvider) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
    final currencyFormatWithKobo =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

    print(
        '[OrderSummaryScreen] Items Ordered Card: ${order.items.length} items.');
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                print(
                    '[OrderSummaryScreen] Item: ${item.quantity}x ${item.productName} at ${item.unitPrice / 100} each.');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(children: [
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
                        currencyFormatWithKobo
                            .format(item.unitPrice * item.quantity / 100),
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.primaryText)),
                  ]),
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
    print(
        '[OrderSummaryScreen] Delivery Address Card: ${order.deliveryAddressSnapshot.fullAddress}');
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
    final currencyFormat =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
    final currencyFormatWithKobo =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

    print(
        '[OrderSummaryScreen] Pricing Summary Card: Items Subtotal: ${order.itemsSubtotal / 100}, VAT: ${order.vatAmount / 100}, Service Fee: ${order.serviceFeeAmount / 100}, Delivery Fee: ${order.deliveryFee / 100}, Discount: ${order.discountAmount / 100}, Wallet Used: ${order.walletAmountUsed / 100}, Final Paid: ${order.finalAmountPaid / 100}');
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                '+ ${currencyFormat.format(order.deliveryFee / 100)}',
                themeProvider),
            if (order.discountAmount > 0)
              _buildDetailRow(
                  "Discount Applied${order.promoCodeApplied != null ? ' (${order.promoCodeApplied})' : ''}:",
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
                currencyFormatWithKobo.format(order.finalAmountPaid / 100),
                themeProvider,
                isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      String label, String value, ThemeProvider themeProvider,
      {bool isTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: isTotal ? 16 : 14,
                  color: isDiscount
                      ? themeProvider.successColor
                      : (isTotal
                          ? themeProvider.primaryText
                          : themeProvider.secondaryText),
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(
                      fontSize: isTotal ? 17 : 15,
                      color: isDiscount
                          ? themeProvider.successColor
                          : themeProvider.primaryText,
                      fontWeight:
                          isTotal ? FontWeight.bold : FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard(DriverInfoForOrder driver, app_order.Order order,
      ThemeProvider themeProvider, BuildContext context) {
    print(
        '[OrderSummaryScreen] Driver Info Card: Driver: ${driver.name}, Vehicle: ${driver.vehicleType}, License: ${driver.licensePlate}');
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
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
                  backgroundColor: themeProvider.gas2doorTeal.withOpacity(0.15),
                  child: Icon(Icons.person_rounded,
                      size: 30, color: themeProvider.gas2doorTeal),
                ),
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
                          driver.vehicleType!.isNotEmpty)
                        Text(driver.vehicleType!,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: themeProvider.secondaryText)),
                      if (driver.licensePlate != null &&
                          driver.licensePlate!.isNotEmpty)
                        Text(driver.licensePlate!,
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
                        print(
                            '[OrderSummaryScreen] Call Driver button pressed for ${driver.name}.');
                        // Call logic can be implemented here
                      },
                      tooltip: "Call Driver"),
                IconButton(
                    icon: Icon(Icons.chat_bubble_outline_rounded,
                        color: themeProvider.gas2doorPrimaryBlue, size: 26),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      print(
                          '[OrderSummaryScreen] Chat with Driver button pressed for ${driver.name}.');
                      if (order.customer?.id == null) {
                        _showFeedbackSnackbar(
                            "Cannot initiate chat: User details missing.",
                            isError: true);
                        print(
                            '[OrderSummaryScreen] Cannot initiate chat: Order customer ID is null.');
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

  Widget _buildActionButtons(app_order.Order order, ThemeProvider themeProvider,
      BuildContext context) {
    List<Widget> buttons = [];

    buttons.add(
      CustomButton(
        text: 'View Full Order Details',
        onPressed: () {
          HapticFeedback.lightImpact();
          print(
              '[OrderSummaryScreen] View Full Order Details button pressed for Order ID: ${order.id}.');
          Navigator.of(context).pushReplacementNamed(
            OrderDetailsScreen.routeName,
            arguments: {
              'orderId': order.id,
              'customerId': widget.customerId,
            },
          );
        },
        color: themeProvider.gas2doorPrimaryBlue,
        icon: Icon(Icons.info_outline_rounded, color: Colors.white),
      ),
    );

    buttons.add(
      CustomButton(
        text: 'Return to Dashboard',
        onPressed: () {
          print('[OrderSummaryScreen] Return to Dashboard button pressed.');
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
              CustomerDashboardScreen.routeName, (route) => false);
        },
        color: themeProvider.gas2doorTeal,
        icon: Icon(Icons.dashboard_outlined,
            color: themeProvider.infoColorOnDarkBgs, size: 20),
      ),
    );

    if (order.status.toLowerCase() == "delivered") {
      print(
          '[OrderSummaryScreen] Order status is "Delivered", adding Submit Feedback button.');
      buttons.add(CustomButton(
        text: 'Submit Feedback',
        onPressed: () {
          HapticFeedback.lightImpact();
          print(
              '[OrderSummaryScreen] Submit Feedback button pressed for Order ID: ${order.id}.');
          Navigator.of(context, rootNavigator: true).pushNamed(
              FeedbackScreen.routeName,
              arguments: {'orderId': order.id});
        },
        color: themeProvider.gas2doorPrimaryBlueLightVer,
        icon: Icon(Icons.rate_review_outlined,
            color: themeProvider.infoColorOnDarkBgs, size: 20),
      ));
    }

    buttons.add(Padding(
      padding: EdgeInsets.only(top: buttons.isNotEmpty ? 10.0 : 0.0),
      child: TextButton.icon(
        icon: Icon(Icons.support_agent_outlined,
            color: themeProvider.secondaryText, size: 20),
        label: Text('Get Help / Support',
            style: GoogleFonts.inter(
                color: themeProvider.secondaryText,
                fontWeight: FontWeight.w500)),
        onPressed: () {
          HapticFeedback.lightImpact();
          _showFeedbackSnackbar('Support channel not yet implemented.',
              isError: false);
          print('[OrderSummaryScreen] Get Help / Support button pressed.');
        },
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10)),
      ),
    ));

    if (buttons.isEmpty) {
      print('[OrderSummaryScreen] No action buttons to display.');
      return const SizedBox.shrink();
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
    } else if (normalizedStatus.contains('payment discrepancy')) {
      return themeProvider.errorColor;
    } else if (normalizedStatus.contains('failed')) {
      return themeProvider.errorColor;
    }
    return themeProvider.secondaryText;
  }
}
