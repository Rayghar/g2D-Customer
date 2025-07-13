// File: lib/screens/driver/driver_support_help_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:url_launcher/url_launcher.dart'; // For launching email/phone
import 'dart:async';

import '../../providers/theme_provider.dart';
import '../../widgets/card.dart';
import '../../widgets/button.dart';
// Assuming a shared FAQ model, or a driver-specific one if different
import '../../models/admin/faq_item_model.dart'; // Re-using admin FAQ model for structure

// Mock Service for Driver Support Content
class MockDriverSupportService {
  Future<List<FaqItemModel>> getDriverFaqs() async {
    await Future.delayed(const Duration(milliseconds: 700));
    // These FAQs should be tailored for drivers
    return [
      FaqItemModel(
          id: "dfaq001",
          question: "How do I update my availability status?",
          answer:
              "You can toggle your availability (Online/Offline) using the switch on the top right of your main Dashboard screen.",
          category: "App Usage",
          displayOrder: 1,
          isActive: true),
      FaqItemModel(
          id: "dfaq002",
          question: "What do I do if a customer is not available for pickup?",
          answer:
              "From the Order Details screen for that stop, select 'Customer Not Available'. You may also try contacting the customer via call or chat before marking them unavailable.",
          category: "Order Issues",
          displayOrder: 2,
          isActive: true),
      FaqItemModel(
          id: "dfaq003",
          question: "How are my earnings calculated?",
          answer:
              "Earnings are based on completed deliveries, including base fare and any applicable bonuses or tips. You can view a detailed breakdown in your 'Earnings & Payouts' screen.",
          category: "Earnings",
          displayOrder: 3,
          isActive: true),
      FaqItemModel(
          id: "dfaq004",
          question: "When do I get paid?",
          answer:
              "Payouts are typically processed weekly to your registered bank account. Check the 'Earnings & Payouts' screen for your next expected payout date.",
          category: "Earnings",
          displayOrder: 4,
          isActive: true),
    ];
  }

  Future<Map<String, String>> getSupportContactInfo() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      "phone": "+2347001112222", // Dedicated driver support line
      "email": "driversupport@gas2door.com",
      "whatsapp": "+2347001112233" // Optional WhatsApp
    };
  }
}

class DriverSupportHelpScreen extends StatefulWidget {
  static const String routeName = '/driver_support_help';
  final String driverId;

  const DriverSupportHelpScreen({super.key, required this.driverId});

  @override
  State<DriverSupportHelpScreen> createState() =>
      _DriverSupportHelpScreenState();
}

