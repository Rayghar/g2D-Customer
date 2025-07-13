// File: lib/screens/more/refer_friend_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart'; // For sharing functionality

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../services/api_service.dart';
import '../../models/referral_model.dart'; // Import the new ReferralModel

class ReferFriendScreen extends StatefulWidget {
  static const String routeName = '/refer_friend';
  final String customerId; // Passed from profile screen
  const ReferFriendScreen({super.key, required this.customerId});

  @override
  State<ReferFriendScreen> createState() => _ReferFriendScreenState();
}

class _ReferFriendScreenState extends State<ReferFriendScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  ReferralModel? _referralData;
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _entryAnimController;
  late Animation<Offset> _contentSlideAnimation;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _contentSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryAnimController, curve: Curves.easeOutCubic));
    _fetchReferralInfo();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchReferralInfo() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _apiService.getReferralInformation(widget.customerId);
      if (mounted) {
        setState(() {
          _referralData = data;
          _isLoading = false;
        });
        _entryAnimController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              "Failed to load referral info: ${e.toString().replaceFirst("Exception: ", "")}";
          _isLoading = false;
        });
      }
    }
  }

  void _shareReferralCode() {
    HapticFeedback.lightImpact();
    if (_referralData == null || _referralData!.referralCode.isEmpty) {
      _showFeedbackSnackbar('No referral code available to share.',
          isError: true);
      return;
    }

    final String shareText =
        "Hey! Get your gas delivered quickly with Gas2Door. Use my referral code "
        "'${_referralData!.referralCode}' to get ${_referralData!.benefitFriend} on your first order!\n\n"
        "Download the app here: [Your App Store Link]"; // Replace with actual link

    Share.share(shareText, subject: 'Get Gas Delivered with My Referral Code!');
  }

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
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
    return Scaffold(
      backgroundColor: themeProvider.appPrimaryBackground,
      appBar: AppBar(
        title: Text("Refer a Friend",
            style: GoogleFonts.inter(
                color: themeProvider.primaryText, fontWeight: FontWeight.w600)),
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchReferralInfo,
        color: themeProvider.gas2doorPrimaryBlue,
        backgroundColor: themeProvider.cardBackground,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                    color: themeProvider.gas2doorPrimaryBlue))
            : _errorMessage != null
                ? _buildErrorState(themeProvider)
                : FadeTransition(
                    opacity: _entryAnimController,
                    child: SlideTransition(
                      position: _contentSlideAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CustomCard(
                              color: themeProvider.cardBackground,
                              elevation: 2,
                              borderRadius: themeProvider.cardBorderRadiusValue,
                              shadowColor: themeProvider.cardShadowColorGlobal
                                  .withOpacity(0.5),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_alt_outlined,
                                        size: 60,
                                        color: themeProvider.gas2doorTeal),
                                    const SizedBox(height: 16),
                                    Text(
                                      _referralData?.programDescription ??
                                          'Share and earn rewards!',
                                      style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: themeProvider.primaryText),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Your Unique Referral Code:',
                                        style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color:
                                                themeProvider.secondaryText)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      decoration: BoxDecoration(
                                          color: themeProvider
                                              .gas2doorPrimaryBlueLightVer
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: themeProvider
                                                  .gas2doorPrimaryBlue
                                                  .withOpacity(0.5))),
                                      child: SelectableText(
                                        _referralData!.referralCode,
                                        style: GoogleFonts.inter(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: themeProvider
                                                .gas2doorPrimaryBlue,
                                            letterSpacing: 2),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    CustomButton(
                                      text: "Share Your Code",
                                      onPressed: _shareReferralCode,
                                      color: themeProvider.gas2doorPrimaryBlue,
                                      icon: const Icon(Icons.share_rounded,
                                          color: Colors.white),
                                      textStyle: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 20),
                                    Divider(
                                        color: themeProvider.tertiaryText
                                            .withOpacity(0.2)),
                                    const SizedBox(height: 20),
                                    _buildBenefitSection(
                                        'Your Benefit (Referrer)',
                                        _referralData?.benefitSelf ?? 'N/A',
                                        Icons.wallet_giftcard_outlined,
                                        themeProvider),
                                    const SizedBox(height: 16),
                                    _buildBenefitSection(
                                        'Friend\'s Benefit (Referee)',
                                        _referralData?.benefitFriend ?? 'N/A',
                                        Icons.discount_outlined,
                                        themeProvider),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatBox(
                                            'Referred',
                                            _referralData?.totalReferredCount
                                                    .toString() ??
                                                '0',
                                            themeProvider),
                                        _buildStatBox(
                                            'Successful',
                                            _referralData
                                                    ?.successfulReferralsCount
                                                    .toString() ??
                                                '0',
                                            themeProvider),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Optional: Instructions/FAQs section
                            CustomCard(
                              color: themeProvider.cardBackground,
                              elevation: 1.5,
                              borderRadius: themeProvider.cardBorderRadiusValue,
                              shadowColor: themeProvider.cardShadowColorGlobal
                                  .withOpacity(0.3),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('How it Works:',
                                        style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: themeProvider.primaryText)),
                                    const SizedBox(height: 10),
                                    _buildInstructionStep(
                                        '1. Share Your Code:',
                                        'Share your unique referral code with friends and family via social media, messaging, etc.',
                                        themeProvider),
                                    _buildInstructionStep(
                                        '2. Friend Orders:',
                                        'Your friend downloads the Gas2Door app and uses your code during their first order.',
                                        themeProvider),
                                    _buildInstructionStep(
                                        '3. You Earn:',
                                        'Once your friend’s first order is successfully delivered and paid for, you receive your reward!',
                                        themeProvider),
                                    _buildInstructionStep(
                                        '4. Friend Benefits:',
                                        'Your friend instantly enjoys their first-order discount when they apply your code.',
                                        themeProvider),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildBenefitSection(String title, String description, IconData icon,
      ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: themeProvider.gas2doorTeal),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28.0),
          child: Text(description,
              style: GoogleFonts.inter(
                  fontSize: 14, color: themeProvider.secondaryText)),
        ),
      ],
    );
  }

  Widget _buildStatBox(
      String label, String value, ThemeProvider themeProvider) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: themeProvider.gas2doorPrimaryBlue)),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13, color: themeProvider.secondaryText)),
      ],
    );
  }

  Widget _buildInstructionStep(
      String title, String description, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.primaryText)),
          Text(description,
              style: GoogleFonts.inter(
                  fontSize: 13, color: themeProvider.secondaryText)),
        ],
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
            Icon(Icons.error_outline_rounded,
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Error Loading Referral Info',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Please check your connection and try again.',
                style: GoogleFonts.inter(
                    fontSize: 15, color: themeProvider.secondaryText),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            CustomButton(
                text: 'Retry',
                onPressed: _fetchReferralInfo,
                color: themeProvider.gas2doorPrimaryBlue,
                icon: Icon(Icons.refresh_rounded,
                    color: themeProvider.infoColorOnDarkBgs)),
          ],
        ),
      ),
    );
  }
}
