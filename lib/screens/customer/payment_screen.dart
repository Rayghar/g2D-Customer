// File: lib/screens/customer/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // To access ISW_LIVE_MODE from .env

// *******************************************************************
// CORRECTED IMPORTS based on your provided file system analysis:
// *******************************************************************
import 'package:isw_mobile_sdk/isw_mobile_sdk.dart'; // Main SDK entry point, provides IswMobileSdk
import 'package:isw_mobile_sdk/models/isw_mobile_sdk_sdk_config.dart'; // Contains IswSdkConfig and Environment
import 'package:isw_mobile_sdk/models/isw_mobile_sdk_payment_info.dart'; // Contains IswPaymentInfo
import 'package:isw_mobile_sdk/models/isw_mobile_sdk_payment_result.dart'; // Contains IswPaymentResult and Optional
// *******************************************************************

import '../../services/api_service.dart'; // To call your backend
import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './order_summary_screen.dart';
import '../../models/user.dart' as app_user;

class PaymentScreen extends StatefulWidget {
  static const String routeName = '/payment';
  final String orderId;
  final double amount; // Amount in SMALLEST currency unit (e.g., Kobo)
  final String? itemDescription;
  final app_user.User customer;
  // Interswitch SDK uses IswSdkConfig with merchantId and merchantCode.
  final String?
      iswMerchantId; // Interswitch Merchant ID passed from OrderPlacementScreen
  final String?
      iswMerchantCode; // Interswitch Domain ID (sometimes called merchantCode)

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
    this.itemDescription,
    required this.customer,
    this.iswMerchantId, // Receive Merchant ID
    this.iswMerchantCode, // Receive Domain ID (used as merchantCode)
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;
  bool _isSdkInitialized = false;
  String _statusMessage = 'Initializing Interswitch...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeInterswitchSdk();
    });
  }

  /// Initializes the Interswitch SDK with merchant credentials.
  Future<void> _initializeInterswitchSdk() async {
    try {
      // Use keys passed from arguments, or fallback to dotenv if not provided (safer to pass via args)
      final merchantId = widget.iswMerchantId;
      // Documentation's `IswSdkConfig` takes `merchantCode`, which often is the domain ID.
      final merchantCode = widget.iswMerchantCode;
      final merchantSecret = "078uF6FEXcNTn16"; // Required by IswSdkConfig
      final currencyCode = "566"; // NGN currency code for IswSdkConfig

      const bool isLiveMode = false; // Get live mode from .env

      // TEMPORARY DEBUG PRINTS - REMOVE BEFORE PRODUCTION!
      debugPrint('DEBUG: Loaded ISW_MERCHANT_ID: $merchantId');
      debugPrint('DEBUG: Loaded ISW_DOMAIN_ID: $merchantCode');
      debugPrint(
          'DEBUG: Loaded ISW_CLIENT_SECRET: $merchantSecret'); // CAUTION: Printing secret key!
      debugPrint('DEBUG: ISW_LIVE_MODE: $isLiveMode');
      // END TEMPORARY DEBUG PRINTS

      if (merchantId == null ||
          merchantId.isEmpty ||
          merchantCode == null ||
          merchantCode.isEmpty ||
          merchantSecret == null ||
          merchantSecret.isEmpty) {
        throw Exception(
            "Interswitch Merchant ID, Domain ID (Code), or Client Secret not found (either passed or in .env file).");
      }

      // Use IswSdkConfig constructor for configuration
      final config = IswSdkConfig(
        merchantId, // Positional argument: merchantId
        merchantSecret, // Positional argument: merchantSecret
        merchantCode, // Positional argument: merchantCode
        currencyCode, // Positional argument: currencyCode
      );

      // Initialize the SDK using IswMobileSdk.initialize with Environment
      final Environment environment = isLiveMode
          ? Environment.PRODUCTION
          : Environment.TEST; // Using PRODUCTION for live mode
      await IswMobileSdk.initialize(config, environment);

      if (mounted) {
        setState(() {
          _isSdkInitialized = true;
          _statusMessage = 'Pay Now';
        });
        debugPrint('Interswitch SDK successfully initialized.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Initialization Failed';
          _isSdkInitialized = false;
        });
        _showFeedbackSnackbar(
            'Interswitch SDK initialization error: ${e.toString()}',
            isError: true);
        debugPrint('Interswitch Initialization Error: ${e.toString()}');
      }
    }
  }

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

  /// Handles the entire client-side payment flow using the Interswitch SDK.
  Future<void> _handlePayment() async {
    // Prevent multiple clicks or if not initialized
    if (_isProcessing || !_isSdkInitialized) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing...';
    });

    try {
      // Interswitch SDK requires amount in minor units (kobo)
      // widget.amount is already in kobo (smallest currency unit), so just cast to int.
      final int amountInMinorUnits = widget.amount.toInt();

      // Generate a unique transaction reference (max 15 chars, duplicates rejected)
      // Using orderId as it's unique and matches your backend's reference.
      final String transactionReference = widget.orderId;

      // Use IswPaymentInfo constructor for payment details
      final iswPaymentInfo = IswPaymentInfo(
        widget.customer.id, // customerId
        widget.customer.name, // customerName
        widget.customer.email, // customerEmail
        widget.customer.phone ?? '', // customerMobile
        transactionReference, // reference
        amountInMinorUnits, // amount
      );

      debugPrint(
          'Calling IswMobileSdk.pay with: ${iswPaymentInfo.toMap()}'); // Use toMap() for logging map representation

      // Trigger payment using IswMobileSdk.pay
      final result = await IswMobileSdk.pay(
          iswPaymentInfo); // Returns Optional<IswPaymentResult?>

      // Handle the result from IswMobileSdk.pay
      if (result.hasValue) {
        // Check if a value is present (transaction completed)
        final IswPaymentResult iswResult =
            result.value!; // Get the actual result object

        if (iswResult.isSuccessful) {
          // Check if the transaction was successful (property, not a method)
          _showFeedbackSnackbar(
              "Payment successful! Confirming order via server...",
              isError: false);

          // Crucial: Call your backend to verify the transaction server-side.
          // Interswitch requires server-side verification for definitive status.
          await _apiService.verifyInterswitchPayment(
            transactionReference: iswResult
                .transactionReference!, // Use the reference from ISW result
            orderId: widget.orderId, // Your internal order ID
          );

          if (mounted) {
            Navigator.of(context).pushReplacementNamed(
              OrderSummaryScreen.routeName,
              arguments: {
                'orderId': widget.orderId,
                'customerId': widget.customer.id,
                'showConfirmation': true,
                'transactionRef': iswResult
                    .transactionReference, // Use ISW reference for summary
              },
            );
          }
        } else {
          // SDK indicates failure
          _showFeedbackSnackbar(
              "Payment failed: ${iswResult.responseCode} - ${iswResult.responseDescription}",
              isError: true);
          if (mounted)
            setState(() {
              _isProcessing = false;
              _statusMessage = 'Pay Now';
            });
        }
      } else {
        // hasValue is false, typically means user cancelled
        _showFeedbackSnackbar("Payment cancelled. Please try again.",
            isError: true);
        if (mounted)
          setState(() {
            _isProcessing = false;
            _statusMessage = 'Pay Now';
          });
      }
    } catch (e) {
      // Catch any unexpected error during payment flow (e.g., PlatformException)
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Pay Now';
        });
        _showFeedbackSnackbar(
            "An unexpected error occurred during Interswitch payment: ${e.toString()}",
            isError: true);
        debugPrint('Interswitch Payment Error: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final displayAmount =
        widget.amount / 100; // For display, convert kobo to Naira
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
                  _isSdkInitialized && !_isProcessing ? _handlePayment : null,
              color: themeProvider.gas2doorPrimaryBlue,
              height: 52,
              icon: _isProcessing || !_isSdkInitialized
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
                child: Text("Powered by Interswitch",
                    style: GoogleFonts.inter(
                        fontSize: 12, color: themeProvider.tertiaryText))),
          ],
        ),
      ),
    );
  }
}
