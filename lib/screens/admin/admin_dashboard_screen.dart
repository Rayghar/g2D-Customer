// File: lib/screens/admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart'; // Import ApiService
import '../../models/user.dart' as app_user;
import '../../models/admin/dashboard_stats_model.dart'; // Import the new model
import '../auth/admin_login_screen.dart';

// Import all management screen routes
import './admin_order_list_screen.dart';
import './admin_customer_list_screen.dart';
import './admin_driver_list_screen.dart';
import './admin_promotions_management_screen.dart';
import './admin_faq_management_screen.dart';
import './admin_system_config_screen.dart';
import './admin_reports_screen.dart';
import './admin_run_management_screen.dart';
import './admin_add_edit_user_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  static const String routeName = '/admin_dashboard';
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  app_user.User? _adminProfile;
  DashboardStatsModel _dashboardStats = DashboardStatsModel();
  String? _errorMessage;

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _tileSlideAnimations;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _tileSlideAnimations = List.generate(
      7,
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(
              0.1 + (index * 0.08), 0.7 + (index * 0.08).clamp(0.0, 0.3),
              curve: Curves.easeOutCubic),
        ),
      ),
    );
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  /// Fetches all necessary data for the dashboard from the backend.
  Future<void> _fetchDashboardData({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Fetch profile and stats in parallel for better performance
      final results = await Future.wait([
        _apiService.getMyProfile(),
        _apiService.getAdminDashboardStats(),
      ]);

      if (mounted) {
        setState(() {
          _adminProfile = results[0] as app_user.User;
          _dashboardStats = results[1] as DashboardStatsModel;
          _isLoading = false;
          _errorMessage = null;
        });
        _entryAnimController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              "Failed to load dashboard: ${e.toString().replaceFirst("Exception: ", "")}";
          _isLoading = false;
        });
      }
    }
  }

  /// Handles admin logout.
  Future<void> _handleLogout() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      await _authService.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AdminLoginScreen.routeName,
            (Route<dynamic> route) => false);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar('Logout failed: ${e.toString()}', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToManagementScreen(String routeName, String featureName) {
    HapticFeedback.lightImpact();
    if (ModalRoute.of(context)?.settings.name != routeName) {
      if (Navigator.canPop(context) &&
          routeName == AdminLoginScreen.routeName) {
        Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
      } else {
        Navigator.pushNamed(context, routeName);
      }
    } else {
      _showFeedbackSnackbar("Already on $featureName screen.", isError: true);
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
    final String appLogoPath = 'assets/images/gas2door_logo.png';
    final Color adminAccentColor = themeProvider.gas2doorPurple;

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(appLogoPath,
                height: 28,
                color: adminAccentColor,
                errorBuilder: (ctx, err, st) => Icon(
                    Icons.admin_panel_settings_rounded,
                    color: adminAccentColor,
                    size: 28)),
            const SizedBox(width: 10),
            Text(
              'Admin Dashboard',
              style: GoogleFonts.inter(
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 18),
            ),
          ],
        ),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: Icon(Icons.logout_rounded,
                      color: themeProvider.secondaryText),
                  onPressed: _handleLogout,
                  tooltip: "Logout",
                ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchDashboardData(isRefresh: true),
        color: adminAccentColor,
        backgroundColor: themeProvider.cardBackground,
        child: _isLoading && _adminProfile == null
            ? Center(child: CircularProgressIndicator(color: adminAccentColor))
            : _errorMessage != null
                ? _buildErrorState(themeProvider)
                : FadeTransition(
                    opacity: _entryAnimController,
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: <Widget>[
                        SlideTransition(
                          position: _tileSlideAnimations[0],
                          child: Text(
                            'Welcome, ${_adminProfile?.name ?? "Admin"}!',
                            style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.primaryText),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SlideTransition(
                          position: _tileSlideAnimations[1],
                          child: Text(
                            'Oversee and manage platform operations.',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                color: themeProvider.secondaryText),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SlideTransition(
                            position: _tileSlideAnimations[2],
                            child: _buildStatsGrid(themeProvider)),
                        const SizedBox(height: 24),
                        SlideTransition(
                            position: _tileSlideAnimations[3],
                            child: _buildManagementSectionTitle(
                                "Core Management", themeProvider)),
                        SlideTransition(
                          position: _tileSlideAnimations[4],
                          child: _buildManagementTile(
                              Icons.list_alt_rounded,
                              "Manage Orders",
                              "View, filter, and update order statuses.",
                              themeProvider,
                              () => _navigateToManagementScreen(
                                  AdminOrderListScreen.routeName, "Order")),
                        ),
                        SlideTransition(
                            position: _tileSlideAnimations[5],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildManagementTile(
                                    Icons.people_outline_rounded,
                                    "Manage Customers",
                                    "View and manage customer accounts.",
                                    themeProvider,
                                    () => _navigateToManagementScreen(
                                        AdminCustomerListScreen.routeName,
                                        "Customer User")),
                                _buildManagementTile(
                                    Icons.directions_car_filled_outlined,
                                    "Manage Drivers",
                                    "View driver applications, manage profiles and availability.",
                                    themeProvider,
                                    () => _navigateToManagementScreen(
                                        AdminDriverListScreen.routeName,
                                        "Driver User")),
                                _buildManagementTile(
                                    Icons.person_add_alt_1_rounded,
                                    "Add New User/Staff",
                                    "Create new admin or driver accounts.",
                                    themeProvider,
                                    () => _navigateToManagementScreen(
                                        AdminAddEditUserScreen.routeName,
                                        "Add User/Staff")),
                              ],
                            )),
                        SlideTransition(
                          position: _tileSlideAnimations[6],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildManagementSectionTitle(
                                  "Platform Settings & Content", themeProvider),
                              _buildManagementTile(
                                  Icons.campaign_rounded,
                                  "Manage Promotions",
                                  "Create and manage promotional offers.",
                                  themeProvider,
                                  () => _navigateToManagementScreen(
                                      AdminPromotionManagementScreen.routeName,
                                      "Promotions")),
                              _buildManagementTile(
                                  Icons.quiz_outlined,
                                  "Manage FAQs",
                                  "Edit and update Frequently Asked Questions.",
                                  themeProvider,
                                  () => _navigateToManagementScreen(
                                      AdminFaqManagementScreen.routeName,
                                      "FAQs")),
                              _buildManagementTile(
                                  Icons.settings_applications_outlined,
                                  "System Configuration",
                                  "Adjust platform-wide settings and parameters.",
                                  themeProvider,
                                  () => _navigateToManagementScreen(
                                      AdminSystemConfigScreen.routeName,
                                      "System Config")),
                              _buildManagementTile(
                                  Icons.analytics_outlined,
                                  "View Reports",
                                  "Access sales, operational, and user analytics.",
                                  themeProvider,
                                  () => _navigateToManagementScreen(
                                      AdminReportsScreen.routeName, "Reports")),
                              _buildManagementTile(
                                  Icons.route_outlined,
                                  "Run Management",
                                  "Monitor and manage pickup/delivery runs.",
                                  themeProvider,
                                  () => _navigateToManagementScreen(
                                      AdminRunManagementScreen.routeName,
                                      "Run Management")),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatsGrid(ThemeProvider themeProvider) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12.0,
      mainAxisSpacing: 12.0,
      childAspectRatio: 1.8,
      children: [
        _buildStatCard(
            Icons.shopping_cart_checkout_rounded,
            "Orders Today",
            _dashboardStats.totalOrdersToday.toString(),
            themeProvider.gas2doorTeal,
            themeProvider),
        _buildStatCard(
            Icons.pending_actions_rounded,
            "Pending Orders",
            _dashboardStats.pendingOrders.toString(),
            themeProvider.warningColor,
            themeProvider),
        _buildStatCard(
            Icons.local_shipping_rounded,
            "Active Deliveries",
            _dashboardStats.activeDeliveries.toString(),
            themeProvider.gas2doorPrimaryBlue,
            themeProvider),
        _buildStatCard(
            Icons.group_rounded,
            "Total Customers",
            _dashboardStats.registeredCustomers.toString(),
            themeProvider.gas2doorPurple,
            themeProvider),
        _buildStatCard(
            Icons.motorcycle_rounded,
            "Active Drivers",
            _dashboardStats.activeDrivers.toString(),
            themeProvider.successColor,
            themeProvider),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value,
      Color iconColor, ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 2,
      shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: themeProvider.secondaryText,
                        fontWeight: FontWeight.w500)),
                Icon(icon, size: 24, color: iconColor.withOpacity(0.8)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementSectionTitle(
      String title, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: themeProvider.secondaryText,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildManagementTile(IconData icon, String title, String subtitle,
      ThemeProvider themeProvider, VoidCallback onTap) {
    return CustomCard(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 1.5,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: themeProvider.gas2doorPrimaryBlue.withOpacity(0.1),
          child: Icon(icon, color: themeProvider.gas2doorPrimaryBlue, size: 24),
        ),
        title: Text(title,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: themeProvider.primaryText)),
        subtitle: Text(subtitle,
            style: GoogleFonts.inter(
                fontSize: 13, color: themeProvider.secondaryText)),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: themeProvider.tertiaryText),
        onTap: onTap,
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Failed to Load Dashboard',
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
              onPressed: () => _fetchDashboardData(isRefresh: true),
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
