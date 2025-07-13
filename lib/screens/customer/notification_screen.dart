// File: lib/screens/customer/notification_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './order_details_screen.dart';
import './promotion_details_screen.dart' show PromotionDetailsScreen;
import '../../models/deal_model.dart';
import '../../models/notification.dart' as app_notification_model;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class IntegratedNotificationService {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  Future<List<app_notification_model.NotificationModel>>
      getNotifications() async {
    String? userId = await _authService.getUserId();
    if (userId == null) {
      throw Exception("User not authenticated. Cannot fetch notifications.");
    }
    return await _apiService.getNotifications();
  }

  Future<void> markAsRead(String notificationId) async {
    await _apiService.markNotificationAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    await _apiService.markAllNotificationsAsRead();
  }

  Future<void> clearAllNotifications() async {
    await _apiService.clearAllNotifications();
  }
}

class NotificationScreen extends StatefulWidget {
  static const String routeName = '/notifications';
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<app_notification_model.NotificationModel> _notifications = [];
  String? _errorMessage;
  String? _currentUserId;

  late AnimationController _listAnimationController;
  final IntegratedNotificationService _notificationService =
      IntegratedNotificationService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _loadCurrentUserAndFetchNotifications();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserAndFetchNotifications() async {
    try {
      final userId = await _authService.getUserId();
      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
      });
      if (userId != null) {
        await _fetchNotifications();
      } else {
        throw Exception("User not authenticated. Cannot load notifications.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
        });
      }
    }
  }

  Future<void> _fetchNotifications({bool isRefresh = false}) async {
    if (!mounted || _currentUserId == null) return;

    if (!isRefresh && _notifications.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (isRefresh) {
      setState(() => _isLoading = true);
    }

    try {
      final fetchedNotifications =
          await _notificationService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = fetchedNotifications;
          _isLoading = false;
          _errorMessage = null;
        });
        if (_notifications.isNotEmpty &&
            (isRefresh ||
                _listAnimationController.status != AnimationStatus.completed)) {
          _listAnimationController.reset();
          _listAnimationController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Failed to load notifications: ${e.toString().replaceFirst("Exception:", "")}";
        });
      }
    }
  }

  Future<void> _markAsRead(int index) async {
    HapticFeedback.lightImpact();
    if (!mounted || _currentUserId == null) return;
    if (index < _notifications.length && !_notifications[index].isRead) {
      final notificationId = _notifications[index].id;
      final originalReadStatus = _notifications[index].isRead;
      setState(() => _notifications[index].isRead = true);

      try {
        await _notificationService.markAsRead(notificationId);
      } catch (e) {
        if (mounted) {
          setState(() => _notifications[index].isRead = originalReadStatus);
          _showFeedbackSnackbar("Failed to mark as read. Please try again.",
              isError: true);
        }
      }
    }
  }

  void _handleNotificationTap(
      app_notification_model.NotificationModel notification) {
    if (_currentUserId == null) {
      _showFeedbackSnackbar("Cannot process notification: User not identified.",
          isError: true);
      return;
    }

    final index = _notifications.indexWhere((n) => n.id == notification.id);
    if (index != -1 && !_notifications[index].isRead) {
      _markAsRead(index);
    }

    final String orderIdFromData =
        notification.data?['orderId']?.toString() ?? '';
    final String promotionIdFromData =
        notification.data?['promotionId']?.toString() ?? '';

    if ((notification.type?.toLowerCase() == 'order_update' ||
            notification.type?.toLowerCase() == 'payment_success') &&
        orderIdFromData.isNotEmpty) {
      Navigator.of(context, rootNavigator: true).pushNamed(
        OrderDetailsScreen.routeName,
        arguments: {
          'orderId': orderIdFromData,
          'customerId': _currentUserId!,
        },
      );
    } else if (notification.type?.toLowerCase() == 'promotion' &&
        promotionIdFromData.isNotEmpty) {
      try {
        if (notification.data == null) {
          throw Exception("Promotion data missing in notification.");
        }
        final DealModel promoDeal =
            DealModel.fromBackendPromotion(notification.data!);
        Navigator.of(context, rootNavigator: true)
            .pushNamed(PromotionDetailsScreen.routeName, arguments: {
          'promotion': promoDeal,
          'customerId': _currentUserId!,
        });
      } catch (e) {
        print(
            "Error creating DealModel from notification data or navigating: $e");
        _showFeedbackSnackbar(
            'Could not open promotion details. Data may be incomplete.',
            isError: true);
      }
    } else {
      _showFeedbackSnackbar('Notification: ${notification.title}');
    }
  }

  Future<void> _handleMarkAllAsRead() async {
    HapticFeedback.mediumImpact();
    if (_currentUserId == null) return;

    final List<app_notification_model.NotificationModel> originalNotifications =
        List.from(_notifications);
    setState(() {
      for (var n in _notifications) {
        n.isRead = true;
      }
    });

    try {
      await _notificationService.markAllAsRead();
      if (mounted) {
        _showFeedbackSnackbar("All notifications marked as read.",
            isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notifications = originalNotifications;
        });
        _showFeedbackSnackbar("Failed to mark all as read.", isError: true);
      }
    }
  }

  Future<void> _handleClearAllNotifications() async {
    HapticFeedback.mediumImpact();
    if (_currentUserId == null) return;

    final List<app_notification_model.NotificationModel> originalNotifications =
        List.from(_notifications);
    setState(() {
      _notifications.clear();
    });

    try {
      await _notificationService.clearAllNotifications();
      if (mounted) {
        _showFeedbackSnackbar("All notifications cleared.", isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notifications = originalNotifications;
        });
        _showFeedbackSnackbar("Failed to clear notifications.", isError: true);
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        margin: const EdgeInsets.all(12.0),
      ),
    );
  }

  IconData _getIconForNotificationType(
      String? type, ThemeProvider themeProvider) {
    // Made type nullable
    switch (type?.toLowerCase()) {
      // Used null-safe operator
      case 'order_update':
        return Icons.local_shipping_outlined;
      case 'payment_success':
        return Icons.check_circle_outline_rounded;
      case 'promotion':
        return Icons.local_offer_outlined;
      case 'system_alert':
        return Icons.warning_amber_rounded;
      case 'new_run':
        return Icons.route_outlined;
      case 'document_update':
        return Icons.file_present_outlined;
      case 'payout_processed':
        return Icons.paid_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text('Notifications',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: themeProvider.primaryText),
                onPressed: () => Navigator.of(context).pop())
            : null,
        actions: [
          if (_notifications.isNotEmpty && hasUnread)
            TextButton(
                onPressed: _isLoading ? null : _handleMarkAllAsRead,
                child: Text("Mark All Read",
                    style: GoogleFonts.inter(
                        color: _isLoading
                            ? themeProvider.secondaryText
                            : themeProvider.gas2doorPrimaryBlue,
                        fontWeight: FontWeight.w500,
                        fontSize: 13))),
          if (_notifications.isNotEmpty)
            IconButton(
                icon: Icon(Icons.delete_sweep_outlined,
                    color: themeProvider.secondaryText.withOpacity(0.8)),
                onPressed: _isLoading ? null : _handleClearAllNotifications,
                tooltip: "Clear All Notifications"),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchNotifications(isRefresh: true),
        color: themeProvider.gas2doorPrimaryBlue,
        backgroundColor: themeProvider.cardBackground,
        child: _buildBody(themeProvider),
      ),
    );
  }

  Widget _buildBody(ThemeProvider themeProvider) {
    if (_isLoading && _notifications.isEmpty)
      return _buildLoadingShimmer(themeProvider);
    if (_errorMessage != null) return _buildErrorState(themeProvider);
    if (_notifications.isEmpty) return _buildEmptyState(themeProvider);

    return ListView.separated(
      padding: const EdgeInsets.all(12.0),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        final itemAnimation =
            Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: _listAnimationController,
                    curve: Interval((0.1 * index).clamp(0.0, 1.0),
                        (0.5 + 0.1 * index).clamp(0.0, 1.0),
                        curve: Curves.easeOutCubic)));

        return FadeTransition(
          opacity:
              _listAnimationController, // Assuming _listAnimationController is an Animation<double> or similar
          child: SlideTransition(
            position: itemAnimation,
            child: _NotificationCardWidget(
              // Renamed from _NotificationItemWidget
              notification: notification,
              themeProvider: themeProvider,
              onTap: () => _handleNotificationTap(notification),
              iconData:
                  _getIconForNotificationType(notification.type, themeProvider),
            ),
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 0),
    );
  }

  Widget _buildLoadingShimmer(ThemeProvider themeProvider) {
    /* ... as provided in your file ... */ return ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: 5,
        itemBuilder: (context, index) => CustomCard(
            margin: const EdgeInsets.only(bottom: 10),
            color: themeProvider.cardBackground,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [
                _buildSkeletonLine(
                    width: 44,
                    height: 44,
                    themeProvider: themeProvider,
                    borderRadius: 22),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _buildSkeletonLine(
                          width: MediaQuery.of(context).size.width * 0.5,
                          height: 14,
                          themeProvider: themeProvider),
                      const SizedBox(height: 8),
                      _buildSkeletonLine(
                          width: MediaQuery.of(context).size.width * 0.7,
                          height: 12,
                          themeProvider: themeProvider),
                      const SizedBox(height: 4),
                      _buildSkeletonLine(
                          width: MediaQuery.of(context).size.width * 0.3,
                          height: 10,
                          themeProvider: themeProvider),
                    ]))
              ]),
            )));
  }

  Widget _buildSkeletonLine(
      {required double width,
      required double height,
      required ThemeProvider themeProvider,
      double borderRadius = 4}) {
    /* ... */ return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? Colors.grey[700]!.withOpacity(0.6)
                : Colors.grey[300]!,
            borderRadius: BorderRadius.circular(borderRadius)));
  }

  Widget _buildErrorState(ThemeProvider themeProvider) {
    /* ... as provided in your file ... */ return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                color: themeProvider.secondaryText.withOpacity(0.5), size: 60),
            const SizedBox(height: 20),
            Text(_errorMessage ?? 'Could Not Load Notifications',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 10),
            Text('Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: themeProvider.secondaryText.withOpacity(0.9))),
            const SizedBox(height: 24),
            CustomButton(
                text: "Retry",
                onPressed: () => _fetchNotifications(isRefresh: true),
                color: themeProvider.gas2doorPrimaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider) {
    /* ... as provided in your file ... */ return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_paused_outlined,
                color: themeProvider.secondaryText.withOpacity(0.5), size: 60),
            const SizedBox(height: 20),
            Text('No New Notifications',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 10),
            Text(
                'You\'re all caught up! We\'ll let you know when there\'s something new.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: themeProvider.secondaryText.withOpacity(0.9))),
          ],
        ),
      ),
    );
  }
}

