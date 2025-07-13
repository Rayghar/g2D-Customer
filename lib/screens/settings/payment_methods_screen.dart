// lib/screens/settings/payment_methods_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../models/payment_method_model.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';

/// Helper function to display a snackbar message.
void showSnackbar(BuildContext context, String message,
    {bool isError = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor:
          isError ? Theme.of(context).colorScheme.error : Colors.green,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class PaymentMethodsScreen extends StatefulWidget {
  static const String routeName = '/payment-methods';
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<PaymentMethodModel>> _paymentMethodsFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _refreshPaymentMethods();
  }

  void _refreshPaymentMethods() {
    if (!mounted) return;
    setState(() {
      _paymentMethodsFuture = _apiService.getPaymentMethods();
    });
  }

  /// Handles adding a new card using the system's admin-configured default gateway.
  Future<void> _handleAddNewCard() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    String? clientSecret;
    String? gateway;

    try {
      // 1. Create a SetupIntent on your server.
      final setupIntentData = await _apiService.createSetupIntent();
      clientSecret = setupIntentData['clientSecret'] as String?;
      gateway = setupIntentData['gateway'] as String?;

      if (clientSecret == null || gateway == null) {
        throw Exception('Invalid setup data from server.');
      }

      // 2. Use the appropriate SDK based on the gateway from the server.
      if (gateway == 'stripe') {
        // Initialize and present the Stripe sheet
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            merchantDisplayName: 'PrimeJet',
            setupIntentClientSecret: clientSecret,
            style: Theme.of(context).brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
          ),
        );
        await Stripe.instance.presentPaymentSheet();

        // 3. CRITICAL FIX: After the sheet closes, retrieve the SetupIntent
        // to get the paymentMethodId.
        final intent = await Stripe.instance.retrieveSetupIntent(clientSecret);
        final paymentMethodId = intent.paymentMethodId;

        if (paymentMethodId == null) {
          throw Exception('Could not retrieve payment method after setup.');
        }

        // 4. Send the new paymentMethodId to YOUR backend to be saved.
        await _apiService.attachPaymentMethod(
          stripePaymentMethodId: paymentMethodId,
          gateway: gateway,
        );

        showSnackbar(context, 'Card added successfully!');
        _refreshPaymentMethods();
      } else {
        showSnackbar(
            context, 'The configured gateway "$gateway" is not supported.',
            isError: true);
      }
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        showSnackbar(context,
            'Error: ${e.error.localizedMessage ?? 'An unknown error.'}',
            isError: true);
      }
    } catch (e) {
      showSnackbar(context, 'An unexpected error occurred: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleDelete(String methodId) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text(
                'Are you sure you want to delete this payment method?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Delete',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() => _isProcessing = true);
      try {
        await _apiService.deletePaymentMethod(methodId);
        showSnackbar(context, 'Payment method deleted.');
        _refreshPaymentMethods();
      } catch (e) {
        showSnackbar(context, 'Error deleting card: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleSetDefault(String methodId) async {
    setState(() => _isProcessing = true);
    try {
      await _apiService.setDefaultPaymentMethod(methodId);
      showSnackbar(context, 'Default payment method updated.');
      _refreshPaymentMethods();
    } catch (e) {
      showSnackbar(context, 'Error setting default: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.appPrimaryBackground,
      appBar: AppBar(
        title: Text("Payment Methods",
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => _refreshPaymentMethods(),
            child: FutureBuilder<List<PaymentMethodModel>>(
              future: _paymentMethodsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !_isProcessing) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildErrorState(
                      themeProvider, snapshot.error.toString());
                }
                final paymentMethods = snapshot.data ?? [];
                if (paymentMethods.isEmpty) {
                  return _buildEmptyState(themeProvider);
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16).copyWith(bottom: 100),
                  itemCount: paymentMethods.length,
                  itemBuilder: (context, index) {
                    final method = paymentMethods[index];
                    return _buildPaymentMethodTile(method, themeProvider);
                  },
                );
              },
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: CustomButton(
          text: 'Add New Card',
          onPressed: _handleAddNewCard,
          icon: const Icon(Icons.add_card_rounded),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(
      PaymentMethodModel method, ThemeProvider themeProvider) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getCardIcon(method.brand),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${method.brand} ending in ${method.last4}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: themeProvider.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Expires ${method.expiryDate}',
                        style: GoogleFonts.inter(
                            color: themeProvider.secondaryText, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (method.isDefault)
                  Chip(
                    label: Text('Default',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.successColor)),
                    backgroundColor:
                        themeProvider.successColor.withOpacity(0.15),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    side: BorderSide.none,
                  ),
              ],
            ),
            Divider(
                color: themeProvider.tertiaryText.withOpacity(0.2), height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!method.isDefault)
                  TextButton(
                    onPressed: () => _handleSetDefault(method.id),
                    child: const Text('Set as Default'),
                  ),
                TextButton(
                  onPressed: () => _handleDelete(method.id),
                  child: Text('Delete',
                      style: TextStyle(color: themeProvider.errorColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCardIcon(String? brand) {
    final brandLower = brand?.toLowerCase() ?? '';
    if (brandLower == 'visa') {
      return const Icon(Icons.credit_card, size: 40, color: Color(0xFF1A1F71));
    }
    if (brandLower == 'mastercard') {
      return const Icon(Icons.credit_card, size: 40, color: Color(0xFFEB001B));
    }
    return const Icon(Icons.credit_card, size: 40);
  }

  Widget _buildEmptyState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_card_outlined,
                color: themeProvider.secondaryText.withOpacity(0.6), size: 80),
            const SizedBox(height: 24),
            Text('No Saved Payment Methods',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            Text(
              'Add a card to make your checkout process faster next time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  color: themeProvider.secondaryText,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card_off_outlined,
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Failed to Load Cards',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(error,
                style: GoogleFonts.inter(
                    fontSize: 15, color: themeProvider.secondaryText),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            CustomButton(
                text: "Retry",
                onPressed: _refreshPaymentMethods,
                icon: const Icon(Icons.refresh_rounded))
          ],
        ),
      ),
    );
  }
}
