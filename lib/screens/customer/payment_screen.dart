// File: lib/screens/customer/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:monnify_payment_sdk/src/models/transaction_status.dart';
import 'package:monnify_payment_sdk/src/models/transaction_response.dart';
import 'package:monnify_payment_sdk/monnify_payment_sdk.dart';

import '../../services/api_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './order_summary_screen.dart';
import '../customer/customer_dashboard_screen.dart';
import '../../models/user.dart' as app_user;

class PaymentScreen extends StatefulWidget {
  static const String routeName = '/payment';
  final String orderId;
  final double amount; // Amount in SMALLEST currency unit (e.g., Kobo)
  final String? itemDescription;
  final app_user.User customer;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
    this.itemDescription,
    required this.customer,
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
    print(
        '[PaymentScreen] initState: Screen initialized for Order ID: ${widget.orderId}');
    _initializeMonnify();
  }

  Future<void> _initializeMonnify() async {
    print(
        '[PaymentScreen] _initializeMonnify: Attempting to initialize Monnify SDK.');
    try {
      // Hardcoded keys for analysis purposes ONLY. Not recommended for production.
      final apiKey = "MK_TEST_L969MNXY0V";
      final contractCode = "8609686503";

      print(
          '[PaymentScreen] _initializeMonnify: Using API Key (first 5 chars): ${apiKey.substring(0, 5)}..., Contract Code: $contractCode');

      if (apiKey.isEmpty || contractCode.isEmpty) {
        print(
            '[PaymentScreen] _initializeMonnify: Monnify credentials are empty. Throwing exception.');
        throw Exception("Monnify credentials are not configured.");
      }

      final monnifyInstance = await Monnify.initialize(
        apiKey: apiKey,
        contractCode: contractCode,
        applicationMode: ApplicationMode.TEST,
      );

      if (mounted) {
        setState(() {
          _monnify = monnifyInstance;
          _statusMessage = 'Pay Now';
        });
        print(
            '[PaymentScreen] _initializeMonnify: Monnify SDK initialized successfully. Status message: "Pay Now".');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Initialization Failed');
        _showFeedbackSnackbar(
            'Could not initialize payment SDK: ${e.toString().replaceFirst("Exception: ", "")}',
            isError: true);
        print(
            '[PaymentScreen] _initializeMonnify: Monnify SDK initialization failed: $e. Status message: "Initialization Failed".');
      }
    }
  }

  void _showFeedbackSnackbar(String message,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) {
      print('[PaymentScreen] Snackbar not shown, widget not mounted.');
      return;
    }
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError
            ? themeProvider.errorColor
            : (isSuccess
                ? themeProvider.successColor
                : themeProvider.gas2doorPrimaryBlue),
        behavior: SnackBarBehavior.floating,
      ),
    );
    print(
        '[PaymentScreen] Showing Snackbar: "$message" (isError: $isError, isSuccess: $isSuccess)');
  }

  Future<void> _handlePayment() async {
    print('[PaymentScreen] _handlePayment: User initiated payment process.');
    if (_monnify == null) {
      _showFeedbackSnackbar('Payment SDK not initialized. Please wait.',
          isError: true);
      print('[PaymentScreen] _handlePayment: Monnify SDK is not initialized.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Redirecting to Monnify...';
    });
    print(
        '[PaymentScreen] _handlePayment: Setting _isProcessing to true, status message to "Redirecting to Monnify...".');

    final transactionDetails = TransactionDetails(
      amount: widget.amount / 100.0, // Convert from Kobo to Naira
      currencyCode: "NGN",
      customerName: widget.customer.name,
      customerEmail: widget.customer.email,
      paymentReference: widget.orderId,
      paymentDescription: widget.itemDescription ?? 'Payment for Order',
      paymentMethods: [PaymentMethod.CARD, PaymentMethod.ACCOUNT_TRANSFER],
    );

    print(
        '[PaymentScreen] _handlePayment: Preparing TransactionDetails for Monnify. Amount: ${transactionDetails.amount}, Ref: ${transactionDetails.paymentReference}');
    // FIX: Log individual properties instead of calling .toJson() on TransactionDetails
    print('[PaymentScreen] _handlePayment: Transaction Details properties: '
        'Amount: ${transactionDetails.amount}, '
        'Currency: ${transactionDetails.currencyCode}, '
        'Customer Name: ${transactionDetails.customerName}, '
        'Customer Email: ${transactionDetails.customerEmail}, '
        'Payment Reference: ${transactionDetails.paymentReference}, '
        'Payment Description: ${transactionDetails.paymentDescription}, '
        'Payment Methods: ${transactionDetails.paymentMethods.map((m) => m.toString().split('.').last).join(', ')}.');

    try {
      final TransactionResponse? response =
          await _monnify!.initializePayment(transaction: transactionDetails);

      if (mounted) {
        // FIX: Log individual properties of TransactionResponse. Use `responseMessage` instead of `errorMessage`.
        print(
            '[PaymentScreen] _handlePayment: Monnify SDK callback received. Response properties: '
            'Transaction Status: ${response?.transactionStatus}, '
            'Transaction Reference: ${response?.transactionReference}, '
            'Payment Reference: ${response?.paymentReference}, '
            'Amount Paid: ${response?.amountPaid}, '
            'Currency: ${response?.currencyCode}, '
            'Payment Method: ${response?.paymentMethod}, ');

        final String? monnifyTransactionStatus = response?.transactionStatus;

        if (monnifyTransactionStatus ==
            TransactionStatus.PAID.toString().split('.').last) {
          _showFeedbackSnackbar(
              'Payment initiated. Verifying status with server...',
              isSuccess: true);
          print(
              '[PaymentScreen] _handlePayment: Monnify reported "PAID". Now calling backend to verify payment status.');
          try {
            print(
                '[PaymentScreen] _handlePayment: Calling _apiService.getOrderPaymentStatus for Order ID: ${widget.orderId}');
            final String confirmedStatus =
                await _apiService.getOrderPaymentStatus(widget.orderId);
            print(
                '[PaymentScreen] _handlePayment: Backend confirmed payment status as: "$confirmedStatus" for Order ID: ${widget.orderId}');

            if (mounted) {
              if (confirmedStatus == 'Completed') {
                _showFeedbackSnackbar(
                    'Payment successfully confirmed by server!',
                    isSuccess: true);
                print(
                    '[PaymentScreen] _handlePayment: Backend confirmed "Completed". Navigating to OrderSummaryScreen (showConfirmation: true, isVerifyingPayment: false).');
                Navigator.of(context).pushReplacementNamed(
                  OrderSummaryScreen.routeName,
                  arguments: {
                    'orderId': widget.orderId,
                    'customerId': widget.customer.id,
                    'showConfirmation': true,
                    'transactionRef': response!.transactionReference,
                    'isVerifyingPayment': false,
                  },
                );
              } else {
                _showFeedbackSnackbar(
                    'Payment processing—refresh or wait a moment for confirmation.',
                    isError: false);
                print(
                    '[PaymentScreen] _handlePayment: Backend did NOT confirm "Completed". Status: "$confirmedStatus". Navigating to OrderSummaryScreen (isVerifyingPayment: true).');
                Navigator.of(context).pushReplacementNamed(
                  OrderSummaryScreen.routeName,
                  arguments: {
                    'orderId': widget.orderId,
                    'customerId': widget.customer.id,
                    'showConfirmation': false,
                    'transactionRef': response!.transactionReference,
                    'isVerifyingPayment': true,
                  },
                );
              }
            }
          } catch (e) {
            if (mounted) {
              _showFeedbackSnackbar(
                  'Error communicating with server for payment confirmation: ${e.toString().replaceFirst("Exception: ", "")}',
                  isError: true);
              print(
                  '[PaymentScreen] _handlePayment: Error during backend payment confirmation check: $e. Navigating to OrderSummaryScreen (isVerifyingPayment: true).');
              Navigator.of(context).pushReplacementNamed(
                OrderSummaryScreen.routeName,
                arguments: {
                  'orderId': widget.orderId,
                  'customerId': widget.customer.id,
                  'showConfirmation': false,
                  'transactionRef': response!.transactionReference,
                  'isVerifyingPayment': true,
                },
              );
            }
          }
        } else if (monnifyTransactionStatus ==
            TransactionStatus.CANCELLED.toString().split('.').last) {
          _showFeedbackSnackbar('Payment cancelled by user.', isError: true);
          print(
              '[PaymentScreen] _handlePayment: Monnify reported "CANCELLED" by user.');
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _statusMessage = 'Pay Now';
            });
          }
        } else {
          _showFeedbackSnackbar('Payment failed: Unknown error from Monnify.',
              isError: true);
          print(
              '[PaymentScreen] _handlePayment: Monnify reported unknown or failed status: "$monnifyTransactionStatus".');
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _statusMessage = 'Pay Now';
            });
          }
        }
      } else {
        _showFeedbackSnackbar(
            'Payment process ended unexpectedly. Please check your order status.',
            isError: true);
        print(
            '[PaymentScreen] _handlePayment: Widget unmounted during payment process, or unexpected null response from Monnify. Navigating to OrderSummaryScreen (isVerifyingPayment: true).');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            OrderSummaryScreen.routeName,
            arguments: {
              'orderId': widget.orderId,
              'customerId': widget.customer.id,
              'showConfirmation': false,
              'transactionRef': null,
              'isVerifyingPayment': true,
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Pay Now';
        });
        _showFeedbackSnackbar(
            "Payment initiation failed: ${e.toString().replaceFirst("Exception: ", "")}",
            isError: true);
        print(
            '[PaymentScreen] _handlePayment: Critical error initiating Monnify SDK payment: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final displayAmount = widget.amount / 100;
    final currencyFormat =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

    // print('[PaymentScreen] build: Rebuilding PaymentScreen. Display Amount: $displayAmount'); // Too frequent for debug

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        title: Text('Complete Payment',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText, fontWeight: FontWeight.w600)),
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () {
            print('[PaymentScreen] AppBar back button pressed.');
            Navigator.of(context).pop(false);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomCard(
              color: themeProvider.cardBackground,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order Details',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.primaryText)),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      context,
                      Icons.receipt_long_outlined,
                      'Order ID:',
                      widget.orderId,
                      themeProvider,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      context,
                      Icons.description_outlined,
                      'Description:',
                      widget.itemDescription ?? 'Gas Cylinder Order',
                      themeProvider,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      context,
                      Icons.person_outline,
                      'Customer:',
                      widget.customer.name,
                      themeProvider,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      context,
                      Icons.email_outlined,
                      'Email:',
                      widget.customer.email,
                      themeProvider,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      context,
                      Icons.phone_outlined,
                      'Phone:',
                      widget.customer.phone ?? 'N/A',
                      themeProvider,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            CustomCard(
              color: themeProvider.cardBackground,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 50, color: themeProvider.gas2doorPrimaryBlue),
                    const SizedBox(height: 16),
                    Text('Total Amount Due',
                        style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.primaryText)),
                    const SizedBox(height: 10),
                    Text(
                      currencyFormat.format(displayAmount),
                      style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.primaryText),
                    ),
                    const SizedBox(height: 8),
                    Text('(Amount in NGN)',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: themeProvider.tertiaryText)),
                    const SizedBox(height: 16),
                    Text('Your payment will be securely processed by Monnify.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: themeProvider.secondaryText)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            CustomButton(
              text: _statusMessage,
              onPressed:
                  _monnify != null && !_isProcessing ? _handlePayment : null,
              color: themeProvider.gas2doorPrimaryBlue,
              height: 52,
              icon: _isProcessing || _monnify == null
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Icon(Icons.payment_rounded, color: Colors.white),
              textStyle: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 20),
            Center(
                child: Text("Powered by Monnify",
                    style: GoogleFonts.inter(
                        fontSize: 12, color: themeProvider.tertiaryText))),
          ],
        ),
      ),
    );
  }

  /// Helper method to build a row for displaying order details.
  Widget _buildDetailRow(BuildContext context, IconData icon, String label,
      String value, ThemeProvider themeProvider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: themeProvider.gas2doorTeal),
        const SizedBox(width: 12),
        Text('$label ',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: themeProvider.secondaryText)),
        Expanded(
          child: Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.primaryText)),
        ),
      ],
    );
  }
}
