// File: lib/screens/customer/profile_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './address_list_screen.dart';
import '../settings/notification_settings_screen.dart';
import '../settings/payment_methods_screen.dart';
import '../more/refer_friend_screen.dart'; // This is where the customer goes
import '../more/help_support_screen.dart';
import '../more/about_us_screen.dart';
import '../auth/customer_login_screen.dart';
import './profile/wallet_screen.dart';
import './profile/edit_profile_screen.dart';

// --- Services and Models ---
import '../../services/auth_service.dart';
import '../../models/user.dart' as app_user; // Use the real User model

class ProfileScreen extends StatefulWidget {
  static const String routeName = '/profile';
  final GlobalKey<NavigatorState> navigatorKey;
  final String customerId;
  const ProfileScreen(
      {super.key, required this.navigatorKey, required this.customerId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  bool _isLoadingProfile = true;
  app_user.User? _userData; // Use the real User model
  String? _errorMessage;
  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _tileSlideAnimations;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _tileSlideAnimations = List.generate(
        7,
        (index) => Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _entryAnimController,
                curve: Interval(
                    0.1 + (index * 0.08), 0.9 + (index * 0.05).clamp(0.0, 0.1),
                    curve: Curves.easeOutCubic))));
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  // FIX: This now fetches data from the real AuthService
  Future<void> _fetchUserProfile({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true;
      if (isRefresh) _errorMessage = null;
    });
    try {
      // Calls the real service to get the logged-in user's profile
      final profile = await _authService.getCurrentUserProfile();
      if (mounted) {
        if (profile != null) {
          setState(() {
            _userData = profile;
            _isLoadingProfile = false;
            _errorMessage = null;
          });
          _entryAnimController.forward(from: 0.0);
        } else {
          throw Exception(
              "Could not retrieve user profile. Please log in again.");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _errorMessage =
              "Failed to load profile. ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  // FIX: This now calls the real AuthService logout
  Future<void> _handleLogout() async {
    HapticFeedback.mediumImpact();
    final confirmLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final themeProvider =
            Provider.of<ThemeProvider>(dialogContext, listen: false);
        return AlertDialog(
          backgroundColor: themeProvider.cardBackground,
          shape: RoundedRectangleBorder(
              borderRadius: themeProvider.cardBorderRadius),
          title: Text('Confirm Logout',
              style: GoogleFonts.inter(
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 18)),
          content: Text('Are you sure you want to log out?',
              style: GoogleFonts.inter(
                  color: themeProvider.secondaryText, fontSize: 15)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('Cancel',
                    style: GoogleFonts.inter(
                        color: themeProvider.secondaryText,
                        fontWeight: FontWeight.w500))),
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('Logout',
                    style: GoogleFonts.inter(
                        color: themeProvider.errorColor,
                        fontWeight: FontWeight.bold))),
          ],
        );
      },
    );

