// File: lib/screens/driver/driver_notification_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
// Import relevant screens for navigation if a notification type links to them
// import './driver_dashboard_home_screen.dart'; // For new run assignment
// import './driver_active_run_details_screen.dart'; // If navigating directly to an active run

// Model for Driver Notifications
class DriverNotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;
  final String
      type; // e.g., "new_run", "system_alert", "document_update", "payout_processed"
  final Map<String, dynamic>?
      data; // e.g., {'runId': 'RUN123', 'documentType': 'License'}

  DriverNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    required this.type,
    this.data,
  });
}

// Mock Service for Driver Notifications
class MockDriverNotificationService {
  final List<DriverNotificationItem> _mockDb = [
    DriverNotificationItem(
        id: 'dn_001',
        title: 'New Pickup Run Assigned!',
        body:
            'Batch BATCH_PEND_001 (Surulere Area, 4 Orders) has been assigned to you.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        type: 'new_run_assigned',
        data: {
          'batchId': 'BATCH_PEND_001',
          'runId': 'RUN_NEW_001'
        }, // runId might be generated on assignment
        isRead: false),
    DriverNotificationItem(
        id: 'dn_002',
        title: 'System Maintenance Alert',
        body:
            'The driver app will undergo scheduled maintenance tonight from 2 AM to 3 AM. Expect brief service interruptions.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: 'system_alert',
        isRead: false),
    DriverNotificationItem(
        id: 'dn_003',
        title: 'Payout Processed',
        body:
            'Your payout of ₦15,750.50 for the week ending Oct 26 has been processed.',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        type: 'payout_processed',
        data: {'payoutId': 'PAYOUT_DRV123_005'},
        isRead: true),
    DriverNotificationItem(
        id: 'dn_004',
        title: 'Document Expiring Soon',
        body:
            'Your Vehicle License is due to expire in 7 days. Please update it to continue receiving orders.',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        type: 'document_expiry_warning',
        data: {'documentType': 'Vehicle License'},
        isRead: true),
  ];

  Future<List<DriverNotificationItem>> getNotifications(String driverId) async {
    print(
        "MockDriverNotificationService: Fetching notifications for driver $driverId");
    await Future.delayed(const Duration(milliseconds: 600));
    _mockDb.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.from(_mockDb);
  }

  Future<bool> markAsRead(String driverId, String notificationId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _mockDb.indexWhere((n) => n.id == notificationId);
    if (index != -1) _mockDb[index].isRead = true;
    return true;
  }

  Future<bool> markAllAsRead(String driverId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    for (var n in _mockDb) {
      n.isRead = true;
    }
    return true;
  }

  Future<bool> clearAllNotifications(String driverId) async {
    await Future.delayed(const Duration(milliseconds: 350));
    _mockDb.clear();
    return true;
  }
}

class DriverNotificationScreen extends StatefulWidget {
  static const String routeName =
      '/driver_notifications'; // For potential direct navigation
  final String driverId;

  const DriverNotificationScreen({super.key, required this.driverId});

  @override
  State<DriverNotificationScreen> createState() =>
      _DriverNotificationScreenState();
}

