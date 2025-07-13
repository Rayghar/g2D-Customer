// File: lib/screens/customer/track_driver_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
// Import OrderDetailsScreen for navigation if needed from here, though typically not.
// For this example, it's mainly for consistency in status icon logic.
import './order_details_screen.dart'
    show OrderStatusStep; // For status consistency reference if needed directly

class MockTrackingOrderInfo {
  final String id;
  String trackingStatus;
  DateTime? eta;
  MockDriverInfo? driverInfo;

  MockTrackingOrderInfo({
    required this.id,
    required this.trackingStatus,
    this.eta,
    this.driverInfo,
  });

  // copyWith might not be needed if state is managed by refetching
}

class MockDriverInfo {
  final String id;
  final String name;
  final String? photoUrl;
  final String phoneNumber;
  final String? vehicleDetails;

  MockDriverInfo({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.phoneNumber,
    this.vehicleDetails,
  });
}

class TrackDriverScreen extends StatefulWidget {
  static const routeName = '/track_driver';
  final String orderId;
  final String customerId; // customerId is important for context

  const TrackDriverScreen({
    super.key,
    required this.orderId,
    required this.customerId,
  });

  @override
  State<TrackDriverScreen> createState() => _TrackDriverScreenState();
}

class _TrackDriverScreenState extends State<TrackDriverScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  MockTrackingOrderInfo? _trackingInfo;
  String? _errorMessage;
  late AnimationController _contentFadeController;
  late Animation<double> _contentFadeAnimation;

  // Timer for periodic refresh (optional)
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _contentFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _contentFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentFadeController, curve: Curves.easeIn),
    );
    _fetchInitialTrackingData();

    // Optional: Start periodic refresh
    // _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
    //   if (mounted && !_isLoading) {
    //     _fetchInitialTrackingData(isManualRefresh: false);
    //   }
    // });
  }

  @override
  void dispose() {
    _contentFadeController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialTrackingData({bool isManualRefresh = true}) async {
    if (!mounted) return;
    if (isManualRefresh) {
      // Only show full loader on manual refresh or initial load
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    // Simulate API call
    await Future.delayed(Duration(milliseconds: isManualRefresh ? 1200 : 800));
    if (!mounted) return;

    // Mock data cycling through statuses for demo purposes if refreshed
    List<String> statuses = [
      'Driver Assigned',
      'Driver Enroute to Gas Station',
      'Cylinder Refilling',
      'Out for Delivery',
    ];
    String newStatus = _trackingInfo?.trackingStatus ?? statuses.first;
    if (isManualRefresh && _trackingInfo != null) {
      // Cycle status on manual refresh for demo
      int currentIndex = statuses.indexOf(_trackingInfo!.trackingStatus);
      newStatus = statuses[(currentIndex + 1) % statuses.length];
    } else if (_trackingInfo == null) {
      // Initial load status
      newStatus = statuses[1]; // Start with "Driver Enroute..."
    }

    setState(() {
      _trackingInfo = MockTrackingOrderInfo(
        id: widget.orderId,
        trackingStatus: newStatus,
        eta: DateTime.now().add(
            Duration(minutes: (newStatus == 'Out for Delivery' ? 15 : 45))),
        driverInfo: MockDriverInfo(
          id: 'driver_xyz_789', name: 'Mr. Wale Oke',
          phoneNumber: '08098765432',
          vehicleDetails: 'Blue Suzuki Bike - KJA 123LG',
          photoUrl:
              'https://randomuser.me/api/portraits/men/32.jpg', // Example photo
        ),
      );
      _isLoading = false;
      if (isManualRefresh)
        _errorMessage = null; // Clear error on successful refresh
    });
    if (!_contentFadeController.isCompleted && isManualRefresh) {
      _contentFadeController.forward();
    } else if (isManualRefresh) {
      _contentFadeController.reset();
      _contentFadeController.forward();
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    HapticFeedback.mediumImpact();
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _showFeedbackSnackbar(
          'Could not launch phone dialer for $phoneNumber', context,
          isError: true);
    }
  }

  void _navigateToChat(
      {required String recipientId,
      required String recipientName,
      String? recipientPhoneNumber,
      String? recipientPhotoUrl}) {
    HapticFeedback.lightImpact();
    Navigator.of(context, rootNavigator: true).pushNamed(
      '/chat',
      arguments: {
        'orderId': widget.orderId,
        'currentUserId': widget.customerId,
        'recipientId': recipientId,
        'recipientName': recipientName,
        'recipientPhoneNumber': recipientPhoneNumber,
        'recipientPhotoUrl': recipientPhotoUrl,
      },
    );
  }

  void _showFeedbackSnackbar(String message, BuildContext context,
      {bool isError = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: isError
          ? themeProvider.errorColor
          : themeProvider.successColor.withOpacity(0.95),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      elevation: 6,
    ));
  }

  Map<String, dynamic> _getTrackingStatusVisuals(
      String status, ThemeProvider themeProvider) {
    IconData statusIcon;
    Color statusColor;
    String normalizedStatus = status.toLowerCase();

    // Aligning with established status icon/color conventions
    switch (normalizedStatus) {
      case 'order placed':
        statusIcon = Icons.playlist_add_check_circle_outlined;
        statusColor = themeProvider.gas2doorTeal;
        break;
      case 'order confirmed':
        statusIcon = Icons.thumb_up_alt_outlined;
        statusColor = themeProvider.gas2doorPrimaryBlue;
        break;
      case 'processing':
      case 'cylinder refilling':
        statusIcon = Icons.hourglass_top_rounded;
        statusColor = themeProvider.warningColor;
        break;
      case 'driver assigned':
        statusIcon = Icons.person_pin_circle_outlined;
        statusColor = themeProvider.warningColor;
        break;
      case 'driver enroute to pickup cylinder':
      case 'driver enroute to gas station':
        statusIcon = Icons.electric_moped_outlined;
        statusColor = themeProvider.warningColor;
        break;
      case 'out for delivery':
        statusIcon = Icons.local_shipping_outlined;
        statusColor = themeProvider.warningColor;
        break;
      case 'delivered':
        statusIcon = Icons.check_circle_outline_rounded;
        statusColor = themeProvider.successColor;
        break;
      case 'cancelled':
        statusIcon = Icons.cancel_outlined;
        statusColor = themeProvider.errorColor;
        break;
      default:
        statusIcon = Icons.info_outline;
        statusColor = themeProvider.secondaryText;
    }
    return {'icon': statusIcon, 'color': statusColor};
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0, // Design Language: Standard elevation
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text('Track Your Order',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: themeProvider.primaryText),
            onPressed: _isLoading
                ? null
                : () => _fetchInitialTrackingData(isManualRefresh: true),
            tooltip: "Refresh Status",
          )
        ],
      ),
      body: _isLoading &&
              _trackingInfo == null // Show loader only if no data yet
          ? Center(
              child: CircularProgressIndicator(
                  color: themeProvider.gas2doorPrimaryBlue))
          : _errorMessage != null
              ? _buildErrorState(themeProvider, _errorMessage!)
              : _trackingInfo ==
                      null // Should not happen if not loading and no error, but as a fallback
                  ? _buildErrorState(themeProvider,
                      "Tracking information is currently unavailable.")
                  : FadeTransition(
                      opacity: _contentFadeAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(
                            16.0), // Design Language: Consistent padding
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Order ID: #${_trackingInfo!.id.length > 7 ? _trackingInfo!.id.substring(_trackingInfo!.id.length - 7) : _trackingInfo!.id}',
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: themeProvider.secondaryText)),
                            const SizedBox(height: 16),
                            _buildStatusCard(_trackingInfo!, themeProvider),
                            const SizedBox(height: 20), // Adjusted spacing
                            if (_trackingInfo!.driverInfo != null) ...[
                              Text('Your Driver:',
                                  style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: themeProvider.primaryText)),
                              const SizedBox(height: 10), // Adjusted spacing
                              _buildDriverInfoCard(_trackingInfo!.driverInfo!,
                                  themeProvider, context),
                              const SizedBox(height: 24),
                            ],
                            TextButton.icon(
                              icon: Icon(Icons.receipt_long_outlined,
                                  color: themeProvider.gas2doorPrimaryBlue,
                                  size: 20),
                              label: Text('View Full Order Details',
                                  style: GoogleFonts.inter(
                                      color: themeProvider.gas2doorPrimaryBlue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5)),
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 0, vertical: 8)),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context, rootNavigator: true)
                                    .pushNamed(
                                  '/order_details', // Ensure this route is correctly defined
                                  arguments: {
                                    'orderId': widget.orderId,
                                    'customerId': widget.customerId
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildStatusCard(
      MockTrackingOrderInfo trackingInfo, ThemeProvider themeProvider) {
    final statusVisuals =
        _getTrackingStatusVisuals(trackingInfo.trackingStatus, themeProvider);
    final IconData statusIcon = statusVisuals['icon'];
    final Color statusColor = statusVisuals['color'];

    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(statusIcon,
                size: 32, color: statusColor), // Prominent status icon
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trackingInfo.trackingStatus,
                    style: GoogleFonts.inter(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: statusColor), // Status text colored
                  ),
                  if (trackingInfo.eta != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Est. Arrival: ${DateFormat('hh:mm a, MMM dd').format(trackingInfo.eta!)}', // More complete ETA
                      style: GoogleFonts.inter(
                          fontSize: 13.5, color: themeProvider.secondaryText),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfoCard(MockDriverInfo driver,
      ThemeProvider themeProvider, BuildContext context) {
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          // Use column for potentially more info if needed
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28, // Slightly larger avatar
                  backgroundColor: themeProvider.gas2doorTeal
                      .withOpacity(0.15), // Customer accent
                  backgroundImage:
                      driver.photoUrl != null && driver.photoUrl!.isNotEmpty
                          ? NetworkImage(driver.photoUrl!)
                          : null,
                  child: driver.photoUrl == null || driver.photoUrl!.isEmpty
                      ? Icon(Icons.person_rounded,
                          size: 30, color: themeProvider.gas2doorTeal)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.name,
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.primaryText)),
                      if (driver.vehicleDetails != null)
                        Text(driver.vehicleDetails!,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: themeProvider.secondaryText)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.end, // Align buttons to the right
              children: [
                TextButton.icon(
                  icon: Icon(Icons.call_outlined,
                      color: themeProvider.gas2doorPrimaryBlue, size: 20),
                  label: Text("Call",
                      style: GoogleFonts.inter(
                          color: themeProvider.gas2doorPrimaryBlue,
                          fontWeight: FontWeight.w500)),
                  onPressed: () => _makePhoneCall(driver.phoneNumber),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: Icon(Icons.chat_bubble_outline_rounded,
                      color: themeProvider.gas2doorPrimaryBlue, size: 20),
                  label: Text("Chat",
                      style: GoogleFonts.inter(
                          color: themeProvider.gas2doorPrimaryBlue,
                          fontWeight: FontWeight.w500)),
                  onPressed: () => _navigateToChat(
                      recipientId: driver.id,
                      recipientName: driver.name,
                      recipientPhoneNumber: driver.phoneNumber,
                      recipientPhotoUrl: driver.photoUrl),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String message) {
    return Center(
      child: CustomCard(
        margin: const EdgeInsets.all(30),
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.track_changes_outlined,
                  color: themeProvider.errorColor,
                  size: 60), // Tracking specific error icon
              const SizedBox(height: 20),
              Text('Tracking Unavailable',
                  style: GoogleFonts.inter(
                      color: themeProvider.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(message,
                  style: GoogleFonts.inter(
                      color: themeProvider.secondaryText, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              CustomButton(
                  text: 'Retry',
                  onPressed: () =>
                      _fetchInitialTrackingData(isManualRefresh: true),
                  color: themeProvider.gas2doorPrimaryBlue),
            ],
          ),
        ),
      ),
    );
  }
}