class _DriverSupportHelpScreenState extends State<DriverSupportHelpScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  List<FaqItemModel> _driverFaqs = [];
  Map<String, String> _supportContacts = {};

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _sectionSlideAnimations;

  final MockDriverSupportService _supportService = MockDriverSupportService();

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _sectionSlideAnimations = List.generate(
      2, // FAQs section, Contact section
      (index) => Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
          .animate(CurvedAnimation(
              parent: _entryAnimController,
              curve: Interval(
                  0.1 + (index * 0.15), 0.8 + (index * 0.1).clamp(0.0, 0.2),
                  curve: Curves.easeOutCubic))),
    );
    _fetchSupportData();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchSupportData({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      if (isRefresh) _errorMessage = null;
    });

    try {
      final faqsFuture = _supportService.getDriverFaqs();
      final contactsFuture = _supportService.getSupportContactInfo();
      final results = await Future.wait([faqsFuture, contactsFuture]);

      if (mounted) {
        setState(() {
          _driverFaqs = results[0] as List<FaqItemModel>;
          _supportContacts = results[1] as Map<String, String>;
          _isLoading = false;
          _errorMessage = null;
        });
        _entryAnimController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load support information: ${e.toString()}";
        });
      }
    }
  }

  Future<void> _launchUri(
      String urlScheme, String path, ThemeProvider themeProvider) async {
    HapticFeedback.lightImpact();
    final Uri uri = Uri(scheme: urlScheme, path: path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted)
        _showFeedbackSnackbar('Could not launch $urlScheme for $path',
            isError: true, themeProvider: themeProvider);
    }
  }

  void _showFeedbackSnackbar(String message,
      {bool isError = false, ThemeProvider? themeProvider}) {
    if (!mounted) return;
    final tp =
        themeProvider ?? Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor:
            isError ? tp.errorColor : tp.successColor.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color driverAccentColor = themeProvider.gas2doorTeal;

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text('Support & Help Center',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: themeProvider.primaryText),
            onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: themeProvider.primaryText),
            onPressed: () => _fetchSupportData(isRefresh: true),
            tooltip: "Refresh Data",
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: driverAccentColor))
          : _errorMessage != null
              ? _buildErrorState(themeProvider, _errorMessage!)
              : FadeTransition(
                  opacity: _entryAnimController,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      SlideTransition(
                          position: _sectionSlideAnimations[0],
                          child: _buildFaqSection(themeProvider)),
                      const SizedBox(height: 24),
                      SlideTransition(
                          position: _sectionSlideAnimations[1],
                          child: _buildContactSupportSection(
                              themeProvider, driverAccentColor)),
                      // TODO: Add section for "App Guides/Tutorials" if needed
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFaqSection(ThemeProvider themeProvider) {
    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Frequently Asked Questions",
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryText)),
              const SizedBox(height: 12),
              if (_driverFaqs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                      child: Text("No FAQs available at the moment.",
                          style: GoogleFonts.inter(
                              color: themeProvider.secondaryText,
                              fontSize: 14))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _driverFaqs.length,
                  itemBuilder: (context, index) {
                    final faq = _driverFaqs[index];
                    return ExpansionTile(
                      iconColor: themeProvider.primaryText.withOpacity(0.7),
                      collapsedIconColor:
                          themeProvider.secondaryText.withOpacity(0.7),
                      tilePadding: const EdgeInsets.symmetric(
                          vertical: 4.0, horizontal: 0), // Adjust padding
                      title: Text(
                        faq.question,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.primaryText),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(
                          8, 0, 8, 12), // Inner padding for answer
                      children: [
                        Text(faq.answer,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: themeProvider.secondaryText,
                                height: 1.45)),
                      ],
                    );
                  },
                  separatorBuilder: (ctx, i) => Divider(
                      color: themeProvider.tertiaryText.withOpacity(0.2),
                      height: 1),
                ),
            ],
          ),
        ));
  }

  Widget _buildContactSupportSection(
      ThemeProvider themeProvider, Color driverAccentColor) {
    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Contact Driver Support",
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryText)),
              const SizedBox(height: 16),
              if (_supportContacts["phone"] != null)
                _buildContactTile(
                    icon: Icons.call_outlined,
                    title: "Call Support: ${_supportContacts["phone"]}",
                    onTap: () => _launchUri(
                        'tel', _supportContacts["phone"]!, themeProvider),
                    themeProvider: themeProvider,
                    accentColor: driverAccentColor),
              if (_supportContacts["email"] != null)
                _buildContactTile(
                    icon: Icons.email_outlined,
                    title: "Email: ${_supportContacts["email"]}",
                    onTap: () => _launchUri(
                        'mailto', _supportContacts["email"]!, themeProvider),
                    themeProvider: themeProvider,
                    accentColor: driverAccentColor),
              if (_supportContacts["whatsapp"] != null)
                _buildContactTile(
                    icon: Icons
                        .chat_bubble_outline_rounded, // Using a generic chat icon for WhatsApp
                    title: "WhatsApp Support: ${_supportContacts["whatsapp"]}",
                    onTap: () => _launchUri(
                        'https://wa.me/',
                        _supportContacts["whatsapp"]!.replaceAll("+", ""),
                        themeProvider), // Basic WhatsApp link
                    themeProvider: themeProvider,
                    accentColor: driverAccentColor),
              if (_supportContacts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(
                      "Support contact information is currently unavailable.",
                      style: GoogleFonts.inter(
                          color: themeProvider.secondaryText, fontSize: 14)),
                )
            ],
          ),
        ));
  }

  Widget _buildContactTile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      required ThemeProvider themeProvider,
      required Color accentColor}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      leading: CircleAvatar(
        backgroundColor: accentColor.withOpacity(0.1),
        foregroundColor: accentColor,
        child: Icon(icon, size: 22),
      ),
      title: Text(title,
          style: GoogleFonts.inter(
              fontSize: 15,
              color: themeProvider.primaryText,
              fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.arrow_forward_ios_rounded,
          size: 16, color: themeProvider.tertiaryText.withOpacity(0.7)),
      onTap: onTap,
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.support_agent_outlined,
                color: themeProvider.errorColor, size: 50),
            const SizedBox(height: 16),
            Text('Error Loading Support Info',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                  color: themeProvider.secondaryText, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: "Retry",
              onPressed: () => _fetchSupportData(isRefresh: true),
              color: themeProvider.gas2doorPrimaryBlue,
              textStyle: GoogleFonts.inter(
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white,
                  fontWeight: FontWeight.w600),
              icon: Icon(Icons.refresh_rounded,
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white),
              height: 48,
              borderRadius: themeProvider.cardBorderRadiusValue,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.help_outline_rounded,
                color: themeProvider.secondaryText.withOpacity(0.5), size: 60),
            const SizedBox(height: 20),
            Text(
              'Support Information Unavailable',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.primaryText),
            ),
            const SizedBox(height: 10),
            Text(
              'We are currently updating our help resources. Please check back later or contact us through alternative channels if urgent.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: themeProvider.secondaryText.withOpacity(0.9)),
            ),
          ],
        ),
      ),
    );
  }
}
