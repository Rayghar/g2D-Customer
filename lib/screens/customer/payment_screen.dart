// File: lib/screens/customer/opay_payment_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Ensure this is still needed for any keys
import 'package:flutter/services.dart'; // For PlatformException

import 'package:opay_online_flutter_sdk/opay_online_flutter_sdk.dart'; // OPay SDK
import 'package:flutter_easyloading/flutter_easyloading.dart'; // For loading indicators

import '../../services/api_service.dart'; // To call your backend
import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './order_summary_screen.dart';
import '../../models/user.dart' as app_user;

class OpayPaymentScreen extends StatefulWidget {
  static const String routeName = '/opay_payment'; // NEW route name
  final String orderId;
  final double amount; // Amount in SMALLEST currency unit (e.g., Kobo)
  final String? itemDescription;
  final app_user.User customer;
  final PayParams opayPayParams; // NEW: Receive OPay PayParams directly

  const OpayPaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
    this.itemDescription,
    required this.customer,
    required this.opayPayParams, // NEW: Required OPay PayParams
  });

  @override
  State<OpayPaymentScreen> createState() => _OpayPaymentScreenState();
}

class _OpayPaymentScreenState extends State<OpayPaymentScreen> {
  final ApiService _apiService = ApiService();
  late final OPayTask _opayTask; // OPay SDK instance
  bool _isProcessingOpay = false;
  String _paymentStatusMessage = 'Ready for OPay payment';

  @override
  void initState() {
    super.initState();
    _opayTask = OPayTask();
    // Configure OPay SDK environment (e.g., sandbox/release)
    // You might want to get this from an environment variable or a global config
    // For now, let's assume sandbox for testing as per OPay demo
    OPayTask.setSandBox(true); // Set to false for production
    _paymentStatusMessage = 'Tap to Pay with OPay';
  }

