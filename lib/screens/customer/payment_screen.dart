// File: lib/screens/customer/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeMonnify();
  }

  /// Initializes the Monnify SDK and stores the instance for later use.
  Future<void> _initializeMonnify() async {
    try {
      final apiKey = dotenv.env['MONNIFY_API_KEY'];
      final contractCode = dotenv.env['MONNIFY_CONTRACT_CODE'];

      if (apiKey == null || contractCode == null) {
        throw Exception("Monnify credentials not found in .env file.");
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not initialize payment SDK: ${e.toString()}',
                style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // _showFeedbackSnackbar is a general helper, can still be used for pre-payment errors
  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor:
            isError ? themeProvider.errorColor : themeProvider.successColor,
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
      amount: widget.amount /
          100, // Monnify expects amount in major currency unit (Naira)
      currencyCode: "NGN",
      customerName: widget.customer.name,
      customerEmail: widget.customer.email,
      paymentReference:
          widget.orderId, // Use orderId as Monnify paymentReference
      paymentDescription: widget.itemDescription ?? 'Payment for Order',
      paymentMethods: [PaymentMethod.CARD, PaymentMethod.ACCOUNT_TRANSFER],
    );

    try {
      // Initiate payment with Monnify SDK
      final TransactionResponse? response =
          await _monnify!.initializePayment(transaction: transactionDetails);

      if (mounted) {
        // Crucial Change: We DO NOT call backend for confirmation here.
        // We navigate directly to OrderSummaryScreen, which will then poll the backend.
        Navigator.of(context).pushReplacementNamed(
          OrderSummaryScreen.routeName,
          arguments: {
            'orderId': widget.orderId,
            'customerId': widget.customer.id,
            'showConfirmation': true, // Used to display an initial message
            'transactionRef': response
                ?.transactionReference, // Pass Monnify's transaction reference
            'isVerifyingPayment': true, // Flag to OrderSummary to start polling
          },
        );
      }
    } catch (e) {
      // Catch errors that occur *before* the Monnify WebView successfully loads/completes
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Pay Now';
        });
        _showFeedbackSnackbar("Payment initiation failed: ${e.toString()}",
            isError: true);
        print('Monnify SDK initiation error: $e'); // For debugging in console
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
            CustomCard(
              color: themeProvider.cardBackground,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.credit_card,
                        size: 50, color: themeProvider.gas2doorPrimaryBlue),
                    const SizedBox(height: 16),
                    Text('Secure Payment',
                        style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.primaryText)),
                    const SizedBox(height: 10),
                    Text(
                      widget.itemDescription ?? 'Order ID: ${widget.orderId}',
                      style: GoogleFonts.inter(
                          fontSize: 16, color: themeProvider.secondaryText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
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
}
