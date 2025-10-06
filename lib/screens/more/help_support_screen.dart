// File: lib/screens/more/help_support_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/card.dart'; // Your CustomCard
import '../../widgets/input.dart'; // For search bar

// Model for FAQ item - REMOVED 'isExpanded' as it's no longer needed
class FaqItem {
  final String id;
  final String question;
  final String answer;

  FaqItem({
    required this.id,
    required this.question,
    required this.answer,
  });
}

class HelpSupportScreen extends StatefulWidget {
  static const String routeName = '/help_support';
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true; // For potential future FAQ fetching
  final List<FaqItem> _baseFaqs = [
    // Hardcoded for now
    FaqItem(
        id: 'faq1',
        question: 'How do I place an order?',
        answer:
            'You can place an order by navigating to the "Order Gas" section from the home screen, selecting your desired cylinder size and quantity, confirming your delivery address, and proceeding to payment.'),
    FaqItem(
        id: 'faq2',
        question: 'What are the available gas cylinder sizes?',
        answer:
            'We currently offer 3kg, 5kg, 6kg, 12.5kg, 25kg, and 50kg cylinders. Availability may vary by location.'),
    FaqItem(
        id: 'faq3',
        question: 'How can I track my order?',
        answer:
            'Once your order is out for delivery, you can track your driver in real-time from the "Order Details" screen or the "Track Driver" option if available for your active order.'),
    FaqItem(
        id: 'faq4',
        question: 'What are the payment methods accepted?',
        answer:
            'We currently support online payments via card (simulated) and Pay on Delivery (mock). More options will be added soon.'),
    FaqItem(
        id: 'faq5',
        question: 'How do I cancel an order?',
        answer:
            'You can cancel an order from the "Order Details" screen if it has not yet been dispatched. Look for the "Cancel Order" button.'),
    FaqItem(
        id: 'faq6',
        question: 'How long does delivery take?',
        answer:
            'Standard delivery usually takes between 1-3 hours. Express delivery aims for under 60 minutes, subject to availability and location. You can see an ETA once a driver is assigned.'),
  ];
  List<FaqItem> _filteredFaqs = [];
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _sectionSlideAnimations;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _sectionSlideAnimations = List.generate(
      2, // Number of main sections (FAQ, Contact)
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(
              0.1 + (index * 0.15), 0.7 + (index * 0.1).clamp(0.0, 0.3),
              curve: Curves.easeOutCubic),
        ),
      ),
    );

    _filteredFaqs = List.from(_baseFaqs);
    _searchController.addListener(_filterFaqs);

    // Simulate loading if FAQs were fetched
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _isLoading = false);
        _entryAnimController.forward();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterFaqs);
    _searchController.dispose();
    _entryAnimController.dispose();
    super.dispose();
  }

  void _filterFaqs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFaqs = _baseFaqs.where((faq) {
        return faq.question.toLowerCase().contains(query) ||
            faq.answer.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _launchCaller(
      String phoneNumber, ThemeProvider themeProvider) async {
    HapticFeedback.lightImpact();
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted)
        _showFeedbackSnackbar(
            'Could not launch phone dialer.', context, themeProvider,
            isError: true);
    }
  }

  Future<void> _launchWhatsApp(
      String phoneNumber, ThemeProvider themeProvider) async {
    HapticFeedback.lightImpact();
    final String whatsappUrl =
        "https://wa.me/$phoneNumber"; // Includes country code
    final Uri launchUri = Uri.parse(whatsappUrl);

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        _showFeedbackSnackbar(
            'Could not open WhatsApp. Make sure it is installed.',
            context,
            themeProvider,
            isError: true);
      }
    }
  }

  Future<void> _launchEmail(String emailAddress, ThemeProvider themeProvider,
      {bool isReport = false}) async {
    HapticFeedback.lightImpact();
    final String subject = isReport
        ? 'Gas2Door App - Issue Report'
        : 'Gas2Door App Support Request';

    final Uri launchUri = Uri(
        scheme: 'mailto',
        path: emailAddress,
        queryParameters: {'subject': subject});
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted)
        _showFeedbackSnackbar(
            'Could not launch email client.', context, themeProvider,
            isError: true);
    }
  }

  void _showFeedbackSnackbar(
      String message, BuildContext ctx, ThemeProvider themeProvider,
      {bool isError = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
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
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text(
          'Help & Support',
          style: GoogleFonts.inter(
              color: themeProvider.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: 18),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: themeProvider.gas2doorPrimaryBlue))
          : FadeTransition(
              opacity: _entryAnimController,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SlideTransition(
                      position: _sectionSlideAnimations[0],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Frequently Asked Questions',
                            style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.primaryText),
                          ),
                          const SizedBox(height: 12),
                          CustomInput(
                            controller: _searchController,
                            hintText: 'Search FAQs...',
                            prefixIcon: Icons.search_rounded,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => _filterFaqs(),
                          ),
                          const SizedBox(height: 24),
                          if (_filteredFaqs.isEmpty &&
                              _searchController.text.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20.0),
                              child: Center(
                                child: Text("No FAQs match your search.",
                                    style: GoogleFonts.inter(
                                        color: themeProvider.secondaryText)),
                              ),
                            )
                          else if (_filteredFaqs.isEmpty &&
                              _searchController.text.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20.0),
                              child: Center(
                                child: Text("No FAQs available at the moment.",
                                    style: GoogleFonts.inter(
                                        color: themeProvider.secondaryText)),
                              ),
                            )
                          else
                            // ### CHANGED SECTION ###
                            // Replaced the ExpansionPanelList with a simple Column
                            // to display questions and answers directly.
                            Column(
                              children: _filteredFaqs
                                  .map((item) =>
                                      _buildFaqItem(item, themeProvider))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SlideTransition(
                      position: _sectionSlideAnimations[1],
                      child: CustomCard(
                        color: themeProvider.cardBackground,
                        borderRadius: themeProvider.cardBorderRadiusValue,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16.0, 16.0, 16.0, 8.0),
                              child: Text(
                                'NEED MORE HELP?',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: themeProvider.secondaryText
                                        .withOpacity(0.9),
                                    letterSpacing: 0.5),
                              ),
                            ),
                            _buildContactListTile(
                              iconWidget: FaIcon(FontAwesomeIcons.whatsapp,
                                  color: Color(0xFF25D366), size: 26),
                              title: 'Chat with Us',
                              subtitle: 'Open a chat on WhatsApp',
                              themeProvider: themeProvider,
                              onTap: () => _launchWhatsApp(
                                  '2347051610832', themeProvider),
                            ),
                            _buildDivider(themeProvider),
                            _buildContactListTile(
                              iconData: Icons.report_problem_outlined,
                              title: 'Report an Issue',
                              subtitle: 'Let us know about a problem',
                              themeProvider: themeProvider,
                              onTap: () => _launchEmail(
                                  'primejetgas@gmail.com', themeProvider,
                                  isReport: true),
                            ),
                            _buildDivider(themeProvider),
                            _buildContactListTile(
                              iconData: Icons.phone_outlined,
                              title: 'Call Us',
                              subtitle: '+234 705 161 0832',
                              themeProvider: themeProvider,
                              onTap: () => _launchCaller(
                                  '+2347051610832', themeProvider),
                            ),
                            _buildDivider(themeProvider),
                            _buildContactListTile(
                              iconData: Icons.email_outlined,
                              title: 'Email Support',
                              subtitle: 'support@gas2door.com',
                              themeProvider: themeProvider,
                              onTap: () => _launchEmail(
                                  'primejetgas@gmail.com', themeProvider),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // NEW HELPER WIDGET for displaying a single FAQ item
  Widget _buildFaqItem(FaqItem item, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.question,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600, // Bolder question
              color: themeProvider.primaryText,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.answer,
            style: GoogleFonts.inter(
              color: themeProvider.secondaryText,
              height: 1.4,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            color: themeProvider.tertiaryText.withOpacity(0.1),
            thickness: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildContactListTile({
    IconData? iconData,
    Widget? iconWidget,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    required ThemeProvider themeProvider,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: iconWidget ??
          Icon(iconData, color: themeProvider.gas2doorPrimaryBlue, size: 26),
      title: Text(title,
          style: GoogleFonts.inter(
              fontSize: 16,
              color: themeProvider.primaryText,
              fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: GoogleFonts.inter(
              fontSize: 14, color: themeProvider.secondaryText)),
      trailing: onTap != null
          ? Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: themeProvider.tertiaryText)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(themeProvider.cardBorderRadiusValue / 2)),
    );
  }

  Widget _buildDivider(ThemeProvider themeProvider) {
    return Divider(
      height: 0.5,
      thickness: 0.3,
      color: themeProvider.tertiaryText.withOpacity(0.2),
      indent: 16 + 26 + 16, // Leading icon size + padding
      endIndent: 16,
    );
  }
}