  void _showFeedbackSnackbar(String message,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    Color backgroundColor = themeProvider.successColor.withOpacity(0.95);
    if (isError) {
      backgroundColor = themeProvider.errorColor;
    } else if (!isSuccess) {
      backgroundColor = themeProvider.gas2doorPrimaryBlue.withOpacity(0.9);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 6,
      ),
    );
  }

  /// Handles the entire client-side payment flow using the OPay SDK.
  Future<void> _handleOpayPayment() async {
    if (_isProcessingOpay) return;

    setState(() {
      _isProcessingOpay = true;
      _paymentStatusMessage = 'Processing OPay payment...';
    });

    EasyLoading.show(status: "Loading OPay...", dismissOnTap: false);

    try {
      // Call OPay SDK's createOrder method with the pre-configured PayParams
      final response = await _opayTask.createOrder(
        context,
        widget.opayPayParams,
        httpFinishedMethod: () {
          // This callback fires when the initial HTTP request to OPay finishes
          // EasyLoading.dismiss(); // Don't dismiss yet, payment UI might still load
        },
      );

      EasyLoading.dismiss(); // Dismiss after OPay SDK returns a response

      if (!mounted) return;

      // Check for webJsResponse first, as it contains the final payment status from OPay's UI
      if (response.webJsResponse != null) {
        final status = response.webJsResponse!.orderStatus;
        debugPrint("OPay webJsResponse.status=$status");

        switch (status) {
          case PayResultStatus.success:
            _showFeedbackSnackbar("OPay payment successful!", isSuccess: true);
            Navigator.of(context).pushReplacementNamed(
              OrderSummaryScreen.routeName,
              arguments: {
                'orderId': widget.orderId,
                'customerId': widget.customer.id,
                'showConfirmation': true,
                'transactionRef':
                    response.webJsResponse!.orderNo, // OPay's order number
              },
            );
            break;
          case PayResultStatus.pending:
            _showFeedbackSnackbar(
                "OPay payment is pending. Please complete on OPay app/web.",
                isError: false);
            // Navigate to OrderSummary but without immediate confirmation
            Navigator.of(context).pushReplacementNamed(
              OrderSummaryScreen.routeName,
              arguments: {
                'orderId': widget.orderId,
                'customerId': widget.customer.id,
                'showConfirmation': false,
                'transactionRef': response.webJsResponse!.orderNo,
              },
            );
            break;
          case PayResultStatus.fail:
            // FIX: Access message from payHttpResponse or provide a generic message
            _showFeedbackSnackbar(
              "OPay payment failed: ${response.payHttpResponse.message ?? 'Unknown reason'}", // Use payHttpResponse.message
              isError: true,
            );
            setState(() {
              _paymentStatusMessage = 'Payment Failed. Try Again.';
            });
            break;
          case PayResultStatus.close:
            _showFeedbackSnackbar("OPay payment window closed by user.",
                isError: true);
            setState(() {
              _paymentStatusMessage = 'Payment Cancelled';
            });
            break;
          case PayResultStatus.initial:
            // This state typically means the order was created but not yet processed by OPay.
            _showFeedbackSnackbar("OPay payment initiated, awaiting status.",
                isError: false);
            setState(() {
              _paymentStatusMessage = 'Payment Initiated';
            });
            // Consider navigating to order summary or a waiting screen, relying on webhook
            Navigator.of(context).pushReplacementNamed(
              OrderSummaryScreen.routeName,
              arguments: {
                'orderId': widget.orderId,
                'customerId': widget.customer.id,
                'showConfirmation': false,
                'transactionRef': response.webJsResponse!.orderNo,
              },
            );
            break;
        }
      } else if (response.payHttpResponse.code == "00000") {
        // If webJsResponse is null but HTTP request was successful (order created on OPay side)
        _showFeedbackSnackbar(
            "OPay order created, awaiting payment completion. Check your OPay app.",
            isSuccess: true);
        Navigator.of(context).pushReplacementNamed(
          OrderSummaryScreen.routeName,
          arguments: {
            'orderId': widget.orderId,
            'customerId': widget.customer.id,
            'showConfirmation': false, // No immediate confirmation
            'transactionRef': response.payHttpResponse.data?.orderNo,
          },
        );
      } else {
        // General API error from OPay
        _showFeedbackSnackbar(
            "OPay API error: ${response.payHttpResponse.message}",
            isError: true);
        setState(() {
          _paymentStatusMessage = 'OPay API Error';
        });
      }
    } on PlatformException catch (e) {
      EasyLoading.dismiss();
      if (mounted) {
        setState(() {
          _isProcessingOpay = false;
          _paymentStatusMessage = 'Payment Error';
        });
        _showFeedbackSnackbar("OPay SDK error: ${e.message}", isError: true);
        debugPrint('OPay PlatformException: ${e.code}: ${e.message}');
      }
    } catch (e) {
      EasyLoading.dismiss();
      if (mounted) {
        setState(() {
          _isProcessingOpay = false;
          _paymentStatusMessage = 'Payment Failed';
        });
        _showFeedbackSnackbar(
            "An unexpected error occurred during OPay payment: ${e.toString()}",
            isError: true);
        debugPrint("OPay Payment Error: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingOpay = false);
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
        title: Text('Complete Payment with OPay',
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
                    Icon(Icons.account_balance_wallet_outlined, // OPay icon
                        size: 50,
                        color: themeProvider.gas2doorPrimaryBlue),
                    const SizedBox(height: 16),
                    Text('Pay with OPay',
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
              text: _paymentStatusMessage,
              onPressed: _isProcessingOpay ? null : _handleOpayPayment,
              color: themeProvider.gas2doorPrimaryBlue,
              height: 52,
              icon: _isProcessingOpay
                  ? SizedBox(
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
                child: Text("Powered by OPay",
                    style: GoogleFonts.inter(
                        fontSize: 12, color: themeProvider.tertiaryText))),
          ],
        ),
      ),
    );
  }
}