class _DriverNotificationScreenState extends State<DriverNotificationScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<DriverNotificationItem> _notifications = [];
  String? _errorMessage;

  late AnimationController _listAnimationController;
  final MockDriverNotificationService _notificationService =
      MockDriverNotificationService();

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fetchNotifications();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotifications({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      if (isRefresh) _errorMessage = null;
    });

    try {
      final fetchedNotifications =
          await _notificationService.getNotifications(widget.driverId);
      if (mounted) {
        setState(() {
          _notifications = fetchedNotifications;
          _isLoading = false;
          _errorMessage = null;
        });
        if (_notifications.isNotEmpty) {
          _listAnimationController.forward(from: 0.0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load notifications: ${e.toString()}";
        });
      }
    }
  }

  Future<void> _markAsRead(int index) async {
    HapticFeedback.lightImpact();
    if (mounted &&
        index < _notifications.length &&
        !_notifications[index].isRead) {
      final notificationId = _notifications[index].id;
      // Optimistically update UI
      setState(() => _notifications[index].isRead = true);
      bool success = await _notificationService.markAsRead(
          widget.driverId, notificationId);
      if (!success && mounted) {
        // Revert if backend call fails (optional, depends on desired UX)
        setState(() => _notifications[index].isRead = false);
        _showFeedbackSnackbar("Failed to mark as read. Please try again.",
            isError: true);
      }
    }
  }

  Future<void> _handleMarkAllAsRead(ThemeProvider themeProvider) async {
    HapticFeedback.mediumImpact();
    // TODO: Add confirmation dialog if desired
    setState(() =>
        _isLoading = true); // Use general loading indicator for mass actions
    final success = await _notificationService.markAllAsRead(widget.driverId);
    if (mounted) {
      if (success) {
        _showFeedbackSnackbar("All notifications marked as read.");
        _fetchNotifications(isRefresh: true); // Refresh to reflect changes
      } else {
        _showFeedbackSnackbar("Failed to mark all as read.", isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleClearAllNotifications(ThemeProvider themeProvider) async {
    HapticFeedback.mediumImpact();
    bool? confirmClear = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: themeProvider.cardBackground,
          shape: RoundedRectangleBorder(
              borderRadius: themeProvider.cardBorderRadius),
          title: Text('Clear All Notifications?',
              style: GoogleFonts.inter(
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w600)),
          content: Text(
              'Are you sure you want to delete all notifications? This action cannot be undone.',
              style: GoogleFonts.inter(color: themeProvider.secondaryText)),
          actions: <Widget>[
            TextButton(
                child: Text('Cancel',
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
                onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
                child: Text('Clear All',
                    style: GoogleFonts.inter(
                        color: themeProvider.errorColor,
                        fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (confirmClear == true) {
      setState(() => _isLoading = true);
      final success =
          await _notificationService.clearAllNotifications(widget.driverId);
      if (mounted) {
        if (success) {
          _showFeedbackSnackbar("All notifications cleared.");
          _fetchNotifications(isRefresh: true); // Refresh to reflect changes
        } else {
          _showFeedbackSnackbar("Failed to clear notifications.",
              isError: true);
        }
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleNotificationTap(DriverNotificationItem notification) {
    final index = _notifications.indexWhere((n) => n.id == notification.id);
    if (index != -1 && !_notifications[index].isRead) {
      _markAsRead(index);
    }

    // Example navigation based on type
    if (notification.type == 'new_run_assigned' &&
        notification.data?['runId'] != null) {
      // TODO: Navigate to the specific run, possibly on DriverDashboardHomeScreen or AdminActiveRunDetailsScreen if appropriate context
      // For simplicity, maybe pop and the DriverDashboardHomeScreen re-fetches and shows the new active run.
      // Or, if DriverDashboardScreen manages tab changes, navigate to home tab.
      _showFeedbackSnackbar(
          "Tapped on New Run: ${notification.data!['runId']}. Navigation not yet implemented.");
      // Example: Navigator.of(context).popUntil(ModalRoute.withName(DriverDashboardScreen.routeName));
      // This might require the DriverDashboardScreen to observe run assignments.
    } else if (notification.type == 'payout_processed') {
      // Potentially navigate to DriverEarningsScreen if it exists and can show specific payout
      _showFeedbackSnackbar("Payout details: ${notification.body}");
    } else if (notification.type == 'document_expiry_warning') {
      // TODO: Navigate to a document management screen if it exists
      _showFeedbackSnackbar("Document warning: ${notification.body}");
    } else {
      _showFeedbackSnackbar(
          'Notification: ${notification.title}'); // Default action
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

  IconData _getIconForNotificationType(
      String type, ThemeProvider themeProvider) {
    switch (type.toLowerCase()) {
      case 'new_run_assigned':
        return Icons.route_outlined;
      case 'system_alert':
        return Icons.campaign_outlined;
      case 'payout_processed':
        return Icons.account_balance_wallet_outlined;
      case 'document_expiry_warning':
        return Icons.description_outlined;
      case 'order_update': // Generic order update not covered by specific run assignment
        return Icons.receipt_long_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color driverAccentColor = themeProvider.gas2doorTeal;
    bool hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text('My Notifications',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: themeProvider.primaryText),
            onPressed: () => Navigator.of(context).pop()),
        actions: [
          if (_notifications.isNotEmpty && hasUnread)
            TextButton(
                onPressed: _isLoading
                    ? null
                    : () => _handleMarkAllAsRead(themeProvider),
                child: Text("Mark All Read",
                    style: GoogleFonts.inter(
                        color: driverAccentColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 13))),
          if (_notifications.isNotEmpty)
            IconButton(
                icon: Icon(Icons.delete_sweep_outlined,
                    color: themeProvider.secondaryText.withOpacity(0.8),
                    size: 24),
                onPressed: _isLoading
                    ? null
                    : () => _handleClearAllNotifications(themeProvider),
                tooltip: "Clear All Notifications"),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchNotifications(isRefresh: true),
        color: driverAccentColor,
        backgroundColor: themeProvider.cardBackground,
        child: _isLoading && _notifications.isEmpty
            ? _buildLoadingShimmer(themeProvider)
            : _errorMessage != null
                ? _buildErrorState(themeProvider, _errorMessage!)
                : _notifications.isEmpty
                    ? _buildEmptyState(themeProvider)
                    : ListView.separated(
                        padding: const EdgeInsets.all(12.0),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final itemAnimation = Tween<Offset>(
                                  begin: const Offset(0, 0.2), end: Offset.zero)
                              .animate(CurvedAnimation(
                                  parent: _listAnimationController,
                                  curve: Interval(
                                      (0.05 * index).clamp(
                                          0.0, 1.0), // Staggered animation
                                      (0.6 + 0.05 * index).clamp(
                                          0.0, 1.0), // Staggered animation
                                      curve: Curves.easeOutCubic)));
                          return FadeTransition(
                            opacity: _listAnimationController,
                            child: SlideTransition(
                              position: itemAnimation,
                              child: _DriverNotificationCardWidget(
                                notification: notification,
                                themeProvider: themeProvider,
                                driverAccentColor: driverAccentColor,
                                onTap: () =>
                                    _handleNotificationTap(notification),
                                iconData: _getIconForNotificationType(
                                    notification.type, themeProvider),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) => const SizedBox(
                            height: 0), // Cards have their own margin
                      ),
      ),
    );
  }

  Widget _buildLoadingShimmer(ThemeProvider themeProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: 6,
      itemBuilder: (context, index) {
        return CustomCard(
          margin: const EdgeInsets.only(bottom: 10.0),
          color: themeProvider.cardBackground,
          borderRadius: themeProvider.cardBorderRadiusValue,
          elevation: 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    radius: 22,
                    backgroundColor: themeProvider.shimmerBaseColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: MediaQuery.of(context).size.width * 0.5,
                          height: 16,
                          color: themeProvider.shimmerBaseColor,
                          margin: const EdgeInsets.only(bottom: 8)),
                      Container(
                          width: double.infinity,
                          height: 14,
                          color: themeProvider.shimmerBaseColor,
                          margin: const EdgeInsets.only(bottom: 6)),
                      Container(
                          width: MediaQuery.of(context).size.width * 0.3,
                          height: 12,
                          color: themeProvider.shimmerBaseColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                color: themeProvider.errorColor, size: 50),
            const SizedBox(height: 16),
            Text('Error Loading Notifications',
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
              onPressed: () => _fetchNotifications(isRefresh: true),
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
            Icon(Icons.notifications_paused_outlined,
                color: themeProvider.secondaryText.withOpacity(0.5), size: 60),
            const SizedBox(height: 20),
            Text(
              'No Notifications Yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.primaryText),
            ),
            const SizedBox(height: 10),
            Text(
              'Important updates and alerts will appear here.',
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

class _DriverNotificationCardWidget extends StatelessWidget {
  final DriverNotificationItem notification;
  final ThemeProvider themeProvider;
  final Color driverAccentColor; // Pass the driver's accent color
  final VoidCallback onTap;
  final IconData iconData;

  const _DriverNotificationCardWidget({
    required this.notification,
    required this.themeProvider,
    required this.driverAccentColor,
    required this.onTap,
    required this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !notification.isRead;
    final Color cardBg = isUnread
        ? themeProvider.cardBackground
        : themeProvider.cardBackground.withOpacity(themeProvider.isDarkMode
            ? 0.6
            : 0.75); // More subtle for read items
    final Color primaryTextColor = isUnread
        ? themeProvider.primaryText
        : themeProvider.primaryText.withOpacity(0.65);
    final Color secondaryTextColor = isUnread
        ? themeProvider.secondaryText
        : themeProvider.secondaryText.withOpacity(0.65);
    final FontWeight titleFontWeight =
        isUnread ? FontWeight.w600 : FontWeight.w500;

    return CustomCard(
      margin: const EdgeInsets.only(bottom: 10.0),
      color: cardBg,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: isUnread ? 2.0 : 0.5, // Less elevation for read items
      shadowColor: themeProvider.cardShadowColorGlobal
          .withOpacity(isUnread ? 0.3 : 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: themeProvider.cardBorderRadius,
        splashColor: driverAccentColor.withOpacity(0.1),
        highlightColor: driverAccentColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20, // Slightly smaller avatar for notifications
                backgroundColor:
                    (isUnread ? driverAccentColor : themeProvider.secondaryText)
                        .withOpacity(isUnread ? 0.15 : 0.1),
                child: Icon(iconData,
                    size: 20,
                    color: isUnread
                        ? driverAccentColor
                        : themeProvider.secondaryText.withOpacity(0.8)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: titleFontWeight,
                          color: primaryTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: secondaryTextColor,
                          height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8), // Reduced space
                    Text(
                      DateFormat('MMM dd, hh:mm a')
                          .format(notification.timestamp.toLocal()),
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: themeProvider.tertiaryText
                              .withOpacity(isUnread ? 0.8 : 0.6)),
                    ),
                  ],
                ),
              ),
              if (isUnread) ...[
                const SizedBox(width: 10),
                Container(
                  width: 8, height: 8, // Smaller unread dot
                  decoration: BoxDecoration(
                      color: driverAccentColor, shape: BoxShape.circle),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
