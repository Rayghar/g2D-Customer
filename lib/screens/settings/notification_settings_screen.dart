// File: lib/screens/settings/notification_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'dart:async';

import '../../providers/theme_provider.dart';
import '../../widgets/card.dart'; // Your CustomCard
import '../../widgets/button.dart'; // Import CustomButton
import '../../services/api_service.dart'; // Import ApiService for API calls
import '../../providers/auth_provider.dart'; // Import AuthProvider to get current user
import '../../models/user.dart'; // Import User model
import '../../models/notification_preferences_model.dart'; // Import the correct NotificationPreferencesModel

// The placeholder UserNotificationPreferences class is replaced by NotificationPreferencesModel
// from 'package:your_app/models/notification_preferences_model.dart'

class NotificationSettingsScreen extends StatefulWidget {
  static const String routeName = '/notification_settings';
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  // Use the actual NotificationPreferencesModel from your models folder
  NotificationPreferencesModel _preferences =
      NotificationPreferencesModel(orderUpdates: true, promotions: true);
  String? _errorMessage;

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _tileSlideAnimations;

  final ApiService _apiService = ApiService(); // Instantiate ApiService

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _tileSlideAnimations = List.generate(
      4, // Number of SwitchListTiles + note
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(
              0.1 + (index * 0.1), 0.7 + (index * 0.1).clamp(0.0, 0.3),
              curve: Curves.easeOutCubic),
        ),
      ),
    );
    _loadPreferences();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        throw Exception("User not authenticated.");
      }

      // Fetch the full user profile, which includes notification preferences
      final User userProfile = await _apiService.getMyProfile(); //

      if (mounted) {
        setState(() {
          // Update preferences from fetched user profile
          _preferences = userProfile.notificationPreferences; //
          _isLoading = false;
          _errorMessage = null;
        });
        _entryAnimController.forward();
      }
    } catch (e) {
      if (mounted) {
        _errorMessage =
            "Failed to load settings: ${e.toString().replaceFirst("Exception: ", "")}";
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updatePreference(String key, bool value) async {
    HapticFeedback.lightImpact();

    // Create a mutable copy of current preferences to modify
    NotificationPreferencesModel updatedPreferences =
        NotificationPreferencesModel(
      orderUpdates: _preferences.orderUpdates,
      promotions: _preferences.promotions,
      // Assuming these are the only two mutable preferences as per user.model.js
      // If 'allowAppUpdates' or 'allowChatMessages' are truly in your backend model,
      // they need to be added to NotificationPreferencesModel in lib/models/notification_preferences_model.dart
      // and handled here. For now, I'm aligning with the provided user.model.js's notificationPreferences.
    );

    switch (key) {
      case 'orderUpdates':
        updatedPreferences = NotificationPreferencesModel(
          orderUpdates: value,
          promotions: updatedPreferences.promotions,
        );
        break;
      case 'promotions':
        updatedPreferences = NotificationPreferencesModel(
          orderUpdates: updatedPreferences.orderUpdates,
          promotions: value,
        );
        break;
      // If you have 'allowAppUpdates' or 'allowChatMessages' in your backend user model,
      // they would be handled here, e.g.:
      // case 'appUpdates':
      //   updatedPreferences = NotificationPreferencesModel(
      //     orderUpdates: updatedPreferences.orderUpdates,
      //     promotions: updatedPreferences.promotions,
      //     allowAppUpdates: value,
      //     allowChatMessages: updatedPreferences.allowChatMessages,
      //   );
      //   break;
      // case 'chatMessages':
      //   updatedPreferences = NotificationPreferencesModel(
      //     orderUpdates: updatedPreferences.orderUpdates,
      //     promotions: updatedPreferences.promotions,
      //     allowAppUpdates: updatedPreferences.allowAppUpdates,
      //     allowChatMessages: value,
      //   );
      //   break;
    }

    // Optimistically update UI
    setState(() {
      _preferences = updatedPreferences;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
        throw Exception("User not authenticated for update.");
      }

      // Prepare payload for API call
      final Map<String, dynamic> updatePayload = {
        'notificationPreferences':
            updatedPreferences.toJson(), // Convert preferences to JSON
      };

      // FIX: Changed updateUserProfile to updateProfile to match ApiService method name
      await _apiService.updateProfile(updatePayload); //

      authProvider.updateCurrentUserProfile(
        authProvider.currentUser!.copyWith(
          notificationPreferences: updatedPreferences,
        ),
      );

      _showFeedbackSnackbar('Settings saved.', context);
    } catch (e) {
      _showFeedbackSnackbar(
          'Failed to save settings: ${e.toString().replaceFirst("Exception: ", "")}',
          context,
          isError: true);
      // Revert UI state if API call fails
      if (mounted) {
        setState(() {
          // Revert to previous state or re-fetch to ensure consistency
          _loadPreferences();
        });
      }
    }
  }

  void _showFeedbackSnackbar(String message, BuildContext ctx,
      {bool isError = false}) {
    final themeProvider = Provider.of<ThemeProvider>(ctx, listen: false);
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
          'Notification Settings',
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
          : _errorMessage != null
              ? _buildErrorState(themeProvider)
              : FadeTransition(
                  opacity: _entryAnimController,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: <Widget>[
                      SlideTransition(
                        position: _tileSlideAnimations[0],
                        child: _buildSettingsGroupCard(
                          themeProvider,
                          title: "Order Notifications",
                          children: [
                            _buildPreferenceSwitch(
                              themeProvider: themeProvider,
                              title: 'Order Status Updates',
                              subtitle:
                                  'Receive real-time updates about your orders (confirmed, shipped, delivered).',
                              icon: Icons.local_shipping_outlined,
                              currentValue: _preferences
                                  .orderUpdates, // Use correct field
                              onChanged: (value) =>
                                  _updatePreference('orderUpdates', value),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SlideTransition(
                        position: _tileSlideAnimations[1],
                        child: _buildSettingsGroupCard(
                          themeProvider,
                          title: "Marketing & App Updates",
                          children: [
                            _buildPreferenceSwitch(
                              themeProvider: themeProvider,
                              title: 'Promotions & Special Offers',
                              subtitle:
                                  'Get notified about the latest deals and discounts.',
                              icon: Icons.campaign_outlined,
                              currentValue:
                                  _preferences.promotions, // Use correct field
                              onChanged: (value) =>
                                  _updatePreference('promotions', value),
                            ),
                            _buildDivider(themeProvider),
                            // Note: The following are commented out because your backend user.model.js
                            // does not currently contain 'allowAppUpdates' or 'allowChatMessages'.
                            // If your backend model supports them, uncomment these and update
                            // NotificationPreferencesModel accordingly.
                            // _buildPreferenceSwitch(
                            //   themeProvider: themeProvider,
                            //   title: 'App Updates & News',
                            //   subtitle:
                            //       'Stay informed about new features and important announcements.',
                            //   icon: Icons.info_outline_rounded,
                            //   currentValue: _preferences.allowAppUpdates,
                            //   onChanged: (value) =>
                            //       _updatePreference('appUpdates', value),
                            // ),
                            // _buildDivider(themeProvider),
                            // _buildPreferenceSwitch(
                            //   themeProvider: themeProvider,
                            //   title: 'New Chat Messages',
                            //   subtitle:
                            //       'Get notified when you receive a new chat message from a driver.',
                            //   icon: Icons.chat_bubble_outline_rounded,
                            //   currentValue: _preferences.allowChatMessages,
                            //   onChanged: (value) =>
                            //       _updatePreference('chatMessages', value),
                            // ),
                          ],
                        ),
                      ),
                      const SizedBox(
                          height:
                              24), // Adjust spacing if app updates/chat are removed
                      SlideTransition(
                        position: _tileSlideAnimations[
                            3], // Adjusted index as some switches might be removed
                        child: Text(
                          "Note: Critical account alerts and security notifications cannot be disabled.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: themeProvider.tertiaryText,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSettingsGroupCard(ThemeProvider themeProvider,
      {required String title, required List<Widget> children}) {
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 1.5,
      shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.secondaryText,
                  letterSpacing: 0.8),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPreferenceSwitch({
    required ThemeProvider themeProvider,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool currentValue,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      title: Text(title,
          style: GoogleFonts.inter(
              fontSize: 16,
              color: themeProvider.primaryText,
              fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: GoogleFonts.inter(
              fontSize: 13, color: themeProvider.tertiaryText, height: 1.3)),
      secondary: Icon(icon,
          color: themeProvider.secondaryText.withOpacity(0.8), size: 26),
      value: currentValue,
      onChanged: onChanged,
      activeColor: themeProvider.gas2doorTeal,
      inactiveTrackColor: themeProvider.tertiaryText.withOpacity(0.3),
    );
  }

  Widget _buildDivider(ThemeProvider themeProvider) {
    return Divider(
      height: 0.5,
      thickness: 0.3,
      color: themeProvider.tertiaryText.withOpacity(0.2),
      indent: 72, // Align with text after icon and padding
      endIndent: 16,
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_suggest_outlined,
                color: themeProvider.secondaryText.withOpacity(0.7), size: 60),
            const SizedBox(height: 20),
            Text('Could Not Load Settings',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Please check your connection and try again.',
              style: GoogleFonts.inter(
                  color: themeProvider.secondaryText, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: "Retry",
              onPressed: _loadPreferences,
              color: themeProvider.gas2doorPrimaryBlue,
              icon: Icon(Icons.refresh_rounded,
                  color: themeProvider.infoColorOnDarkBgs),
            )
          ],
        ),
      ),
    );
  }
}
