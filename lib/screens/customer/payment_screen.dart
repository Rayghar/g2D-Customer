// File: lib/screens/customer/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// UPDATE 1: Import TransactionStatus from monnify_payment_sdk to resolve undefined name errors.
import 'package:monnify_payment_sdk/src/models/transaction_status.dart';
import 'package:monnify_payment_sdk/src/models/transaction_response.dart';
import 'package:monnify_payment_sdk/monnify_payment_sdk.dart';

import '../../services/api_service.dart'; // Still needed for other API calls
import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './order_summary_screen.dart'; // Navigation target
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
    _initializeMonnify();
  }

  Future<void> _initializeMonnify() async {
    try {
      // Hardcoded keys for analysis purposes ONLY. Not recommended for production.
      final apiKey = "MK_TEST_L969MNXY0V"; //
      final contractCode = "8609686503"; //
      // Note: MONNIFY_SECRET_KEY=2Z659QCSA4GCPR0VKTPQTB81A3R7XHK4 is a backend secret and should NEVER be used client-side.
      // It is not included in this client-side file.

      if (apiKey.isEmpty || contractCode.isEmpty) {
        throw Exception("Monnify credentials are not configured.");
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
      }
    } catch (e) {
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
  }

  Future<void> _handlePayment() async {
    if (_monnify == null) {
      _showFeedbackSnackbar('Payment SDK not initialized. Please wait.',
          isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Redirecting to Monnify...';
    });

    final transactionDetails = TransactionDetails(
      amount: widget.amount / 100.0, // Convert from Kobo to Naira
      currencyCode: "NGN",
      customerName: widget.customer.name,
      customerEmail: widget.customer.email,
      paymentReference: widget.orderId,
      paymentDescription: widget.itemDescription ?? 'Payment for Order',
      paymentMethods: [PaymentMethod.CARD, PaymentMethod.ACCOUNT_TRANSFER],
    );

    try {
      final TransactionResponse? response =
          await _monnify!.initializePayment(transaction: transactionDetails);

      if (mounted) {
        // UPDATE 2: Corrected 'response.status' to 'response.transactionStatus'
        // UPDATE 3: Used TransactionStatus enum for comparison (e.g., TransactionStatus.PAID.toString().split('.').last to get 'PAID')
        if (response != null &&
            response.transactionStatus ==
                TransactionStatus.PAID.toString().split('.').last) {
          _showFeedbackSnackbar(
              'Payment initiated. Verifying status with server...',
              isSuccess: true);
          try {
            final String confirmedStatus =
                await _apiService.getOrderPaymentStatus(widget.orderId);

            if (mounted) {
              if (confirmedStatus == 'Completed') {
                _showFeedbackSnackbar(
                    'Payment successfully confirmed by server!',
                    isSuccess: true);
                Navigator.of(context).pushReplacementNamed(
                  OrderSummaryScreen.routeName,
                  arguments: {
                    'orderId': widget.orderId,
                    'customerId': widget.customer.id,
                    'showConfirmation': true,
                    'transactionRef': response.transactionReference,
                    'isVerifyingPayment': false,
                  },
                );
              } else {
                _showFeedbackSnackbar(
                    'Payment confirmation pending or failed. Please check order details later.',
                    isError: true);
                Navigator.of(context).pushReplacementNamed(
                  OrderSummaryScreen.routeName,
                  arguments: {
                    'orderId': widget.orderId,
                    'customerId': widget.customer.id,
                    'showConfirmation': false,
                    'transactionRef': response.transactionReference,
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
              Navigator.of(context).pushReplacementNamed(
                OrderSummaryScreen.routeName,
                arguments: {
                  'orderId': widget.orderId,
                  'customerId': widget.customer.id,
                  'showConfirmation': false,
                  'transactionRef': response.transactionReference,
                  'isVerifyingPayment': true,
                },
              );
            }
          }
          // UPDATE 4: Corrected 'response.status' to 'response.transactionStatus' and used TransactionStatus enum.
        } else if (response != null &&
            response.transactionStatus ==
                TransactionStatus.CANCELLED.toString().split('.').last) {
          _showFeedbackSnackbar('Payment cancelled by user.', isError: true);
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _statusMessage = 'Pay Now';
            });
          }
        } else {
          // UPDATE 5: Removed 'response.message' as it's not a property of TransactionResponse.
          // Provided a generic error message.
          _showFeedbackSnackbar('Payment failed: Unknown error from Monnify.',
              isError: true);
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
        print('Monnify SDK initiation error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final displayAmount = widget.amount / 100;
    final currencyFormat =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

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
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // New Order Details Card
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
            // Existing Secure Payment Card, slightly enhanced
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
