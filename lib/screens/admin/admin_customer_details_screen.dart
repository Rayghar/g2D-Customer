// File: lib/screens/admin/admin_customer_details_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
// Import defined models
import '../../services/api_service.dart';
import '../../models/admin/admin_customer_detail_model.dart';
import '../../models/admin/admin_order_summary_model.dart'; // For order list
import '../../models/address_model.dart'; // For displaying addresses

// Import screen for navigation
import './admin_order_details_screen.dart';
import './admin_order_list_screen.dart';
// import '../customer/address_list_screen.dart'; // Would need an admin variant or filter

class AdminCustomerDetailsScreen extends StatefulWidget {
  static const String routeName = '/admin_customer_details';
  final String customerId;

  const AdminCustomerDetailsScreen({super.key, required this.customerId});

  @override
  State<AdminCustomerDetailsScreen> createState() =>
      _AdminCustomerDetailsScreenState();
}

class _AdminCustomerDetailsScreenState extends State<AdminCustomerDetailsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService(); // Use the real ApiService

  bool _isLoading = true;
  AdminCustomerDetailModel? _customerData;
  String? _errorMessage;
  bool _isUpdatingStatus = false;

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _sectionSlideAnimations;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _sectionSlideAnimations = List.generate(
      4,
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(
              0.1 + (index * 0.1), 0.7 + (index * 0.1).clamp(0.0, 0.3),
              curve: Curves.easeOutCubic),
        ),
      ),
    );
    _fetchCustomerDetails();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  /// INTEGRATED: Fetches full customer details from the backend.
  Future<void> _fetchCustomerDetails({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final fetchedData =
          await _apiService.adminGetCustomerDetails(widget.customerId);
      if (mounted) {
        setState(() {
          _customerData = fetchedData;
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
              "Failed to load customer details: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  /// INTEGRATED: Updates the customer's account status (Active/Suspended).
  Future<void> _toggleAccountStatus(String newStatus) async {
    HapticFeedback.mediumImpact();
    if (_customerData == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final themeProvider =
            Provider.of<ThemeProvider>(dialogContext, listen: false);
        return AlertDialog(
          backgroundColor: themeProvider.cardBackground,
          shape: RoundedRectangleBorder(
              borderRadius: themeProvider.cardBorderRadius),
          title: Text('Confirm ${newStatus.capitalizeFirst()} Account',
              style: GoogleFonts.inter(
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w600)),
          content: Text(
              'Are you sure you want to ${newStatus.toLowerCase()} this customer\'s account?',
              style: GoogleFonts.inter(color: themeProvider.secondaryText)),
          actions: <Widget>[
            TextButton(
                child: Text('Cancel',
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
                onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
                child: Text(newStatus.capitalizeFirst(),
                    style: GoogleFonts.inter(
                        color: newStatus == "Suspended"
                            ? themeProvider.errorColor
                            : themeProvider.successColor,
                        fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _isUpdatingStatus = true);
      try {
        await _apiService.adminUpdateUserStatus(widget.customerId, newStatus);
        if (mounted) {
          _showFeedbackSnackbar('Account status updated successfully.');
          setState(() => _customerData!.accountStatus = newStatus);
        }
      } catch (e) {
        if (mounted)
          _showFeedbackSnackbar(
              'Error: ${e.toString().replaceFirst("Exception: ", "")}',
              isError: true);
      } finally {
        if (mounted) setState(() => _isUpdatingStatus = false);
      }
    }
  }

  /// INTEGRATED: Triggers a password reset email for the customer.
  Future<void> _handleTriggerPasswordReset() async {
    HapticFeedback.mediumImpact();
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final themeProvider =
            Provider.of<ThemeProvider>(dialogContext, listen: false);
        return AlertDialog(
          backgroundColor: themeProvider.cardBackground,
          title: Text('Trigger Password Reset?',
              style: GoogleFonts.inter(
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w600)),
          content: Text(
              'Send a password reset link to ${_customerData?.email ?? "this customer"}?',
              style: GoogleFonts.inter(color: themeProvider.secondaryText)),
          actions: <Widget>[
            TextButton(
                child: Text('Cancel',
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
                onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
                child: Text('Send Link',
                    style: GoogleFonts.inter(
                        color: themeProvider.gas2doorPrimaryBlue,
                        fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );
    if (confirm == true) {
      setState(() => _isLoading = true); // Use general loader
      try {
        await _apiService.adminTriggerPasswordReset(_customerData!.email);
        if (mounted)
          _showFeedbackSnackbar(
              'Password reset link sent to ${_customerData!.email}.');
      } catch (e) {
        if (mounted)
          _showFeedbackSnackbar(
              'Error: ${e.toString().replaceFirst("Exception: ", "")}',
              isError: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color adminAccentColor = themeProvider.gas2doorPurple;

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text(
          _isLoading || _customerData == null
              ? 'Loading...'
              : _customerData!.name,
          style: GoogleFonts.inter(
              color: themeProvider.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: 18),
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
          : _errorMessage != null || _customerData == null
              ? _buildErrorState(themeProvider)
              : FadeTransition(
                  opacity: _entryAnimController,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SlideTransition(
                            position: _sectionSlideAnimations[0],
                            child: _buildCustomerHeader(
                                _customerData!, themeProvider)),
                        const SizedBox(height: 20),
                        SlideTransition(
                            position: _sectionSlideAnimations[1],
                            child: _buildCustomerStats(
                                _customerData!, themeProvider)),
                        const SizedBox(height: 20),
                        SlideTransition(
                            position: _sectionSlideAnimations[2],
                            child: _buildAccountActionsCard(
                                _customerData!, themeProvider)),
                        const SizedBox(height: 20),
                        SlideTransition(
                            position: _sectionSlideAnimations[3],
                            child: _buildOrderHistoryCard(
                                _customerData!.recentOrders,
                                themeProvider,
                                _customerData!.id)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildCustomerHeader(
      AdminCustomerDetailModel customer, ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: themeProvider.gas2doorPurple.withOpacity(0.2),
              backgroundImage:
                  customer.photoUrl != null && customer.photoUrl!.isNotEmpty
                      ? NetworkImage(customer.photoUrl!)
                      : null,
              child: customer.photoUrl == null || customer.photoUrl!.isEmpty
                  ? Text(customer.initials,
                      style: GoogleFonts.inter(
                          fontSize: 36,
                          color: themeProvider.gas2doorPurple,
                          fontWeight: FontWeight.w500))
                  : null,
            ),
            const SizedBox(height: 16),
            Text(customer.name,
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 6),
            Text(customer.email,
                style: GoogleFonts.inter(
                    fontSize: 15, color: themeProvider.secondaryText)),
            const SizedBox(height: 4),
            Text(customer.phone,
                style: GoogleFonts.inter(
                    fontSize: 15, color: themeProvider.secondaryText)),
            const SizedBox(height: 6),
            Text("Joined: ${customer.formattedRegistrationDate}",
                style: GoogleFonts.inter(
                    fontSize: 13, color: themeProvider.tertiaryText)),
            if (customer.defaultAddress != null) ...[
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: themeProvider.tertiaryText),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(customer.defaultAddress!.fullAddress,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: themeProvider.tertiaryText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ]),
            ],
            const SizedBox(height: 12),
            _buildStatusPill(customer.accountStatus, themeProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status, ThemeProvider themeProvider) {
    Color pillColor;
    switch (status.toLowerCase()) {
      case "active":
        pillColor = themeProvider.successColor;
        break;
      case "suspended":
        pillColor = themeProvider.errorColor;
        break;
      case "pending verification":
        pillColor = themeProvider.warningColor;
        break;
      default:
        pillColor = themeProvider.secondaryText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: pillColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: GoogleFonts.inter(
              color: pillColor, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _buildCustomerStats(
      AdminCustomerDetailModel customer, ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Activity Snapshot",
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem("Total Orders", customer.totalOrders.toString(),
                    Icons.shopping_cart_checkout_rounded, themeProvider),
                _buildStatItem(
                    "Total Spent",
                    "₦${NumberFormat("#,##0").format(customer.totalSpent)}",
                    Icons.monetization_on_outlined,
                    themeProvider),
              ],
            ),
            if (customer.lastOrderDate != null) ...[
              const SizedBox(height: 12),
              _buildDetailRowAdmin(
                  "Last Order On:",
                  DateFormat('dd MMM, yyyy').format(customer.lastOrderDate!),
                  themeProvider)
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, ThemeProvider themeProvider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
      ],
    );
  }

  Widget _buildDetailRowAdmin(
      String label, String value, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14, color: themeProvider.secondaryText)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14.5,
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAccountActionsCard(
      AdminCustomerDetailModel customer, ThemeProvider themeProvider) {
    return CustomCard(
        color: themeProvider.cardBackground,
        borderRadius: themeProvider.cardBorderRadiusValue,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text("ACCOUNT ACTIONS",
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.secondaryText,
                    letterSpacing: 0.8)),
          ),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Icon(
                customer.accountStatus.toLowerCase() == "active"
                    ? Icons.block_rounded
                    : Icons.check_circle_outline_rounded,
                color: customer.accountStatus.toLowerCase() == "active"
                    ? themeProvider.errorColor
                    : themeProvider.successColor),
            title: Text(
                customer.accountStatus.toLowerCase() == "active"
                    ? 'Suspend Account'
                    : 'Activate Account',
                style: GoogleFonts.inter(
                    color: customer.accountStatus.toLowerCase() == "active"
                        ? themeProvider.errorColor
                        : themeProvider.successColor,
                    fontWeight: FontWeight.w500)),
            onTap: _isUpdatingStatus
                ? null
                : () => _toggleAccountStatus(
                    customer.accountStatus.toLowerCase() == "active"
                        ? "Suspended"
                        : "Active"),
          ),
          _buildDivider(themeProvider),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Icon(Icons.vpn_key_outlined,
                color: themeProvider.secondaryText),
            title: Text('Trigger Password Reset',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w500)),
            trailing: Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: themeProvider.tertiaryText),
            onTap: _isLoading ? null : _handleTriggerPasswordReset,
          ),
          _buildDivider(themeProvider),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Icon(Icons.edit_location_alt_outlined,
                color: themeProvider.secondaryText),
            title: Text('View/Manage Addresses (${customer.addresses.length})',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w500)),
            trailing: Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: themeProvider.tertiaryText),
            onTap: () {
              _showFeedbackSnackbar(
                  "View Customer Addresses (Not Implemented in detail view yet)",
                  isError: true);
              // TODO: Navigate to an Admin version of AddressListScreen, filtered by customer.id
              // Navigator.pushNamed(context, AdminAddressListScreen.routeName, arguments: {'customerId': customer.id});
            },
          ),
        ]));
  }

  Widget _buildOrderHistoryCard(List<AdminOrderSummaryModel> orders,
      ThemeProvider themeProvider, String customerId) {
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Recent Order History (${orders.length > 3 ? "Top 3" : orders.length})',
                    style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.primaryText)),
                if (orders.length > 3 ||
                    (_customerData != null &&
                        _customerData!.totalOrders > orders.length))
                  TextButton(
                    onPressed: () {
                      // Ensure AdminOrderListScreen.routeName is correctly defined and handled in main.dart
                      Navigator.pushNamed(
                          context, AdminOrderListScreen.routeName,
                          arguments: {'customerIdFilter': customerId});
                    },
                    child: Text(
                        "View All (${_customerData?.totalOrders ?? orders.length})", // Show total if available
                        style: GoogleFonts.inter(
                            color: themeProvider.gas2doorPrimaryBlue,
                            fontWeight: FontWeight.w500)),
                  )
              ],
            ),
            const SizedBox(height: 10),
            if (orders.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    "No orders found for this customer.",
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText),
                  ),
                ),
              )
            else // This is where your error was indicated
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length > 3 ? 3 : orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _getStatusIcon(order
                          .status), // Ensure this method exists and is correct
                      color: _getStatusColor(order.status,
                          themeProvider), // Ensure this method exists
                      size: 22,
                    ),
                    title: Text(
                      "Order #${order.shortOrderId} - ${order.itemsPreview}",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          color: themeProvider.primaryText,
                          fontSize: 14),
                    ),
                    subtitle: Text(
                      order
                          .formattedOrderDate, // Uses getter from AdminOrderSummaryModel
                      style: GoogleFonts.inter(
                          color: themeProvider.tertiaryText, fontSize: 12),
                    ),
                    trailing: Text(
                      "₦${NumberFormat("#,##0").format(order.totalAmount)}",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: themeProvider.primaryText,
                          fontSize: 14),
                    ),
                    onTap: () {
                      // Ensure AdminOrderDetailsScreen.routeName is correctly defined and handled
                      Navigator.pushNamed(
                          context, AdminOrderDetailsScreen.routeName,
                          arguments: {'orderId': order.id});
                    },
                  );
                },
                separatorBuilder: (context, index) =>
                    Divider(color: themeProvider.tertiaryText.withOpacity(0.2)),
              ), // Closing parenthesis for ListView.separated
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ThemeProvider themeProvider) {
    /* From AdminOrderListScreen */
    switch (status.toLowerCase()) {
      case 'delivered':
        return themeProvider.successColor;
      case 'out for delivery':
      case 'processing':
      case 'order confirmed':
        return themeProvider.warningColor;
      case 'cancelled':
        return themeProvider.errorColor;
      default:
        return themeProvider.secondaryText;
    }
  }

  IconData _getStatusIcon(String status) {
    /* From AdminOrderListScreen */
    switch (status.toLowerCase()) {
      case 'delivered':
        return Icons.check_circle_outline;
      case 'out for delivery':
        return Icons.local_shipping_outlined;
      case 'processing':
      case 'order confirmed':
        return Icons.hourglass_top_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.pending_actions_outlined;
    }
  }

  Widget _buildDivider(ThemeProvider themeProvider) {
    return Divider(
        height: 0.5,
        thickness: 0.3,
        color: themeProvider.tertiaryText.withOpacity(0.2),
        indent: 16,
        endIndent: 16);
  }

  Widget _buildErrorState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined,
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Could Not Load Customer Details',
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
              onPressed: () => _fetchCustomerDetails(isRefresh: true),
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

// Helper extension for String capitalization
extension StringExtensionAdminCustDetails on String {
  String capitalizeFirst() {
    if (this.isEmpty) return "";
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}
