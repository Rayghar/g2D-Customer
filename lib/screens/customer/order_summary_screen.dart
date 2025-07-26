// File: lib/screens/customer/order_summary_screen.dart
// ADVISORY: This version includes a themed gradient for the action button container.
// UPDATE: Fixed total amount showing as 0 during verification by computing it dynamically in _buildPricingSummaryCard.
// UPDATE: Standardized to kobo; deliveryFee /100 for display/calc.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './order_details_screen.dart';
import '../../models/order.dart' as app_order;
import '../../services/api_service.dart';
import './customer_dashboard_screen.dart';

class OrderSummaryScreen extends StatefulWidget {
  static const String routeName = '/order_summary';
  final String orderId;
  final String customerId;
  final bool showConfirmation;
  final String? transactionRef;
  final bool isVerifyingPayment;
  final app_order.Order? orderPayload;

  const OrderSummaryScreen({
    super.key,
    required this.orderId,
    required this.customerId,
    this.showConfirmation = false,
    this.transactionRef,
    this.isVerifyingPayment = false,
    this.orderPayload,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  app_order.Order? _orderData;
  bool _isStillVerifying;

  late AnimationController _entryAnimController;
  final ApiService _apiService = ApiService();
  Timer? _pollingTimer;

  _OrderSummaryScreenState() : _isStillVerifying = false;

  @override
  void initState() {
    super.initState();
    _isStillVerifying = widget.isVerifyingPayment;
    _orderData = widget.orderPayload;
    _isLoading = _orderData == null;

    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    if (_orderData == null) {
      _fetchOrderDetails();
    } else {
      _entryAnimController.forward();
    }

    if (_isStillVerifying) {
      _startPolling();
    }
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrderDetails({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!forceRefresh) setState(() => _isLoading = true);
    try {
      final fetchedOrder = await _apiService.getOrderDetails(widget.orderId);
      if (mounted) {
        setState(() {
          _orderData = fetchedOrder;
          _isLoading = false;
          if (fetchedOrder.paymentStatus.toLowerCase() == 'completed') {
            _isStillVerifying = false;
            _pollingTimer?.cancel();
          }
        });
        _entryAnimController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  void _startPolling() {
    int pollAttempt = 0;
    const int maxPollAttempts = 8;
    const pollInterval = Duration(seconds: 15);
    _pollingTimer = Timer.periodic(pollInterval, (timer) async {
      if (pollAttempt >= maxPollAttempts || !mounted || !_isStillVerifying) {
        timer.cancel();
        if (mounted && _isStillVerifying) {
          setState(() => _isStillVerifying = false);
          _showFeedbackSnackbar(
              "Verification is taking longer than usual. Please check order details later.",
              isError: true);
        }
        return;
      }
      pollAttempt++;
      try {
        final paymentStatus =
            await _apiService.getOrderPaymentStatus(widget.orderId);
        if (paymentStatus.toLowerCase() == 'completed') {
          timer.cancel();
          await _fetchOrderDetails(forceRefresh: true);
          _showFeedbackSnackbar('Payment confirmed!', isSuccess: true);
        }
      } catch (e) {
        /* Continue polling on error */
      }
    });
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
        backgroundColor: themeProvider.cardBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: themeProvider.gas2doorPrimaryBlue))
          : _errorMessage != null || _orderData == null
              ? _buildErrorState(
                  themeProvider, _errorMessage ?? "Order summary not found.")
              : FadeTransition(
                  opacity: _entryAnimController,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.05), end: Offset.zero)
                        .animate(_entryAnimController),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                if (_isStillVerifying)
                                  _buildVerifyingHeader(themeProvider)
                                else
                                  _buildSuccessHeader(
                                      themeProvider, _orderData!),
                                const SizedBox(height: 24),
                                _buildItemsOrderedCard(
                                    _orderData!, themeProvider),
                                const SizedBox(height: 16),
                                _buildPricingSummaryCard(
                                    _orderData!, themeProvider),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                        _buildActionButtons(_orderData!, themeProvider),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSuccessHeader(
      ThemeProvider themeProvider, app_order.Order order) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
        themeProvider.successColor.withOpacity(0.1),
        themeProvider.successColor.withOpacity(0.0)
      ], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: themeProvider.successColor,
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            'Payment Successful!',
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: themeProvider.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            'Your order #${order.shortOrderId} has been confirmed.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 16, color: themeProvider.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyingHeader(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation<Color>(
                  themeProvider.gas2doorPrimaryBlue),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Verifying Your Payment...',
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: themeProvider.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            'This should only take a moment. We are confirming your transaction with the payment provider.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 16, color: themeProvider.secondaryText),
          ),
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

  Widget _buildPricingSummaryCard(
      app_order.Order order, ThemeProvider themeProvider) {
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    // FIX: Dynamically calculate total amount instead of relying on finalAmountPaid (which may be 0 during verification).
    double totalAmount =
        (order.itemsSubtotal / 100) + (order.deliveryFee / 100);
    if (order.serviceFeeAmount > 0)
      totalAmount += (order.serviceFeeAmount / 100);
    if (order.vatAmount > 0) totalAmount += (order.vatAmount / 100);
    if (order.discountAmount > 0) totalAmount -= (order.discountAmount / 100);
    if (order.walletAmountUsed > 0)
      totalAmount -= (order.walletAmountUsed / 100);

    // If verification is complete and finalAmountPaid is set, use it; else use computed.
    if (!_isStillVerifying && order.finalAmountPaid > 0) {
      totalAmount = order.finalAmountPaid / 100;
    }

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
                '+ ${currencyFormat.format(order.deliveryFee / 100)}', // FIX: /100 for kobo
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
            _buildDetailRow("Grand Total Paid:",
                currencyFormat.format(totalAmount), themeProvider,
                isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      app_order.Order order, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
          // NEW: Added a subtle blue gradient to the background.
          gradient: LinearGradient(
            colors: [
              themeProvider.gas2doorPrimaryBlue.withOpacity(0.03),
              themeProvider.cardBackground.withOpacity(0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          color: themeProvider.cardBackground,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5))
          ],
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil(
                        CustomerDashboardScreen.routeName, (route) => false);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                    color: themeProvider.tertiaryText.withOpacity(0.5)),
              ),
              child: Text('Back to Home',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: themeProvider.primaryText)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.route_rounded, size: 20),
              label: const Text('Track Your Order'),
              onPressed: () {
                Navigator.of(context).pushReplacementNamed(
                  OrderDetailsScreen.routeName,
                  arguments: {
                    'orderId': order.id,
                    'customerId': widget.customerId
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: themeProvider.gas2doorPrimaryBlue,
                  foregroundColor: Colors.white,
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: isTotal ? 16 : 14,
                  color: isDiscount
                      ? themeProvider.successColor
                      : (isTotal
                          ? themeProvider.primaryText
                          : themeProvider.secondaryText),
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w500)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: isTotal ? 17 : 15,
                  color: isDiscount
                      ? themeProvider.successColor
                      : themeProvider.primaryText,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String message) {
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
                  onPressed: () => _fetchOrderDetails(),
                  color: themeProvider.gas2doorPrimaryBlue),
            ])));
  }
}
