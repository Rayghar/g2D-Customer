// File: lib/screens/customer/payment_screen.dart
// ADVISORY: This is the complete, reimagined version with the "Floating Purple Receipt" design.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:monnify_payment_sdk/monnify_payment_sdk.dart';
import 'package:monnify_payment_sdk/src/models/transaction_response.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './order_summary_screen.dart';
import '../../models/user.dart' as app_user;
import '../../models/order.dart' as app_order;
import '../../services/api_service.dart';

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
    _initializeMonnify();
  }

  Future<void> _initializeMonnify() async {
    try {
      const apiKey = "MK_TEST_L969MNXY0V"; // Should be from a secure source
      const contractCode = "8609686503"; // Should be from a secure source

      if (apiKey.isEmpty || contractCode.isEmpty) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
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
      _statusMessage = 'Redirecting...';
    });

    final transactionDetails = TransactionDetails(
      amount: widget.amount / 100.0,
      currencyCode: "NGN",
      customerName: widget.customer.name,
      customerEmail: widget.customer.email,
      paymentReference: widget.orderId,
      paymentDescription: widget.order.itemsPreview,
      paymentMethods: [PaymentMethod.CARD, PaymentMethod.ACCOUNT_TRANSFER],
    );

    try {
      final TransactionResponse? response =
          await _monnify!.initializePayment(transaction: transactionDetails);
      if (!mounted) return;

      final bool isPaid = response?.transactionStatus ==
          TransactionStatus.PAID.toString().split('.').last;

      if (isPaid) {
        _showFeedbackSnackbar('Payment initiated. Verifying with server...',
            isSuccess: true);
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
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = 'Pay Now';
          });
        }
      }
    } catch (e) {
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
          onPressed: () => Navigator.of(context).pop(false),
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
    return Column(
      children: [
        Divider(color: Colors.white.withOpacity(0.2)),
        const SizedBox(height: 8),
        _buildPriceDetailRow('Subtotal:',
            currencyFormat.format(order.itemsSubtotal / 100), themeProvider),
        _buildPriceDetailRow('Delivery Fee:',
            currencyFormat.format(order.deliveryFee), themeProvider),
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
            Text(currencyFormat.format(order.finalAmountPaid / 100),
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
