// File: lib/screens/admin/admin_driver_details_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../models/admin/admin_driver_detail_model.dart';
import '../../models/admin/admin_order_summary_model.dart';
import '../../services/api_service.dart';
import './admin_order_details_screen.dart';
import './admin_order_list_screen.dart';

class AdminDriverDetailsScreen extends StatefulWidget {
  static const String routeName = '/admin_driver_details';
  final String driverId;

  const AdminDriverDetailsScreen({super.key, required this.driverId});

  @override
  State<AdminDriverDetailsScreen> createState() =>
      _AdminDriverDetailsScreenState();
}

class _AdminDriverDetailsScreenState extends State<AdminDriverDetailsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  AdminDriverDetailModel? _driverData;
  String? _errorMessage;
  bool _isUpdatingAccountStatus = false;
  bool _isUpdatingAvailability = false;

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _sectionSlideAnimations;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _sectionSlideAnimations = List.generate(
      5,
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(
              0.1 + (index * 0.12), 0.8 + (index * 0.1).clamp(0.0, 0.2),
              curve: Curves.easeOutCubic),
        ),
      ),
    );
    _fetchDriverDetails();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchDriverDetails({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final fetchedDriverData =
          await _apiService.adminGetDriverDetails(widget.driverId);
      if (mounted) {
        setState(() {
          _driverData = fetchedDriverData;
          _isLoading = false;
          _errorMessage = null;
        });
        _entryAnimController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Failed to load driver details: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  Future<void> _handleUpdateDriverAccountStatus(String newStatus) async {
    HapticFeedback.mediumImpact();
    if (!mounted || _driverData == null) return;

    String actionText = newStatus.toLowerCase();
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final themeProvider =
            Provider.of<ThemeProvider>(dialogContext, listen: false);
        return AlertDialog(
          backgroundColor: themeProvider.cardBackground,
          title: Text('Confirm Account ${actionText.capitalizeFirst()}',
              style: GoogleFonts.inter(
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w600)),
          content: Text(
              'Are you sure you want to $actionText this driver\'s account?',
              style: GoogleFonts.inter(color: themeProvider.secondaryText)),
          actions: <Widget>[
            TextButton(
                child: Text('Cancel',
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
                onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
              child: Text(actionText.capitalizeFirst(),
                  style: GoogleFonts.inter(
                      color: newStatus == "Suspended"
                          ? themeProvider.errorColor
                          : themeProvider.successColor,
                      fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _isUpdatingAccountStatus = true);
      try {
        // FIX: Using the real ApiService method
        await _apiService.adminUpdateUserStatus(widget.driverId, newStatus);
        if (mounted) {
          _showFeedbackSnackbar(
              'Driver account ${newStatus.toLowerCase()}d successfully.');
          _fetchDriverDetails(isRefresh: true); // Refresh data from source
        }
      } catch (e) {
        if (mounted)
          _showFeedbackSnackbar(
              'Error: ${e.toString().replaceFirst("Exception: ", "")}',
              isError: true);
      } finally {
        if (mounted) setState(() => _isUpdatingAccountStatus = false);
      }
    }
  }

  Future<void> _toggleDriverAvailability(bool isAvailable) async {
    HapticFeedback.lightImpact();
    if (!mounted || _driverData == null) return;
    setState(() => _isUpdatingAvailability = true);
    try {
      // FIX: Using the real ApiService method
      await _apiService.adminSetDriverAvailability(
          widget.driverId, isAvailable);
      if (mounted) {
        _showFeedbackSnackbar(
            "Driver availability forced to ${isAvailable ? 'Online' : 'Offline'}.");
        setState(() => _driverData!.isAvailableOnline =
            isAvailable); // Optimistic UI update
      }
    } catch (e) {
      if (mounted)
        _showFeedbackSnackbar(
            "Error: ${e.toString().replaceFirst("Exception: ", "")}",
            isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingAvailability = false);
    }
  }

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor:
          isError ? Theme.of(context).colorScheme.error : Colors.green,
    ));
  }

  void _navigateToOrderDetails(String orderId) {
    Navigator.pushNamed(context, AdminOrderDetailsScreen.routeName,
        arguments: {'orderId': orderId});
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final adminAccentColor = themeProvider.gas2doorPurple;

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        title: Text(
          _isLoading || _driverData == null ? 'Loading...' : _driverData!.name,
          style: GoogleFonts.inter(
              color: themeProvider.primaryText, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: adminAccentColor))
          : _driverData == null || _errorMessage != null
              ? _buildErrorState(themeProvider)
              : FadeTransition(
                  opacity: _entryAnimController,
                  child: RefreshIndicator(
                    onRefresh: () => _fetchDriverDetails(isRefresh: true),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildDriverHeader(_driverData!, themeProvider),
                          const SizedBox(height: 20),
                          _buildDriverStatsCard(_driverData!, themeProvider),
                          const SizedBox(height: 20),
                          _buildAccountActionsCard(_driverData!, themeProvider),
                          const SizedBox(height: 20),
                          if (_driverData!.recentDeliveries.isNotEmpty)
                            _buildOrderHistoryCard(
                                _driverData!.recentDeliveries,
                                themeProvider,
                                _driverData!.id),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildDriverHeader(
      AdminDriverDetailModel driver, ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: themeProvider.gas2doorTeal.withOpacity(0.2),
              backgroundImage:
                  driver.photoUrl != null && driver.photoUrl!.isNotEmpty
                      ? NetworkImage(driver.photoUrl!)
                      : null,
              child: (driver.photoUrl == null || driver.photoUrl!.isEmpty)
                  ? Text(driver.initials,
                      style: GoogleFonts.inter(
                          fontSize: 40,
                          color: themeProvider.gas2doorTeal,
                          fontWeight: FontWeight.w500))
                  : null,
            ),
            const SizedBox(height: 16),
            Text(driver.name,
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 6),
            Text(driver.email,
                style: GoogleFonts.inter(
                    fontSize: 15, color: themeProvider.secondaryText)),
            const SizedBox(height: 4),
            Text(driver.phone,
                style: GoogleFonts.inter(
                    fontSize: 15, color: themeProvider.secondaryText)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _buildStatusPill(driver.accountStatus, themeProvider),
              const SizedBox(width: 10),
              _buildStatusPill(driver.isAvailableOnline ? "Online" : "Offline",
                  themeProvider,
                  isOnlineStatus: true),
            ]),
            if (driver.vehicleType != null && driver.licensePlate != null) ...[
              const SizedBox(height: 10),
              Text("Vehicle: ${driver.vehicleType} - ${driver.licensePlate}",
                  style: GoogleFonts.inter(
                      fontSize: 13, color: themeProvider.tertiaryText)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status, ThemeProvider themeProvider,
      {bool isOnlineStatus = false}) {
    Color bgColor, textColor;
    if (isOnlineStatus) {
      bgColor = (status.toLowerCase() == "online"
              ? themeProvider.successColor
              : themeProvider.secondaryText)
          .withOpacity(0.15);
      textColor = status.toLowerCase() == "online"
          ? themeProvider.successColor
          : themeProvider.secondaryText;
    } else {
      switch (status.toLowerCase()) {
        case "active":
          bgColor = themeProvider.successColor.withOpacity(0.15);
          textColor = themeProvider.successColor;
          break;
        case "pending approval":
          bgColor = themeProvider.warningColor.withOpacity(0.15);
          textColor = themeProvider.warningColor;
          break;
        case "suspended":
          bgColor = themeProvider.errorColor.withOpacity(0.15);
          textColor = themeProvider.errorColor;
          break;
        default:
          bgColor = themeProvider.tertiaryText.withOpacity(0.15);
          textColor = themeProvider.tertiaryText;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: GoogleFonts.inter(
              color: textColor, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  Widget _buildDriverStatsCard(
      AdminDriverDetailModel driver, ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Driver Performance",
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                    "Total Deliveries",
                    driver.totalDeliveriesCompleted.toString(),
                    Icons.local_shipping_outlined,
                    themeProvider),
                _buildStatItem(
                    "Avg. Rating",
                    driver.averageRating.toStringAsFixed(1),
                    Icons.star_half_rounded,
                    themeProvider),
                _buildStatItem(
                    "Total Earned",
                    "₦${NumberFormat("#,##0").format(driver.totalEarnings)}",
                    Icons.account_balance_wallet_outlined,
                    themeProvider),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActionsCard(
      AdminDriverDetailModel driver, ThemeProvider themeProvider) {
    return CustomCard(
        color: themeProvider.cardBackground,
        borderRadius: themeProvider.cardBorderRadiusValue,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text("DRIVER ACCOUNT ACTIONS",
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.secondaryText,
                    letterSpacing: 0.8)),
          ),
          if (driver.accountStatus == "Pending Approval")
            _buildAdminActionTile(
                Icons.check_circle_outline_rounded,
                "Approve Driver Application",
                themeProvider.successColor,
                () => _handleUpdateDriverAccountStatus("Active")),
          if (driver.accountStatus == "Active")
            _buildAdminActionTile(
                Icons.pause_circle_outline_rounded,
                "Suspend Driver Account",
                themeProvider.errorColor,
                () => _handleUpdateDriverAccountStatus("Suspended")),
          if (driver.accountStatus == "Suspended")
            _buildAdminActionTile(
                Icons.play_circle_outline_rounded,
                "Reactivate Driver Account",
                themeProvider.successColor,
                () => _handleUpdateDriverAccountStatus("Active")),
          _buildDivider(themeProvider),
          _buildAdminActionTile(
              driver.isAvailableOnline
                  ? Icons.power_settings_new_rounded
                  : Icons.online_prediction_rounded,
              driver.isAvailableOnline ? "Force Offline" : "Force Online",
              themeProvider.secondaryText,
              _isUpdatingAvailability
                  ? null
                  : () => _toggleDriverAvailability(!driver.isAvailableOnline)),
        ]));
  }

  Widget _buildOrderHistoryCard(List<AdminOrderSummaryModel> orders,
      ThemeProvider themeProvider, String driverId) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Deliveries',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      "Order #${order.shortOrderId} for ${order.customer.name}",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                  subtitle: Text(order.formattedOrderDate,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: themeProvider.tertiaryText)),
                  trailing: Text(
                      "₦${NumberFormat("#,##0").format(order.totalAmount)}"),
                  onTap: () => _navigateToOrderDetails(order.id),
                );
              },
              separatorBuilder: (context, index) =>
                  Divider(color: themeProvider.tertiaryText.withOpacity(0.2)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActionTile(
      IconData icon, String title, Color iconColor, VoidCallback? onTap) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(title,
          style: GoogleFonts.inter(
              fontSize: 16,
              color: themeProvider.primaryText,
              fontWeight: FontWeight.w500)),
      trailing: onTap != null
          ? Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: themeProvider.tertiaryText)
          : (_isUpdatingAccountStatus || _isUpdatingAvailability
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null),
      onTap: _isUpdatingAccountStatus || _isUpdatingAvailability ? null : onTap,
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, ThemeProvider themeProvider) {
    /* Same as in AdminCustomerDetailsScreen */
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: themeProvider.gas2doorPrimaryBlue, size: 28),
      const SizedBox(height: 6),
      Text(value,
          style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeProvider.primaryText)),
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 12, color: themeProvider.secondaryText)),
    ]);
  }

  Widget _buildErrorState(ThemeProvider themeProvider) {
    /* ... Same as AdminCustomerDetailsScreen (adjust icon/text if needed) ... */
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_outlined,
                color: themeProvider.errorColor, size: 60), // Changed icon
            const SizedBox(height: 20),
            Text('Could Not Load Driver Details',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Please check your connection and try again.',
                style: GoogleFonts.inter(
                    color: themeProvider.secondaryText, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            CustomButton(
                text: "Retry",
                onPressed: () => _fetchDriverDetails(isRefresh: true),
                color: themeProvider.gas2doorPrimaryBlue,
                icon: Icon(Icons.refresh_rounded,
                    color: themeProvider.infoColorOnDarkBgs)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeProvider themeProvider) {
    return Divider(
        height: 0.5,
        thickness: 0.3,
        color: themeProvider.tertiaryText.withOpacity(0.2),
        indent: 16 + 24 + 16, // leading icon + padding
        endIndent: 16);
  }
}

// FIX: Added the missing String extension method
extension StringExtensionAdminDriverDetails on String {
  String capitalizeFirst() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
