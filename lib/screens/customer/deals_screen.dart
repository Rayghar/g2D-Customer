// File: lib/screens/customer/deals_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../models/deal_model.dart';
import '../../models/address_model.dart';
import './promotion_details_screen.dart';
import './order_placement_screen.dart';
import '../more/refer_friend_screen.dart';
import '../../services/api_service.dart';

class DealsScreen extends StatefulWidget {
  static const String routeName = '/deals';
  final GlobalKey<NavigatorState> navigatorKey;
  final String? customerId;
  final AddressModel? initialAddress;

  const DealsScreen({
    super.key,
    required this.navigatorKey,
    this.customerId,
    this.initialAddress,
  });

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<DealModel> _deals = [];
  String? _errorMessage;
  late AnimationController _listAnimationController;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fetchDeals();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchDeals({bool isRefresh = false}) async {
    if (!mounted) return;
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final fetchedDeals = await _apiService.getActivePromotions();

      if (!mounted) return;
      setState(() {
        _deals = fetchedDeals;
        _isLoading = false;
        _errorMessage = null;
        if (_deals.isNotEmpty) {
          _listAnimationController.reset();
          _listAnimationController.forward();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        _isLoading = false;
        _deals = [];
      });
      _showFeedbackSnackbar(_errorMessage!, isError: true);
    }
  }

  void _handleDealTap(DealModel deal) {
    HapticFeedback.lightImpact();
    Navigator.of(context, rootNavigator: true).pushNamed(
      PromotionDetailsScreen.routeName,
      arguments: {
        'promotion': deal,
        'customerId': widget.customerId,
        'initialAddress': widget.initialAddress,
      },
    );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text('Deals & Offers',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        automaticallyImplyLeading: false,
      ),
      backgroundColor: themeProvider.appSecondaryBackground,
      body: _buildDealsContent(context, themeProvider),
    );
  }

  Widget _buildDealsContent(BuildContext context, ThemeProvider themeProvider) {
    return RefreshIndicator(
      onRefresh: () => _fetchDeals(isRefresh: true),
      color: themeProvider.gas2doorPrimaryBlue,
      backgroundColor: themeProvider.cardBackground,
      child: _buildBody(themeProvider),
    );
  }

  Widget _buildBody(ThemeProvider themeProvider) {
    if (_isLoading && _deals.isEmpty) {
      return _buildLoadingShimmer(themeProvider);
    }
    if (_errorMessage != null) {
      return _buildErrorState(themeProvider);
    }
    if (_deals.isEmpty && !_isLoading) {
      return _buildEmptyState(themeProvider);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deals.length,
      itemBuilder: (context, index) {
        final deal = _deals[index];
        final itemAnimation =
            Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
                .animate(
          CurvedAnimation(
            parent: _listAnimationController,
            curve: Interval(
              (0.1 * index).clamp(0.0, 1.0),
              (0.6 + 0.1 * index).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
          ),
        );
        if (!_isLoading && _deals.isNotEmpty)
          _listAnimationController.forward();

        return FadeTransition(
          opacity: _listAnimationController,
          child: SlideTransition(
            position: itemAnimation,
            child: _DealCardWidget(
              deal: deal,
              themeProvider: themeProvider,
              onTap: () => _handleDealTap(deal),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingShimmer(ThemeProvider themeProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return CustomCard(
          margin: const EdgeInsets.only(bottom: 16),
          color: themeProvider.cardBackground,
          borderRadius: themeProvider.cardBorderRadiusValue,
          child: SizedBox(
            height: 140,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeletonLine(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: 22,
                          themeProvider: themeProvider,
                          borderRadius: 6),
                      const SizedBox(height: 10),
                      _buildSkeletonLine(
                          width: double.infinity,
                          height: 16,
                          themeProvider: themeProvider),
                      const SizedBox(height: 6),
                      _buildSkeletonLine(
                          width: MediaQuery.of(context).size.width * 0.7,
                          height: 16,
                          themeProvider: themeProvider),
                    ],
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: _buildSkeletonLine(
                        width: 100,
                        height: 36,
                        themeProvider: themeProvider,
                        borderRadius: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLine({
    required double width,
    required double height,
    required ThemeProvider themeProvider,
    double borderRadius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.grey[700]!.withOpacity(0.6)
            : Colors.grey[300]!,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: themeProvider.secondaryText.withOpacity(0.7), size: 60),
            const SizedBox(height: 20),
            Text('Failed to Load Deals',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Please check your connection and try again.',
                style: GoogleFonts.inter(
                    fontSize: 15, color: themeProvider.secondaryText),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Retry',
              onPressed: () => _fetchDeals(isRefresh: true),
              color: themeProvider.gas2doorPrimaryBlue,
              icon: Icon(Icons.refresh_rounded,
                  color: themeProvider.infoColorOnDarkBgs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_very_dissatisfied_rounded,
                color: themeProvider.secondaryText.withOpacity(0.5), size: 80),
            const SizedBox(height: 24),
            Text('No Deals Available Right Now',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            Text("We're always working on new offers. Please check back soon!",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    color: themeProvider.secondaryText,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _DealCardWidget extends StatelessWidget {
  final DealModel deal;
  final ThemeProvider themeProvider;
  final VoidCallback onTap;

  const _DealCardWidget({
    required this.deal,
    required this.themeProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = deal.cardColor ?? themeProvider.cardBackground;
    final isDarkCard =
        ThemeData.estimateBrightnessForColor(cardColor) == Brightness.dark;
    final textColor = deal.textColor ??
        (isDarkCard
            ? Colors.white.withOpacity(0.95)
            : themeProvider.primaryText);
    final subTextColor = deal.textColor?.withOpacity(0.85) ??
        (isDarkCard
            ? Colors.white.withOpacity(0.8)
            : themeProvider.secondaryText);
    final validityColor = deal.textColor?.withOpacity(0.75) ??
        (isDarkCard
            ? Colors.white.withOpacity(0.7)
            : themeProvider.tertiaryText);

    return CustomCard(
      color: cardColor,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 3.5,
      shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.5),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: themeProvider.cardBorderRadius,
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.05),
        child: Container(
          height: 150,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: themeProvider.cardBorderRadius,
            image: deal.imageUrl != null && deal.imageUrl!.isNotEmpty
                ? DecorationImage(
                    image: deal.imageUrl!.startsWith('http')
                        ? NetworkImage(deal.imageUrl!)
                        : AssetImage(deal.imageUrl!) as ImageProvider,
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.40), BlendMode.darken),
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deal.title,
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: 0.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(deal.shortDescription,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: subTextColor, height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (deal.validUntil != null)
                    Text(
                        'Expires: ${DateFormat('MMM dd, yyyy').format(deal.validUntil!)}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: validityColor)),
                  const Spacer(),
                  if (deal.ctaText.isNotEmpty)
                    CustomButton(
                      text: deal.ctaText,
                      onPressed: onTap,
                      color: (isDarkCard
                              ? themeProvider.gas2doorPrimaryBlueLightVer
                              : themeProvider.gas2doorPrimaryBlue)
                          .withOpacity(0.9),
                      textStyle: GoogleFonts.inter(
                          color: isDarkCard
                              ? themeProvider.primaryText
                              : themeProvider.infoColorOnDarkBgs,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      height: 38,
                      elevation: 1,
                      borderRadius: 20,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