    if (confirmLogout == true && mounted) {
      await _authService.logout(); // Use real logout service
      _showFeedbackSnackbar('Logged out successfully.');
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          CustomerLoginScreen.routeName, (route) => false);
    }
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
        title: Text("My Profile",
            style: GoogleFonts.inter(
                color: themeProvider.primaryText, fontWeight: FontWeight.w600)),
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchUserProfile(isRefresh: true),
        color: themeProvider.gas2doorPrimaryBlue,
        backgroundColor: themeProvider.cardBackground,
        child: _isLoadingProfile
            ? _buildLoadingState(themeProvider)
            : _userData == null || _errorMessage != null
                ? _buildErrorState(themeProvider)
                : FadeTransition(
                    opacity: _entryAnimController,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SlideTransition(
                              position: _tileSlideAnimations[0],
                              child: _buildProfileHeader(
                                  _userData!, themeProvider, context)),
                          const SizedBox(height: 20),
                          SlideTransition(
                              position: _tileSlideAnimations[1],
                              child: _buildSectionCard(
                                  title: 'Account Information',
                                  themeProvider: themeProvider,
                                  children: [
                                    _buildProfileListTile(
                                        icon: Icons.edit_outlined,
                                        title: 'Edit My Profile',
                                        themeProvider: themeProvider,
                                        onTap: () {
                                          if (widget.customerId.isNotEmpty) {
                                            Navigator.of(context).pushNamed(
                                                EditProfileScreen.routeName,
                                                arguments: {
                                                  'customerId':
                                                      widget.customerId
                                                });
                                          }
                                        }),
                                    _buildProfileListTile(
                                        icon: Icons.home_work_outlined,
                                        title: 'My Delivery Addresses',
                                        themeProvider: themeProvider,
                                        onTap: () => Navigator.of(context)
                                                .pushNamed(
                                                    AddressListScreen.routeName,
                                                    arguments: {
                                                  'customerId':
                                                      widget.customerId
                                                })),
                                    _buildProfileListTile(
                                        icon: Icons
                                            .account_balance_wallet_outlined,
                                        title: 'My Wallet',
                                        subtitle:
                                            '₦${NumberFormat("#,##0.00").format(_userData!.walletBalance)}',
                                        themeProvider: themeProvider,
                                        onTap: () {
                                          if (widget.customerId.isNotEmpty) {
                                            Navigator.of(context).pushNamed(
                                                WalletScreen.routeName,
                                                arguments: {
                                                  'customerId':
                                                      widget.customerId
                                                });
                                          }
                                        }),
                                    _buildProfileListTile(
                                        icon: Icons.credit_card_outlined,
                                        title: 'Payment Methods',
                                        themeProvider: themeProvider,
                                        onTap: () => Navigator.of(context)
                                            .pushNamed(PaymentMethodsScreen
                                                .routeName)),
                                  ])),
                          const SizedBox(height: 16),
                          SlideTransition(
                              position: _tileSlideAnimations[2],
                              child: _buildSectionCard(
                                  title: 'App Settings',
                                  themeProvider: themeProvider,
                                  children: [
                                    SwitchListTile.adaptive(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 6),
                                      secondary: Icon(
                                          themeProvider.isDarkMode
                                              ? Icons.nightlight_round
                                              : Icons.wb_sunny_outlined,
                                          color: themeProvider.secondaryText,
                                          size: 24),
                                      title: Text('Dark Mode',
                                          style: GoogleFonts.inter(
                                              color: themeProvider.primaryText,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500)),
                                      value: themeProvider.isDarkMode,
                                      onChanged: (value) {
                                        HapticFeedback.lightImpact();
                                        themeProvider.toggleTheme();
                                      },
                                      activeColor: themeProvider.gas2doorTeal,
                                    ),
                                    _buildProfileListTile(
                                        icon:
                                            Icons.notifications_active_outlined,
                                        title: 'Notification Preferences',
                                        themeProvider: themeProvider,
                                        onTap: () => Navigator.of(context)
                                            .pushNamed(
                                                NotificationSettingsScreen
                                                    .routeName)),
                                  ])),
                          const SizedBox(height: 16),
                          SlideTransition(
                              position: _tileSlideAnimations[3],
                              child: _buildSectionCard(
                                  title: 'More',
                                  themeProvider: themeProvider,
                                  children: [
                                    _buildProfileListTile(
                                        icon: Icons.share_outlined,
                                        title: 'Refer a Friend & Earn',
                                        themeProvider: themeProvider,
                                        onTap: () {
                                          if (widget.customerId.isNotEmpty) {
                                            Navigator.of(context).pushNamed(
                                              ReferFriendScreen.routeName,
                                              arguments: {
                                                'customerId': widget.customerId
                                              },
                                            );
                                          }
                                        }),
                                    _buildProfileListTile(
                                        icon: Icons.help_outline_rounded,
                                        title: 'Help & Support',
                                        themeProvider: themeProvider,
                                        onTap: () => Navigator.of(context)
                                            .pushNamed(
                                                HelpSupportScreen.routeName)),
                                    _buildProfileListTile(
                                        icon: Icons.info_outline_rounded,
                                        title: 'About Gas2Door',
                                        themeProvider: themeProvider,
                                        onTap: () => Navigator.of(context)
                                            .pushNamed(
                                                AboutUsScreen.routeName)),
                                  ])),
                          const SizedBox(height: 28),
                          SlideTransition(
                              position: _tileSlideAnimations[4],
                              child: CustomButton(
                                text: 'Logout',
                                onPressed: _handleLogout,
                                color: themeProvider.isDarkMode
                                    ? themeProvider.errorColor.withOpacity(0.3)
                                    : themeProvider.errorColor
                                        .withOpacity(0.15),
                                textStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: themeProvider.errorColor),
                                icon: Icon(Icons.logout_rounded,
                                    color: themeProvider.errorColor, size: 20),
                                height: 50,
                                borderRadius:
                                    themeProvider.cardBorderRadiusValue,
                                elevation: 0,
                              )),
                          const SizedBox(height: 24),
                          SlideTransition(
                              position: _tileSlideAnimations[5],
                              child: Center(
                                  child: Text('App Version 1.0.0 (Build 1)',
                                      style: GoogleFonts.inter(
                                          color: themeProvider.tertiaryText,
                                          fontSize: 12)))),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  // FIX: This widget now uses the real app_user.User model
  Widget _buildProfileHeader(
      app_user.User user, ThemeProvider themeProvider, BuildContext context) {
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 2,
      shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            CircleAvatar(
                radius: 50,
                backgroundColor:
                    themeProvider.gas2doorPrimaryBlueLightVer.withOpacity(0.8),
                child: Text(
                    user.name.isNotEmpty
                        ? user.name.substring(0, 1).toUpperCase()
                        : 'U',
                    style: GoogleFonts.inter(
                        fontSize: 40,
                        color: themeProvider.infoColorOnDarkBgs,
                        fontWeight: FontWeight.w500))),
            const SizedBox(height: 16),
            Text(user.name,
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(user.email,
                style: GoogleFonts.inter(
                    fontSize: 15, color: themeProvider.secondaryText)),
            const SizedBox(height: 4),
            Text(user.phone ?? 'No phone number provided',
                style: GoogleFonts.inter(
                    fontSize: 15, color: themeProvider.secondaryText)),
            const SizedBox(height: 12),
            CustomButton(
              text: "Edit Profile",
              onPressed: () {
                if (widget.customerId.isNotEmpty) {
                  Navigator.of(context).pushNamed(EditProfileScreen.routeName,
                      arguments: {'customerId': widget.customerId});
                }
              },
              color: themeProvider.appSecondaryBackground,
              height: 38,
              elevation: 0,
              textStyle: GoogleFonts.inter(
                  color: themeProvider.gas2doorPrimaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
              icon: Icon(Icons.edit_outlined,
                  color: themeProvider.gas2doorPrimaryBlue, size: 16),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title,
      required List<Widget> children,
      required ThemeProvider themeProvider}) {
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 1.5,
      shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(title.toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.secondaryText,
                      letterSpacing: 0.8))),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            itemBuilder: (context, index) => children[index],
            separatorBuilder: (context, index) => Divider(
                height: 0.5,
                thickness: 0.3,
                color: themeProvider.tertiaryText.withOpacity(0.2),
                indent: 16,
                endIndent: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileListTile(
      {required IconData icon,
      required String title,
      String? subtitle,
      VoidCallback? onTap,
      Widget? trailing,
      required ThemeProvider themeProvider}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: themeProvider.secondaryText, size: 24),
      title: Text(title,
          style: GoogleFonts.inter(
              fontSize: 16,
              color: themeProvider.primaryText,
              fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: GoogleFonts.inter(
                  fontSize: 13, color: themeProvider.tertiaryText))
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: themeProvider.tertiaryText)
              : null),
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap();
            }
          : null,
      shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(themeProvider.cardBorderRadiusValue / 2)),
      hoverColor: themeProvider.gas2doorPrimaryBlue.withOpacity(0.04),
      splashColor: themeProvider.gas2doorTeal.withOpacity(0.08),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined,
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Could Not Load Profile',
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
                onPressed: _fetchUserProfile,
                color: themeProvider.gas2doorPrimaryBlue,
                icon: Icon(Icons.refresh_rounded,
                    color: themeProvider.infoColorOnDarkBgs)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          CustomCard(
            color: themeProvider.cardBackground,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  CircleAvatar(
                      radius: 50,
                      backgroundColor: themeProvider.appSecondaryBackground),
                  const SizedBox(height: 16),
                  _buildSkeletonLine(
                      width: 150, height: 22, themeProvider: themeProvider),
                  const SizedBox(height: 8),
                  _buildSkeletonLine(
                      width: 200, height: 16, themeProvider: themeProvider),
                  const SizedBox(height: 6),
                  _buildSkeletonLine(
                      width: 180, height: 16, themeProvider: themeProvider),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSkeletonSectionCard(themeProvider),
          const SizedBox(height: 16),
          _buildSkeletonSectionCard(themeProvider),
        ],
      ),
    );
  }

  Widget _buildSkeletonLine(
      {required double width,
      required double height,
      required ThemeProvider themeProvider,
      double borderRadius = 4}) {
    return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? Colors.grey[700]!.withOpacity(0.6)
                : Colors.grey[300]!,
            borderRadius: BorderRadius.circular(borderRadius)));
  }

  Widget _buildSkeletonSectionCard(ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSkeletonLine(
                width: 120, height: 14, themeProvider: themeProvider),
            const SizedBox(height: 16),
            _buildSkeletonLine(
                width: double.infinity,
                height: 40,
                themeProvider: themeProvider),
            const SizedBox(height: 12),
            _buildSkeletonLine(
                width: double.infinity,
                height: 40,
                themeProvider: themeProvider),
          ],
        ),
      ),
    );
  }
}
