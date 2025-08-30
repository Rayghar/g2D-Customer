// File: lib/screens/customer/payment_screen.dart
// ADVISORY: This is the complete, reimagined version with the "Floating Purple Receipt" design.
// UPDATE: Fixed total payable showing as 0 by computing it dynamically in _buildPricingSummary.
// UPDATE: Standardized to kobo; deliveryFee /100 for display/calc.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:monnify_payment_sdk/monnify_payment_sdk.dart';
import 'package:monnify_payment_sdk/src/models/transaction_response.dart';
import 'package:logging/logging.dart'; // Added for internal logging
import 'package:sentry_flutter/sentry_flutter.dart'; // Added for Sentry integration
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Added for .env file access

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './order_summary_screen.dart';
import '../../models/user.dart' as app_user;
import '../../models/order.dart' as app_order;
import '../../services/api_service.dart';

// Initialize a logger for this file
final _logger = Logger('PaymentScreen');

class PaymentScreen extends StatefulWidget {
  static const String routeName = '/payment';
  final String orderId;
  final double amount; // Amount in SMALLEST currency unit (e.g., Kobo)
  final app_user.User customer;
  final app_order.Order order;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
    required this.customer,
    required this.order,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  String _statusMessage = 'Initializing...';

  Monnify? _monnify;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _logger.info(
        'PaymentScreen initialized for Order ID: ${widget.orderId}'); // Log info
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'lifecycle',
        message: 'PaymentScreen initialized',
        data: {
          'order_id': widget.orderId,
          'amount_kobo': widget.amount,
          'customer_id': widget.customer.id
        },
        level: SentryLevel.info)); // Sentry breadcrumb

    // Set Sentry context specific to this payment
    Sentry.configureScope((scope) {
      scope.setTag('order_id', widget.orderId);
      scope.setTag('customer_id', widget.customer.id);
      scope.setExtra('payment_amount_kobo', widget.amount);
      scope.setUser(SentryUser(
          id: widget.customer.id,
          email: widget.customer.email,
          username: widget.customer.name));
    });

    _initializeMonnify();
  }

  Future<void> _initializeMonnify() async {
    _logger.info('Initializing Monnify SDK...'); // Log info
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'payment_sdk',
        message: 'Attempting to initialize Monnify SDK',
        level: SentryLevel.info)); // Sentry breadcrumb

    try {
      // Correctly access environment variables using flutter_dotenv
      final String? apiKey = dotenv.env['MONNIFY_API_KEY'];
      final String? contractCode = dotenv.env['MONNIFY_CONTRACT_CODE'];

      // Correctly check for null and empty strings
      if (apiKey == null ||
          apiKey.isEmpty ||
          contractCode == null ||
          contractCode.isEmpty) {
        final errorMessage =
            "Monnify credentials (API Key or Contract Code) are not configured. Please check your .env file or build configuration.";
        _logger.severe(errorMessage); // Log severe error
        Sentry.captureMessage(errorMessage,
            level: SentryLevel.fatal,
            hint: Hint.withMap({
              // Sentry fatal message
              'reason': 'Missing Monnify API credentials',
              'action_needed':
                  'Ensure MONNIFY_API_KEY and MONNIFY_CONTRACT_CODE are in .env and loaded.'
            }));
        throw Exception(
            errorMessage); // Throw the exception to stop initialization
      }

      final monnifyInstance = await Monnify.initialize(
        apiKey: apiKey,
        contractCode: contractCode,
        applicationMode:
            ApplicationMode.TEST, // Use ApplicationMode.LIVE for production
      );

      if (mounted) {
        setState(() {
          _monnify = monnifyInstance;
          _statusMessage = 'Pay Now';
        });
        _logger.info('Monnify SDK initialized successfully.'); // Log info
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'payment_sdk',
            message: 'Monnify SDK initialized successfully',
            level: SentryLevel.info)); // Sentry breadcrumb
      }
    } catch (e, st) {
      // Capture stack trace for Sentry
      _logger.severe(
          'Failed to initialize Monnify SDK: $e', e, st); // Log severe error
      Sentry.captureException(e,
          stackTrace: st,
          hint: Hint.withMap({
            // Send error to Sentry
            'action': 'initialize_monnify_sdk',
            'order_id': widget.orderId,
          }));
      if (mounted) {
        setState(() => _statusMessage = 'Initialization Failed');
        _showFeedbackSnackbar(
            'Could not initialize payment SDK: ${e.toString().replaceFirst("Exception: ", "")}',
            isError: true);
      }
    }
  }

  void _showFeedbackSnackbar(String message,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    Color backgroundColor;
    if (isError) {
      backgroundColor = themeProvider.errorColor;
      _logger.warning(
          'Snackbar Error: $message'); // Log warnings for user-facing errors
    } else if (isSuccess) {
      backgroundColor = themeProvider.successColor;
      _logger.info(
          'Snackbar Success: $message'); // Log info for user-facing successes
    } else {
      backgroundColor = themeProvider.gas2doorPrimaryBlue;
      _logger.info('Snackbar Info: $message'); // Log info for other messages
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _handlePayment() async {
    _logger.info(
        'Attempting to handle payment for order ID: ${widget.orderId}'); // Log info
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'payment_flow',
        message: 'User initiated payment process',
        data: {'order_id': widget.orderId, 'amount': widget.amount / 100.0},
        level: SentryLevel.info)); // Sentry breadcrumb

    if (_monnify == null) {
      _showFeedbackSnackbar('Payment SDK not initialized. Please wait.',
          isError: true);
      _logger.warning(
          'Payment attempt failed: Monnify SDK not initialized.'); // Log warning
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'payment_flow',
          message: 'Payment SDK not ready',
          level: SentryLevel.warning)); // Sentry breadcrumb
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Redirecting...';
    });

    final transactionDetails = TransactionDetails(
      amount: double.parse((widget.amount / 100.0).toStringAsFixed(
          2)), // Convert kobo to Naira and round to 2 decimal places
      currencyCode: "NGN",
      customerName: widget.customer.name,
      customerEmail: widget.customer.email,
      paymentReference: widget.orderId,
      paymentDescription: widget.order.itemsPreview,
      paymentMethods: [PaymentMethod.CARD, PaymentMethod.ACCOUNT_TRANSFER],
    );

    _logger.fine(
        'Monnify transaction details prepared: ${transactionDetails.paymentReference}'); // Log fine
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'payment_sdk',
        message: 'Monnify transaction details prepared',
        data: {
          'payment_reference': transactionDetails.paymentReference,
          'amount': transactionDetails.amount
        },
        level: SentryLevel.debug)); // Sentry breadcrumb

    try {
      final TransactionResponse? response =
          await _monnify!.initializePayment(transaction: transactionDetails);
      if (!mounted) {
        _logger.warning(
            'Payment response received, but screen unmounted.'); // Log warning
        return;
      }

      _logger.info(
          'Monnify payment response received. Status: ${response?.transactionStatus}'); // Log info
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'payment_sdk',
          message: 'Monnify payment callback received',
          data: {
            'transaction_status': response?.transactionStatus,
            'payment_reference': response?.paymentReference
          },
          level: SentryLevel.info)); // Sentry breadcrumb

      final bool isPaid = response?.transactionStatus ==
          TransactionStatus.PAID.toString().split('.').last;

      if (isPaid) {
        _showFeedbackSnackbar('Payment initiated. Verifying with server...',
            isSuccess: true);
        try {
          await _apiService.markOrderAsVerifying(widget.orderId);
        } catch (e) {
          _logger.warning(
              "Failed to mark order as verifying, but proceeding with navigation: $e");
        }
        _logger.info(
            'Payment successful. Navigating to OrderSummaryScreen for verification.'); // Log info
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'navigation',
            message:
                'Payment successful, navigating to OrderSummaryScreen for verification',
            data: {'order_id': widget.orderId},
            level: SentryLevel.info)); // Sentry breadcrumb

        Navigator.of(context).pushReplacementNamed(
          OrderSummaryScreen.routeName,
          arguments: {
            'orderId': widget.orderId,
            'customerId': widget.customer.id,
            'isVerifyingPayment': true,
            'orderPayload': widget.order,
          },
        );
      } else {
        _showFeedbackSnackbar('Payment was not completed.', isError: true);
        _logger.info(
            'Payment not completed. Monnify status: ${response?.transactionStatus}'); // Log info
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'payment_flow',
            message: 'Payment not completed by user',
            data: {'transaction_status': response?.transactionStatus},
            level: SentryLevel.info)); // Sentry breadcrumb
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = 'Pay Now';
          });
        }
      }
    } catch (e, st) {
      // Capture stack trace for Sentry
      _logger.severe(
          "Monnify payment initiation failed: $e", e, st); // Log severe error
      Sentry.captureException(e,
          stackTrace: st,
          hint: Hint.withMap({
            // Send error to Sentry
            'action': 'initialize_monnify_payment',
            'order_id': widget.orderId,
            'customer_id': widget.customer.id,
            'amount_kobo': widget.amount,
          }));
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Pay Now';
        });
        _showFeedbackSnackbar(
            "Payment failed: ${e.toString().replaceFirst("Exception: ", "")}",
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final displayAmount = widget.amount / 100.0;
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        title: Text('Confirm & Pay',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, color: themeProvider.primaryText)),
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () {
            _logger.info('Back button pressed on PaymentScreen.'); // Log info
            Sentry.addBreadcrumb(Breadcrumb(
                category: 'navigation',
                message: 'Back button pressed from PaymentScreen',
                data: {'order_id': widget.orderId},
                level: SentryLevel.info)); // Sentry breadcrumb
            Navigator.of(context).pop(false);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // NEW: The Floating Purple Receipt Card
            CustomCard(
              color: themeProvider.gas2doorPurple,
              elevation: 8,
              shadowColor: themeProvider.gas2doorPurple.withOpacity(0.4),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${widget.order.shortOrderId}',
                        style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Final Confirmation',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildSectionHeader(
                        Icons.shopping_bag_outlined, 'Items Ordered'),
                    _buildItemsList(widget.order, currencyFormat),
                    const SizedBox(height: 20),
                    _buildSectionHeader(
                        Icons.location_on_outlined, 'Delivering To'),
                    Text(widget.order.deliveryAddressSnapshot.fullAddress,
                        style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.9), height: 1.4)),
                    const SizedBox(height: 20),
                    _buildPricingSummary(
                        widget.order, themeProvider, currencyFormat),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
            color: themeProvider.cardBackground,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5))
            ],
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20))),
        child: CustomButton(
          text: _isProcessing
              ? _statusMessage
              : 'Pay ${currencyFormat.format(displayAmount)} Securely',
          onPressed: _monnify != null && !_isProcessing ? _handlePayment : null,
          color: themeProvider.gas2doorPrimaryBlue,
          height: 52,
          icon: _isProcessing || _monnify == null
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Icon(Icons.lock_outline_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.7), size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildItemsList(app_order.Order order, NumberFormat currencyFormat) {
    return ListView.separated(
      itemCount: order.items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final item = order.items[index];
        return Row(
          children: [
            Expanded(
                child: Text('${item.quantity}x ${item.productName}',
                    style:
                        GoogleFonts.inter(color: Colors.white, fontSize: 15))),
            Text(currencyFormat.format((item.unitPrice * item.quantity) / 100),
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ],
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 8),
    );
  }

  Widget _buildPricingSummary(app_order.Order order,
      ThemeProvider themeProvider, NumberFormat currencyFormat) {
    // FIX: Dynamically calculate total payable instead of relying on finalAmountPaid (which may be 0 pre-payment).
    double totalPayable =
        (order.itemsSubtotal / 100) + (order.deliveryFee / 100);
    if (order.serviceFeeAmount > 0)
      totalPayable += (order.serviceFeeAmount / 100);
    if (order.vatAmount > 0) totalPayable += (order.vatAmount / 100);
    if (order.discountAmount > 0) totalPayable -= (order.discountAmount / 100);
    if (order.walletAmountUsed > 0)
      totalPayable -= (order.walletAmountUsed / 100);

    return Column(
      children: [
        Divider(color: Colors.white.withOpacity(0.2)),
        const SizedBox(height: 8),
        _buildPriceDetailRow('Subtotal:',
            currencyFormat.format(order.itemsSubtotal / 100), themeProvider),
        _buildPriceDetailRow(
            'Delivery Fee:',
            currencyFormat.format(order.deliveryFee / 100),
            themeProvider), // FIX: /100
        if (order.serviceFeeAmount > 0)
          _buildPriceDetailRow(
              'Service Fee:',
              currencyFormat.format(order.serviceFeeAmount / 100),
              themeProvider),
        if (order.vatAmount > 0)
          _buildPriceDetailRow('VAT:',
              currencyFormat.format(order.vatAmount / 100), themeProvider),
        if (order.discountAmount > 0)
          _buildPriceDetailRow(
              'Discount:',
              '- ${currencyFormat.format(order.discountAmount / 100)}',
              themeProvider,
              isDiscount: true),
        if (order.walletAmountUsed > 0)
          _buildPriceDetailRow(
              'From Wallet:',
              '- ${currencyFormat.format(order.walletAmountUsed / 100)}',
              themeProvider,
              isDiscount: true),
        const SizedBox(height: 8),
        Divider(color: Colors.white.withOpacity(0.2)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Payable',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text(currencyFormat.format(totalPayable),
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        )
      ],
    );
  }

  Widget _buildPriceDetailRow(
      String label, String value, ThemeProvider themeProvider,
      {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: isDiscount
                      ? themeProvider.successColor.withOpacity(0.8)
                      : Colors.white.withOpacity(0.8))),
          Text(value,
              style: GoogleFonts.inter(
                  color: isDiscount ? themeProvider.successColor : Colors.white,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
