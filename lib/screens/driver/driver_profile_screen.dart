// File: lib/screens/driver/driver_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For HapticFeedback

import '../../providers/theme_provider.dart';
import '../../widgets/card.dart';
import '../../widgets/button.dart';
import '../auth/driver_login_screen.dart'; // For logout navigation

// Mock DriverProfile Model
class DriverProfileDetails {
  final String id;
  final String name;
  final String? phoneNumber;
  final String? email; // Added email for completeness
  final String? vehicleModel;
  final String? licensePlate;
  final String? serviceZone;
  final String? photoUrl;

  DriverProfileDetails({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.email, // Added
    this.vehicleModel,
    this.licensePlate,
    this.serviceZone,
    this.photoUrl,
  });

  String get initials => name.isNotEmpty
      ? name.trim().split(' ').map((l) => l[0]).take(2).join().toUpperCase()
      : '?';
}

class DriverProfileScreen extends StatefulWidget {
  final String driverId;

  const DriverProfileScreen({
    super.key,
    required this.driverId,
  });

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen>
    with TickerProviderStateMixin {
  bool _isLoadingProfile = true;
  DriverProfileDetails? _driverProfile;
  String? _errorMessage;

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _sectionSlideAnimations;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _sectionSlideAnimations = List.generate(
      3, // Profile Header, Details Card, Logout Button
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(
              0.1 + (index * 0.1), 0.8 + (index * 0.08).clamp(0.0, 0.2),
              curve: Curves.easeOutCubic),
        ),
      ),
    );
    _fetchDriverProfile();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchDriverProfile({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true;
      if (isRefresh) _errorMessage = null;
    });

    // TODO: Replace with actual API call to fetch detailed driver profile for widget.driverId
    await Future.delayed(Duration(milliseconds: isRefresh ? 500 : 900));

    if (mounted) {
      setState(() {
        _driverProfile = DriverProfileDetails(
          id: widget.driverId,
          name: "Tunde Adebayo",
          phoneNumber: "+234 801 234 5678",
          email: "tunde.adebayo@driver.gas2door.com", // Added mock email
          vehicleModel: "Bajaj Boxer BM150",
          licensePlate: "LSR 123XY",
          serviceZone: "Lekki Phase 1 & VI",
          photoUrl:
              null, // 'https://i.pravatar.cc/150?u=${widget.driverId}' // Uncomment for mock image
        );
        _isLoadingProfile = false;
        _errorMessage = null;
      });
      _entryAnimController.forward(from: 0.0);
    }
    // catch (e) {
    //   if (mounted) {
    //     setState(() {
    //       _isLoadingProfile = false;
    //       _errorMessage = "Failed to load profile: ${e.toString()}";
    //     });
    //   }
    // }
  }

  Future<void> _handleLogout() async {
    HapticFeedback.mediumImpact();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final confirmLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: themeProvider.cardBackground,
          shape: RoundedRectangleBorder(
              borderRadius: themeProvider.cardBorderRadius),
          title: Text('Confirm Logout',
              style: GoogleFonts.inter(
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w600)),
          content: Text('Are you sure you want to log out?',
              style: GoogleFonts.inter(color: themeProvider.secondaryText)),
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
      // TODO: Implement actual logout logic (e.g., call AuthService.logoutDriver())
      await Future.delayed(
          const Duration(milliseconds: 300)); // Simulate logout
      _showFeedbackSnackbar('Logged out successfully.', context);
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          DriverLoginScreen.routeName, (route) => false);
    }
  }

  void _showFeedbackSnackbar(String message, BuildContext ctx,
      {bool isError = false}) {
    if (!mounted) return;
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
    final Color driverAccentColor = themeProvider.gas2doorTeal;

    return Scaffold(
      // Added Scaffold
      backgroundColor: themeProvider.appSecondaryBackground,
      body: RefreshIndicator(
        onRefresh: () => _fetchDriverProfile(isRefresh: true),
        color: driverAccentColor,
        backgroundColor: themeProvider.cardBackground,
        child: _isLoadingProfile
            ? Center(child: CircularProgressIndicator(color: driverAccentColor))
            : _errorMessage != null
                ? _buildErrorState(themeProvider, _errorMessage!)
                : _driverProfile == null
                    ? _buildEmptyState(
                        themeProvider, "Driver profile data not found.")
                    : FadeTransition(
                        opacity: _entryAnimController,
                        child: ListView(
                          // Changed to ListView for scrollability of profile sections
                          padding: const EdgeInsets.all(16.0),
                          children: [
                            SlideTransition(
                                position: _sectionSlideAnimations[0],
                                child: _buildProfileHeader(
                                    _driverProfile!, themeProvider)),
                            const SizedBox(height: 20),
                            SlideTransition(
                                position: _sectionSlideAnimations[1],
                                child: _buildProfileDetailsCard(
                                    _driverProfile!, themeProvider)),
                            const SizedBox(height: 28),
                            SlideTransition(
                              position: _sectionSlideAnimations[2],
                              child: CustomButton(
                                // Standardized Logout Button
                                text: 'Logout',
                                onPressed: _handleLogout,
                                color: themeProvider.errorColor.withOpacity(
                                    themeProvider.isDarkMode ? 0.3 : 0.15),
                                textStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: themeProvider.errorColor),
                                icon: Icon(Icons.logout_rounded,
                                    color: themeProvider.errorColor, size: 20),
                                height: 50,
                                borderRadius:
                                    themeProvider.cardBorderRadiusValue,
                                elevation: 0, // Flat style for logout
                              ),
                            ),
                            const SizedBox(height: 24),
                            Center(
                                child: Text('App Version 1.0.0 (Build 1)',
                                    style: GoogleFonts.inter(
                                        color: themeProvider.tertiaryText,
                                        fontSize: 12))),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildProfileHeader(
      DriverProfileDetails driver, ThemeProvider themeProvider) {
    final Color driverPrimaryColor =
        themeProvider.gas2doorTeal; // Driver specific accent
    return CustomCard(
      // Standardized Card
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 2.0,
      shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50, // Consistent avatar size
              backgroundColor:
                  driverPrimaryColor.withOpacity(0.15), // Themed background
              backgroundImage:
                  driver.photoUrl != null && driver.photoUrl!.isNotEmpty
                      ? NetworkImage(driver.photoUrl!)
                      : null,
              child: (driver.photoUrl == null || driver.photoUrl!.isEmpty)
                  ? Text(driver.initials,
                      style: GoogleFonts.inter(
                          // Consistent Typography
                          fontSize: 38, // Adjusted size
                          color:
                              driverPrimaryColor, // Use accent color for initials
                          fontWeight: FontWeight.w500))
                  : null,
            ),
            const SizedBox(height: 16),
            Text(driver.name,
                style: GoogleFonts.inter(
                    // Consistent Typography
                    fontSize: 22, // Prominent name
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            if (driver.email != null)
              Text(driver.email!,
                  style: GoogleFonts.inter(
                      fontSize: 14.5,
                      color: themeProvider.secondaryText)), // Adjusted size
            if (driver.phoneNumber != null) ...[
              if (driver.email != null)
                const SizedBox(height: 4), // Space if email is also present
              Text(driver.phoneNumber!,
                  style: GoogleFonts.inter(
                      fontSize: 14.5,
                      color: themeProvider.secondaryText)), // Adjusted size
            ],
            const SizedBox(height: 16),
            // Placeholder for "Edit Profile" if needed in future
            // CustomButton(
            //   text: "Edit Profile Details",
            //   onPressed: () { /* TODO: Navigate to edit driver profile screen */},
            //   color: driverPrimaryColor.withOpacity(0.1),
            //   textStyle: GoogleFonts.inter(color: driverPrimaryColor, fontWeight: FontWeight.w600, fontSize: 13),
            //   icon: Icon(Icons.edit_outlined, color: driverPrimaryColor, size: 16),
            //   height: 38,
            //   elevation: 0,
            // )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetailsCard(
      DriverProfileDetails driver, ThemeProvider themeProvider) {
    return CustomCard(
        // Standardized Card
        color: themeProvider.cardBackground,
        borderRadius: themeProvider.cardBorderRadiusValue,
        elevation: 2.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Vehicle & Service Info",
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryText)),
              Divider(
                  height: 20,
                  thickness: 0.5,
                  color: themeProvider.tertiaryText
                      .withOpacity(0.2)), // Subtle divider
              if (driver.vehicleModel != null &&
                  driver.vehicleModel!.isNotEmpty)
                _buildDetailRow(Icons.two_wheeler_outlined, "Vehicle Model",
                    driver.vehicleModel!, themeProvider),
              if (driver.licensePlate != null &&
                  driver.licensePlate!.isNotEmpty)
                _buildDetailRow(Icons.pin_outlined, "License Plate",
                    driver.licensePlate!, themeProvider),
              if (driver.serviceZone != null && driver.serviceZone!.isNotEmpty)
                _buildDetailRow(Icons.map_outlined, "Service Zone(s)",
                    driver.serviceZone!, themeProvider),
              if (driver.vehicleModel == null &&
                  driver.licensePlate == null &&
                  driver.serviceZone == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                      "No vehicle or service zone information available.",
                      style: GoogleFonts.inter(
                          color: themeProvider.secondaryText,
                          fontStyle: FontStyle.italic)),
                )
            ],
          ),
        ));
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Increased padding
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Align icon with first line of text
        children: [
          Icon(icon,
              color: themeProvider.secondaryText.withOpacity(0.8),
              size: 20), // Adjusted size
          const SizedBox(width: 12), // Consistent spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 13.5,
                        color: themeProvider.tertiaryText,
                        fontWeight: FontWeight.w500)), // Label smaller
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color:
                            themeProvider.primaryText)), // Value more prominent
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      // Added SingleChildScrollView for shimmer
      padding: const EdgeInsets.all(16.0),
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
                      backgroundColor: themeProvider.shimmerBaseColor),
                  const SizedBox(height: 16),
                  Container(
                      width: 150,
                      height: 22,
                      color: themeProvider.shimmerBaseColor,
                      margin: const EdgeInsets.only(bottom: 8)),
                  Container(
                      width: 200,
                      height: 16,
                      color: themeProvider.shimmerBaseColor,
                      margin: const EdgeInsets.only(bottom: 6)),
                  Container(
                      width: 180,
                      height: 16,
                      color: themeProvider.shimmerBaseColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          CustomCard(
            color: themeProvider.cardBackground,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 120,
                      height: 18,
                      color: themeProvider.shimmerBaseColor,
                      margin: const EdgeInsets.only(bottom: 16)),
                  Container(
                      width: double.infinity,
                      height: 16,
                      color: themeProvider.shimmerBaseColor,
                      margin: const EdgeInsets.only(bottom: 12)),
                  Container(
                      width: double.infinity,
                      height: 16,
                      color: themeProvider.shimmerBaseColor,
                      margin: const EdgeInsets.only(bottom: 12)),
                  Container(
                      width: double.infinity,
                      height: 16,
                      color: themeProvider.shimmerBaseColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined,
                color: themeProvider.errorColor, size: 50), // Adjusted size
            const SizedBox(height: 16),
            Text('Error Loading Profile',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 17)), // Adjusted size
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                  color: themeProvider.secondaryText,
                  fontSize: 14), // Adjusted size
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CustomButton(
              // Standardized Button
              text: "Retry",
              onPressed: () => _fetchDriverProfile(isRefresh: true),
              color:
                  themeProvider.gas2doorPrimaryBlue, // Consistent action color
              textStyle: GoogleFonts.inter(
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white,
                  fontWeight: FontWeight.w600),
              icon: Icon(Icons.refresh_rounded,
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white),
              height: 48, // Consistent height
              borderRadius: themeProvider.cardBorderRadiusValue,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_outlined,
                color: themeProvider.secondaryText.withOpacity(0.5),
                size: 60), // Adjusted size
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 17, // Adjusted size
                  fontWeight: FontWeight.w500,
                  color: themeProvider.primaryText),
            ),
            const SizedBox(height: 10),
            Text(
              'If this issue persists, please contact support.', // More helpful message
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: themeProvider.secondaryText
                      .withOpacity(0.9)), // Adjusted size
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: "Refresh",
              onPressed: () => _fetchDriverProfile(isRefresh: true),
              color: themeProvider.gas2doorPrimaryBlue,
              icon: Icon(Icons.refresh_rounded,
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white),
            )
          ],
        ),
      ),
    );
  }
}
