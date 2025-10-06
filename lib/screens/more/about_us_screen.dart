// File: lib/screens/more/about_us_screen.dart
// (Assuming you create a 'more' or 'settings' subfolder in screens)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart'; // Ensure this package is in pubspec.yaml
import 'package:url_launcher/url_launcher.dart'; // Ensure this package is in pubspec.yaml
import 'package:flutter/services.dart'; // For HapticFeedback

import '../../providers/theme_provider.dart';
import '../../widgets/card.dart'; // Your CustomCard

class AboutUsScreen extends StatefulWidget {
  static const String routeName = '/about_us';
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen>
    with TickerProviderStateMixin {
  PackageInfo _packageInfo = PackageInfo(
    // This initialization is fine once PackageInfo class is recognized
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
  );
  bool _isLoadingPackageInfo = true;

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _sectionSlideAnimations;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _sectionSlideAnimations = List.generate(
      4, // Number of sections to animate
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(
              0.1 + (index * 0.15), 0.8 + (index * 0.1).clamp(0.0, 0.2),
              curve: Curves.easeOutCubic),
        ),
      ),
    );
    _initPackageInfo();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _initPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _packageInfo = info;
          _isLoadingPackageInfo = false;
        });
        _entryAnimController.forward();
      }
    } catch (e) {
      print("Error fetching package info: $e");
      if (mounted) {
        setState(() {
          _isLoadingPackageInfo = false; // Still stop loading on error
          // _packageInfo remains with default 'Unknown' values
        });
        _entryAnimController.forward(); // Still animate other content
      }
    }
  }

  Future<void> _launchURL(String urlString, ThemeProvider themeProvider) async {
    HapticFeedback.lightImpact();
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Simplified check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Could not launch $urlString', style: GoogleFonts.inter()),
            backgroundColor: themeProvider.errorColor,
          ),
        );
      }
    }
  }

  void _showAppLicenses(BuildContext context) {
    HapticFeedback.lightImpact();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showLicensePage(
      context: context,
      applicationName: 'Gas2Door', // Use your app name
      applicationVersion:
          'Version ${_packageInfo.version} (Build ${_packageInfo.buildNumber})',
      applicationIcon: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset(
          'assets/images/gas2door_logo.png', // Ensure asset exists
          height: 40,
          errorBuilder: (context, error, stackTrace) => Icon(
              Icons.local_fire_department_rounded,
              size: 40,
              color: themeProvider.gas2doorPrimaryBlue),
        ),
      ),
      // applicationLegalese: '© ${DateTime.now().year} PrimeJetGas Ltd.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String appName = "Gas2Door";
    final String companyName = "PrimeJetGas Ltd";

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text(
          'About $appName',
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
      body: FadeTransition(
        opacity: _entryAnimController,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SlideTransition(
                position: _sectionSlideAnimations[0],
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/gas2door_logo.png',
                      height: 80,
                      errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.local_fire_department_rounded,
                          size: 80,
                          color: themeProvider.gas2doorPrimaryBlue),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      appName,
                      style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.primaryText),
                    ),
                    Text(
                      'powered by $companyName',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: themeProvider.secondaryText),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingPackageInfo)
                      const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Text(
                        'Version: ${_packageInfo.version} (Build ${_packageInfo.buildNumber})',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: themeProvider.tertiaryText),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Our Mission',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.primaryText),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$appName is a cooking gas delivery platform service. It enables customers to order cooking gas, track deliveries, communicate with drivers, provide feedback, manage profiles, and receive notifications. Drivers manage orders, share locations, and interact with customers, while admins oversee operations, orders, and users.',
                          textAlign: TextAlign.justify,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: themeProvider.secondaryText,
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SlideTransition(
                position: _sectionSlideAnimations[2],
                child: CustomCard(
                    color: themeProvider.cardBackground,
                    borderRadius: themeProvider.cardBorderRadiusValue,
                    child: Column(
                      children: [
                        _buildInfoListTile(
                          icon: Icons.article_outlined,
                          title: 'Terms of Service',
                          themeProvider: themeProvider,
                          onTap: () => _launchURL(
                              'https://example.com/terms', // Replace with your actual URL
                              themeProvider),
                        ),
                        _buildDivider(themeProvider),
                        _buildInfoListTile(
                          icon: Icons.shield_outlined,
                          title: 'Privacy Policy',
                          themeProvider: themeProvider,
                          onTap: () => _launchURL(
                              'https://example.com/privacy', // Replace with your actual URL
                              themeProvider),
                        ),
                        _buildDivider(themeProvider),
                        _buildInfoListTile(
                          icon: Icons.handshake_outlined,
                          title: 'Open Source Licenses',
                          themeProvider: themeProvider,
                          onTap: () => _showAppLicenses(context),
                        ),
                      ],
                    )),
              ),
              const SizedBox(height: 16),
              SlideTransition(
                position: _sectionSlideAnimations[3],
                child: CustomCard(
                  color: themeProvider.cardBackground,
                  borderRadius: themeProvider.cardBorderRadiusValue,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Us',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.primaryText),
                        ),
                        const SizedBox(height: 12),
                        _buildContactRow(Icons.email_outlined,
                            'support@gas2door.com', themeProvider,
                            onTap: () => _launchURL(
                                'mailto:primejetgas@gmail.com', themeProvider)),
                        const SizedBox(height: 8),
                        _buildContactRow(Icons.phone_outlined,
                            '+234 705 161 0832', themeProvider,
                            onTap: () => _launchURL(
                                'tel:+2347051610832', themeProvider)),
                        const SizedBox(height: 8),
                        _buildContactRow(Icons.language_rounded,
                            'www.gas2door.com', themeProvider,
                            onTap: () => _launchURL(
                                'https://www.gas2door.ng', themeProvider)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '© ${DateTime.now().year} $companyName. All Rights Reserved.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: themeProvider.tertiaryText),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoListTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    required ThemeProvider themeProvider,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: Icon(icon,
          color: themeProvider.secondaryText.withOpacity(0.8), size: 24),
      title: Text(title,
          style: GoogleFonts.inter(
              fontSize: 16,
              color: themeProvider.primaryText,
              fontWeight: FontWeight.w500)),
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
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildContactRow(
      IconData icon, String text, ThemeProvider themeProvider,
      {VoidCallback? onTap}) {
    Widget content = Row(
      children: [
        Icon(icon, color: themeProvider.secondaryText, size: 20),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 15, color: themeProvider.primaryText))),
      ],
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0), child: content),
      );
    }
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0), child: content);
  }
}