// Renamed from _NotificationItemWidget to avoid potential conflicts
class _NotificationCardWidget extends StatelessWidget {
  final app_notification_model.NotificationModel notification;
  final ThemeProvider themeProvider;
  final VoidCallback onTap;
  final IconData iconData;

  const _NotificationCardWidget({
    // Removed Key? key to avoid conflict if super.key isn't used
    required this.notification,
    required this.themeProvider,
    required this.onTap,
    required this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !notification.isRead;
    final Color cardBg = isUnread
        ? themeProvider.cardBackground
        : themeProvider.cardBackground
            .withOpacity(themeProvider.isDarkMode ? 0.5 : 0.7);
    final Color primaryTextColor = isUnread
        ? themeProvider.primaryText
        : themeProvider.primaryText.withOpacity(0.7);
    final Color secondaryTextColor = isUnread
        ? themeProvider.secondaryText
        : themeProvider.secondaryText.withOpacity(0.7);
    final FontWeight titleFontWeight =
        isUnread ? FontWeight.w600 : FontWeight.w500;

    return CustomCard(
      margin: const EdgeInsets.only(bottom: 10.0),
      color: cardBg,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: isUnread ? 2.5 : 1.0,
      shadowColor:
          themeProvider.cardShadowColorGlobal.withOpacity(isUnread ? 0.4 : 0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: themeProvider.cardBorderRadius,
        splashColor: themeProvider.gas2doorPrimaryBlue.withOpacity(0.1),
        highlightColor: themeProvider.gas2doorPrimaryBlue.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: (isUnread
                        ? themeProvider.gas2doorPrimaryBlue
                        : themeProvider.secondaryText)
                    .withOpacity(isUnread ? 0.15 : 0.1),
                child: Icon(iconData,
                    size: 22,
                    color: isUnread
                        ? themeProvider.gas2doorPrimaryBlue
                        : themeProvider.secondaryText),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: titleFontWeight,
                          color: primaryTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Text(notification.body,
                      style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: secondaryTextColor,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Text(
                      DateFormat('MMM dd, yyyy hh:mm a').format(notification
                          .timestamp
                          .toLocal()), // Standardized date format
                      style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: themeProvider.tertiaryText
                              .withOpacity(isUnread ? 0.9 : 0.7))),
                ],
              )),
              if (isUnread) ...[
                const SizedBox(width: 10),
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: themeProvider.gas2doorTeal,
                        shape: BoxShape.circle)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
