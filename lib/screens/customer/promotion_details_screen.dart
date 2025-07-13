// File: lib/screens/customer/promotion_details_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/deal_model.dart';
import '../../models/address_model.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './order_placement_screen.dart';
import '../more/refer_friend_screen.dart';

class PromotionDetailsScreen extends StatefulWidget {
  static const routeName = '/promotion_details';
  final DealModel promotion;
  final String? customerId;
  final AddressModel? initialAddress;

  const PromotionDetailsScreen({
    super.key,
    required this.promotion,
    this.customerId,
    this.initialAddress,
  });

  @override
  State<PromotionDetailsScreen> createState() => _PromotionDetailsScreenState();
}

class _PromotionDetailsScreenState extends State<PromotionDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryAnimController;
  late Animation<double> _fadeAnimation;
  late List<Animation<Offset>> _sectionSlideAnimations;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryAnimController, curve: Curves.easeIn),
    );
    _sectionSlideAnimations = List.generate(
      5,
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(
            0.2 + (index * 0.1),
            0.8 + (index * 0.1).clamp(0.0, 0.2),
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );
    _entryAnimController.forward();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  void _handleCta(ThemeProvider themeProvider) {
    HapticFeedback.lightImpact();
    Map<String, dynamic> finalCtaArgs =
        Map<String, dynamic>.from(widget.promotion.ctaArgs ?? {});

    if (widget.promotion.ctaLink == OrderPlacementScreen.routeName) {
      if (widget.customerId == null) {
        _showFeedbackSnackbar(
            "Cannot proceed: User information missing.", context, themeProvider,
            isError: true);
        return;
      }
      finalCtaArgs['customerId'] = widget.customerId;
      finalCtaArgs['initialAddress'] = widget.initialAddress;
      finalCtaArgs['isRefill'] = finalCtaArgs['isRefill'] ?? false;

      if (widget.promotion.promoCode != null &&
          widget.promotion.promoCode!.isNotEmpty) {
        finalCtaArgs['prefilledPromoCode'] = widget.promotion.promoCode;
        Clipboard.setData(ClipboardData(text: widget.promotion.promoCode!));
        _showFeedbackSnackbar(
            'Promo code "${widget.promotion.promoCode}" copied! Redirecting...',
            context,
            themeProvider);
      }
    } else if (widget.promotion.ctaLink == ReferFriendScreen.routeName) {
      if (widget.customerId == null) {
        _showFeedbackSnackbar(
            "Cannot proceed: User information missing for referral.",
            context,
            themeProvider,
            isError: true);
        return;
      }
      finalCtaArgs['customerId'] = widget.customerId;
    }

    if (widget.promotion.ctaLink != null) {
      Navigator.of(context, rootNavigator: true).pushNamed(
        widget.promotion.ctaLink!,
        arguments: finalCtaArgs.isNotEmpty ? finalCtaArgs : null,
      );
    } else {
      _showFeedbackSnackbar(
          "No action defined for this promotion's CTA.", context, themeProvider,
          isError: true);
    }
  }

  void _copyPromoCode(String code, ThemeProvider themeProvider) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: code));
    _showFeedbackSnackbar(
        'Promo code "$code" copied to clipboard!', context, themeProvider);
  }

  void _showFeedbackSnackbar(
    String message,
    BuildContext context,
    ThemeProvider themeProvider, {
    bool isError = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError
            ? themeProvider.errorColor
            : themeProvider.successColor.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final promo = widget.promotion;

    final effectiveCardColor =
        promo.cardColor ?? themeProvider.gas2doorPrimaryBlueLightVer;
    final isDarkHeaderBg =
        ThemeData.estimateBrightnessForColor(effectiveCardColor) ==
            Brightness.dark;
    final headerTextColor = promo.textColor ??
        (isDarkHeaderBg ? Colors.white : themeProvider.primaryText);

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text(
          promo.title,
          style: GoogleFonts.inter(
            color: themeProvider.primaryText,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: themeProvider.primaryText,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SlideTransition(
                position: _sectionSlideAnimations[0],
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: effectiveCardColor,
                    image: promo.imageUrl != null
                        ? DecorationImage(
                            image: promo.imageUrl!.startsWith('http')
                                ? NetworkImage(promo.imageUrl!)
                                : AssetImage(promo.imageUrl!) as ImageProvider,
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.30),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          promo.title,
                          style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: headerTextColor,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                    blurRadius: 2,
                                    color: Colors.black.withOpacity(0.5)),
                              ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SlideTransition(
                      position: _sectionSlideAnimations[1],
                      child: CustomCard(
                        color: themeProvider.cardBackground,
                        borderRadius: themeProvider.cardBorderRadiusValue,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Offer Details',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: themeProvider.primaryText,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                promo.longDescription ?? promo.shortDescription,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: themeProvider.secondaryText,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (promo.promoCode != null &&
                        promo.promoCode!.isNotEmpty) ...[
                      SlideTransition(
                        position: _sectionSlideAnimations[2],
                        child: CustomCard(
                          color: themeProvider.cardBackground,
                          borderRadius: themeProvider.cardBorderRadiusValue,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Promo Code',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: themeProvider.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: themeProvider
                                              .appSecondaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: themeProvider.gas2doorTeal
                                                .withOpacity(0.7),
                                          ),
                                        ),
                                        child: Text(
                                          promo.promoCode!,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: themeProvider.gas2doorTeal,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: Icon(
                                        Icons.copy_all_outlined,
                                        color: themeProvider.secondaryText,
                                      ),
                                      tooltip: 'Copy Code',
                                      onPressed: () => _copyPromoCode(
                                          promo.promoCode!, themeProvider),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (promo.validFrom != null ||
                        promo.validUntil != null) ...[
                      SlideTransition(
                        position: _sectionSlideAnimations[3],
                        child: CustomCard(
                          color: themeProvider.cardBackground,
                          borderRadius: themeProvider.cardBorderRadiusValue,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Validity',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: themeProvider.primaryText,
                                    )),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 20,
                                      color: themeProvider.secondaryText,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        promo.validFrom != null &&
                                                promo.validUntil != null
                                            ? 'Valid: ${DateFormat.yMMMd().format(promo.validFrom!)} - ${DateFormat.yMMMd().format(promo.validUntil!)}'
                                            : promo.validUntil != null
                                                ? 'Expires: ${DateFormat.yMMMd().format(promo.validUntil!)}'
                                                : 'Ongoing Offer',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: themeProvider.secondaryText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (promo.termsAndConditions != null &&
                        promo.termsAndConditions!.isNotEmpty)
                      SlideTransition(
                        position: _sectionSlideAnimations[4],
                        child: CustomCard(
                          color: themeProvider.cardBackground,
                          borderRadius: themeProvider.cardBorderRadiusValue,
                          child: ExpansionTile(
                            iconColor: themeProvider.primaryText,
                            collapsedIconColor: themeProvider.secondaryText,
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            title: Text(
                              'Terms & Conditions',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: themeProvider.primaryText,
                              ),
                            ),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Text(
                                  promo.termsAndConditions!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: themeProvider.secondaryText,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: CustomButton(
          text: promo.ctaText,
          onPressed: () => _handleCta(themeProvider),
          color: themeProvider.gas2doorPrimaryBlue,
          height: 52,
          icon: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 18,
            color: themeProvider.infoColorOnDarkBgs,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: themeProvider.infoColorOnDarkBgs,
          ),
        ),
      ),
    );
  }
}
