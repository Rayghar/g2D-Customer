// File: lib/screens/customer/profile/wallet_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/theme_provider.dart';
import '../../../widgets/card.dart';
import '../../../widgets/button.dart';
import '../../../models/wallet_transaction.dart';
import '../../../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  static const String routeName = '/wallet';
  final String customerId;

  const WalletScreen({super.key, required this.customerId});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ApiService _apiService = ApiService();
  double _walletBalance = 0.0;
  List<WalletTransaction> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchWalletDetails();
  }

  Future<void> _fetchWalletDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final walletData = await _apiService.getWalletDetails();
      if (mounted) {
        setState(() {
          _walletBalance =
              (walletData['walletBalance'] as num?)?.toDouble() ?? 0.0;
          final List<dynamic> transactionsJson =
              walletData['recentTransactions'] as List<dynamic>? ?? [];
          _transactions = transactionsJson
              .map((json) => WalletTransaction.fromJson(json))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
        });
      }
    }
  }

  void _handleTopUp() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Wallet Top-up: Not yet implemented.',
            style: GoogleFonts.inter()),
        backgroundColor:
            Provider.of<ThemeProvider>(context, listen: false).warningColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final NumberFormat currencyFormatter =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        title: Text('My Wallet',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, color: themeProvider.primaryText)),
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_card_rounded,
                color: themeProvider.gas2doorPrimaryBlue),
            tooltip: 'Top-up Wallet',
            onPressed: _handleTopUp,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: themeProvider.gas2doorPrimaryBlue))
          : RefreshIndicator(
              onRefresh: _fetchWalletDetails,
              color: themeProvider.gas2doorPrimaryBlue,
              backgroundColor: themeProvider.cardBackground,
              child: _errorMessage != null
                  ? _buildErrorState(themeProvider)
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(16.0),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate(
                              [
                                _buildBalanceCard(
                                    themeProvider, currencyFormatter),
                                const SizedBox(height: 24),
                                Text('Transaction History',
                                    style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: themeProvider.primaryText)),
                                const SizedBox(height: 12),
                                _transactions.isEmpty
                                    ? _buildEmptyState(themeProvider)
                                    : _buildTransactionList(
                                        themeProvider, currencyFormatter),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildBalanceCard(
      ThemeProvider themeProvider, NumberFormat formatter) {
    return CustomCard(
      color: themeProvider.gas2doorPrimaryBlue,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Balance',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    color: themeProvider.infoColorOnDarkBgs.withOpacity(0.9),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(formatter.format(_walletBalance / 100),
                style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.infoColorOnDarkBgs)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(
      ThemeProvider themeProvider, NumberFormat formatter) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final transaction = _transactions[index];
        final isCredit = transaction.isCredit;
        final amountColor =
            isCredit ? themeProvider.successColor : themeProvider.errorColor;
        final amountPrefix = isCredit ? '+' : '-';

        return CustomCard(
          color: themeProvider.cardBackground,
          margin: const EdgeInsets.only(bottom: 12),
          borderRadius: themeProvider.cardBorderRadiusValue,
          elevation: 1.5,
          shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: CircleAvatar(
              backgroundColor: amountColor.withOpacity(0.15),
              child: Icon(
                  isCredit
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: amountColor,
                  size: 22),
            ),
            title: Text(transaction.description,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    color: themeProvider.primaryText,
                    fontSize: 14.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Text(transaction.formattedDate,
                style: GoogleFonts.inter(
                    color: themeProvider.secondaryText, fontSize: 12)),
            trailing: Text(
              '$amountPrefix${formatter.format(transaction.amount / 100)}',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                  fontSize: 14.5),
            ),
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off_rounded,
                  color: themeProvider.secondaryText.withOpacity(0.5),
                  size: 60),
              const SizedBox(height: 16),
              Text('No Transactions Yet',
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryText)),
              const SizedBox(height: 8),
              Text('Your wallet activity will appear here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: themeProvider.secondaryText)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider) {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline_rounded,
                  color: themeProvider.errorColor, size: 50),
              const SizedBox(height: 16),
              Text('Failed to Load Wallet',
                  style: GoogleFonts.inter(
                      color: themeProvider.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                  _errorMessage ??
                      'Could not fetch wallet details. Please try again.',
                  style: GoogleFonts.inter(
                      color: themeProvider.secondaryText, fontSize: 15),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              CustomButton(
                  text: 'Retry',
                  onPressed: _fetchWalletDetails,
                  color: themeProvider.gas2doorPrimaryBlue),
            ])));
  }
}
