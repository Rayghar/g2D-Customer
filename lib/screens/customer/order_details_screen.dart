// lib/screens/customer/order_details_screen.dart
// ADVISORY: This is the final version with the new, more detailed 6-step timeline.
// UPDATE: Standardized to kobo; deliveryFee /100 for display.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logging/logging.dart'; // Added for internal logging
import 'package:sentry_flutter/sentry_flutter.dart'; // Added for Sentry integration

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/feedback_dialog.dart';
import './chat_screen.dart';
import './track_driver_screen.dart'; // Import the TrackDriverScreen
import '../../models/driver_info_for_order.dart'; //
import '../../services/api_service.dart';
import '../../models/order.dart' as app_order;
import './payment_screen.dart'; // Added to support Pay Now button
import '../../providers/order_provider.dart'; // Added to support Pay Now button

// Initialize a logger for this file
final _logger = Logger('OrderDetailsScreen');

class OrderDetailsScreen extends StatefulWidget {
  static const String routeName = '/order_details';
  final String orderId;
  final String customerId;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.customerId,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with TickerProviderStateMixin {
  bool _isCancellingOrder = false;
  bool _feedbackPromptShown = false;

  late AnimationController _entryAnimController;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _logger
        .info('OrderDetailsScreen initialized for order ID: ${widget.orderId}');
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'lifecycle',
        message: 'OrderDetailsScreen initialized',
        data: {'order_id': widget.orderId, 'customer_id': widget.customerId},
        level: SentryLevel.info));

    // Set orderId as a tag for all events related to this screen
    Sentry.configureScope((scope) {
      scope.setTag('order_id', widget.orderId);
      scope.setUser(SentryUser(id: widget.customerId));
    });

    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    // Ask the provider to fetch the data as soon as the screen loads.
    // 'listen: false' is important here because we're in initState.
    Future.microtask(() => Provider.of<OrderProvider>(context, listen: false)
        .fetchOrderDetails(widget.orderId));
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    _logger.info(
        'OrderDetailsScreen disposed for order ID: ${widget.orderId}'); // Log info
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'lifecycle',
        message: 'OrderDetailsScreen disposed',
        data: {'order_id': widget.orderId},
        level: SentryLevel.info)); // Sentry breadcrumb
    super.dispose();
  }

  void _promptForFeedbackIfNeeded(app_order.Order order) {
    if (order.status.toLowerCase() == 'delivered' &&
        order.feedback == null &&
        !_feedbackPromptShown) {
      _logger.info(
          'Prompting for feedback for delivered order: ${order.id}'); // Log info
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'feedback',
          message: 'Prompting for feedback',
          data: {'order_id': order.id},
          level: SentryLevel.info)); // Sentry breadcrumb

      setState(() => _feedbackPromptShown = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return FeedbackDialog(
                orderId: order.id,
                customerId: widget.customerId,
                onFeedbackSubmitted: () {
                  _logger.info(
                      'Feedback submitted, refreshing order details.'); // Log info
                  Sentry.addBreadcrumb(Breadcrumb(
                      category: 'feedback',
                      message: 'Feedback submitted, refreshing order details',
                      data: {'order_id': order.id},
                      level: SentryLevel.info)); // Sentry breadcrumb
                  Provider.of<OrderProvider>(context, listen: false)
                      .fetchOrderDetails(widget.orderId);
                },
              );
            },
          );
        }
      });
    }
  }

  Future<void> _handleInitiateCall(String? phoneNumber) async {
    _logger.info(
        'Attempting to initiate call to phone number: $phoneNumber'); // Log info
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'communication',
        message: 'Attempting to call driver',
        data: {
          'order_id': widget.orderId,
          'phone_number_present': phoneNumber != null && phoneNumber.isNotEmpty
        },
        level: SentryLevel.info)); // Sentry breadcrumb

    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showFeedbackSnackbar("Driver's phone number is not available.",
          isError: true);
      _logger.warning(
          "Driver's phone number is not available for call."); // Log warning
      return;
    }
    HapticFeedback.lightImpact();
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (!await canLaunchUrl(launchUri)) {
        _showFeedbackSnackbar('Could not launch phone dialer.', isError: true);
        _logger.warning(
            'Could not launch phone dialer for $phoneNumber.'); // Log warning
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'communication',
            message: 'Failed to launch phone dialer',
            data: {'phone_number': phoneNumber, 'order_id': widget.orderId},
            level: SentryLevel.warning)); // Sentry breadcrumb
      } else {
        await launchUrl(launchUri);
        _logger.info(
            'Successfully launched phone dialer for $phoneNumber.'); // Log info
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'communication',
            message: 'Phone dialer launched',
            data: {'phone_number': phoneNumber, 'order_id': widget.orderId},
            level: SentryLevel.info)); // Sentry breadcrumb
      }
    } catch (e, st) {
      // Capture stack trace for Sentry
      _showFeedbackSnackbar(
          'Error launching phone dialer: ${e.toString().replaceFirst("Exception: ", "")}',
          isError: true);
      _logger.severe('Exception while launching phone dialer: $e', e,
          st); // Log severe error
      Sentry.captureException(e,
          stackTrace: st,
          hint: Hint.withMap({
            // Send error to Sentry
            'phone_number': phoneNumber,
            'order_id': widget.orderId,
            'action': 'launch_dialer',
          }));
    }
  }

  Future<void> _handleCancelOrder(String orderId) async {
    _logger.info('User initiated order cancellation for order ID: $orderId');
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'order_action',
        message: 'User initiated order cancellation dialog',
        data: {'order_id': orderId},
        level: SentryLevel.info));

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        return AlertDialog(
          backgroundColor: themeProvider.cardBackground,
          title: Text('Confirm Cancellation',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: themeProvider.primaryText)),
          content: Text('Are you sure you want to cancel this order?',
              style: GoogleFonts.inter(color: themeProvider.secondaryText)),
          actions: <Widget>[
            TextButton(
                child: Text('No',
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
                onPressed: () {
                  _logger.info('Order cancellation dialog: No selected.');
                  Sentry.addBreadcrumb(Breadcrumb(
                      category: 'order_action',
                      message: 'Order cancellation dialog dismissed',
                      level: SentryLevel.info));
                  Navigator.of(context).pop(false);
                }),
            TextButton(
                child: Text('Yes, Cancel',
                    style: GoogleFonts.inter(color: themeProvider.errorColor)),
                onPressed: () {
                  _logger.info(
                      'Order cancellation dialog: Yes selected, proceeding to cancel.');
                  Sentry.addBreadcrumb(Breadcrumb(
                      category: 'order_action',
                      message: 'User confirmed order cancellation',
                      data: {'order_id': orderId},
                      level: SentryLevel.info));
                  Navigator.of(context).pop(true);
                }),
          ],
        );
      },
    );

    if (shouldCancel == true) {
      setState(() => _isCancellingOrder = true);
      try {
        final result = await _apiService.cancelOrder(orderId);
        _showFeedbackSnackbar(
            result['message'] ?? 'Order cancelled successfully.',
            isSuccess: true);
        _logger.info(
            'Order $orderId cancelled successfully. Message: ${result['message']}');
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'order_action',
            message: 'Order successfully cancelled via API',
            data: {'order_id': orderId, 'api_response': result['message']},
            level: SentryLevel.info));
        // Refresh data from the provider after cancellation
        Provider.of<OrderProvider>(context, listen: false)
            .fetchOrderDetails(widget.orderId);
      } catch (e, st) {
        _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
            isError: true);
        _logger.severe('Error cancelling order $orderId: $e', e, st);
        Sentry.captureException(e,
            stackTrace: st,
            hint: Hint.withMap({
              'order_id': orderId,
              'customer_id': widget.customerId,
              'action': 'cancel_order',
            }));
      } finally {
        if (mounted) setState(() => _isCancellingOrder = false);
        _logger.info('Order cancellation process finished.');
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'order_action',
            message: 'Order cancellation process finished',
            level: SentryLevel.info));
      }
    }
  }

  void _showFeedbackSnackbar(String message,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    Color backgroundColor;
    if (isError) {
      backgroundColor = themeProvider.errorColor;
      _logger.warning(
          'Snackbar Error: $message'); // Log warnings for user-facing errors
    } else if (isSuccess) {
      backgroundColor = themeProvider.successColor;
      _logger.info(
          'Snackbar Success: $message'); // Log info for user-facing successes
    } else {
      backgroundColor = themeProvider.gas2doorPrimaryBlue;
      _logger.info('Snackbar Info: $message'); // Log info for other messages
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Use a Consumer widget to listen for changes in the OrderProvider
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        // Get the specific order and its loading state from the provider
        final orderData = orderProvider.orders[widget.orderId];
        final isLoading = orderProvider.isLoading(widget.orderId);

        // Your existing Scaffold goes here
        return Scaffold(
          backgroundColor: themeProvider.appSecondaryBackground,
          appBar: AppBar(
            title: Text('Order Details',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            backgroundColor: themeProvider.cardBackground,
            elevation: 1.0,
            leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: themeProvider.primaryText),
                onPressed: () {
                  _logger.info('Back button pressed on OrderDetailsScreen.');
                  Sentry.addBreadcrumb(Breadcrumb(
                      category: 'navigation',
                      message: 'Back button pressed from OrderDetailsScreen',
                      data: {'order_id': widget.orderId},
                      level: SentryLevel.info));
                  Navigator.of(context).pop();
                }),
            actions: [
              IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      color: themeProvider.primaryText),
                  onPressed: () =>
                      orderProvider.fetchOrderDetails(widget.orderId),
                  tooltip: "Refresh")
            ],
          ),
          body: (isLoading && orderData == null)
              ? const Center(child: CircularProgressIndicator())
              : (orderData == null)
                  ? _buildErrorState(themeProvider, "Order could not be found.")
                  : FadeTransition(
                      opacity: _entryAnimController..forward(),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatusAndProgressCard(
                                orderData, themeProvider),
                            const SizedBox(height: 16),
                            _buildItemsOrderedCard(orderData, themeProvider),
                            const SizedBox(height: 16),
                            if (orderData.driver != null)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: _buildDriverInfoCard(orderData.driver!,
                                      orderData, themeProvider)),
                            _buildDeliveryAddressCard(orderData, themeProvider),
                            const SizedBox(height: 16),
                            _buildPricingSummaryCard(orderData, themeProvider),
                            const SizedBox(height: 24),
                            _buildActionButtons(orderData, themeProvider),
                          ],
                        ),
                      ),
                    ),
          bottomNavigationBar: (orderData?.status == 'Pending Payment' &&
                  orderData?.paymentMethod == 'payOnPickup')
              ? _buildPayNowButton(themeProvider, orderData!)
              : null,
        );
      },
    );
  }

  // << NEW WIDGET >>
  Widget _buildPayNowButton(
      ThemeProvider themeProvider, app_order.Order orderData) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: themeProvider.cardBackground,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: CustomButton(
        text:
            'Pay Now (${NumberFormat.currency(locale: 'en_NG', symbol: '₦').format(orderData.grandTotal / 100)})',
        onPressed: () {
          // We navigate to the payment screen. The '.then()' block will automatically
          // execute after the user finishes the payment flow and returns to this screen.
          Navigator.of(context).pushNamed(
            PaymentScreen.routeName,
            arguments: {
              'orderId': orderData.id,
              'amount': orderData.grandTotal,
              'customer': orderData.customer,
              'order': orderData,
            },
          ).then((_) {
            // This code runs AFTER the payment flow is finished.
            // We tell our central provider to fetch the latest details for this order.
            // The screen will then automatically update with the new status, and this button will disappear.
            _logger
                .info('Returned from payment flow, refreshing order details.');
            Provider.of<OrderProvider>(context, listen: false)
                .fetchOrderDetails(widget.orderId);
          });
        },
        color: themeProvider.successColor,
        icon: const Icon(Icons.shield_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Failed to Load Order',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                style: GoogleFonts.inter(
                    color: themeProvider.secondaryText, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            CustomButton(
                text: "Retry",
                onPressed: () {
                  _logger.info('Retry button pressed on error state.');
                  Sentry.addBreadcrumb(Breadcrumb(
                      category: 'error_recovery',
                      message: 'Retry button pressed on error state',
                      data: {'order_id': widget.orderId},
                      level: SentryLevel.info));
                  Provider.of<OrderProvider>(context, listen: false)
                      .fetchOrderDetails(widget.orderId);
                },
                color: themeProvider.gas2doorPrimaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusAndProgressCard(
      app_order.Order order, ThemeProvider themeProvider) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${order.shortOrderId}',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Placed on: ${order.formattedOrderDate}',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: themeProvider.secondaryText)),
            ),
            Divider(color: themeProvider.tertiaryText.withOpacity(0.2)),
            const SizedBox(height: 16),
            _buildVisualTimeline(order, themeProvider),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // NEW: Redesigned timeline with 6 steps and original backend logic
  // =======================================================================
  Widget _buildVisualTimeline(
      app_order.Order order, ThemeProvider themeProvider) {
    // These are the VISUAL steps shown to the customer.
    final timelineSteps = [
      {
        'key': 'Order Placed',
        'title': 'Order Placed',
        'icon': Icons.playlist_add_check_circle_outlined
      },
      {
        'key': 'Processing',
        'title': 'Processing',
        'icon': Icons.hourglass_top_rounded
      },
      {
        'key': 'Driver Assigned',
        'title': 'Driver Assigned',
        'icon': Icons.person_pin_circle_outlined
      },
      {
        'key': 'In Transit',
        'title': 'Refilling/In Transit',
        'icon': Icons.local_gas_station_outlined
      },
      {
        'key': 'Out for Delivery',
        'title': 'Out for Delivery',
        'icon': Icons.local_shipping_outlined
      },
      {
        'key': 'Delivered',
        'title': 'Delivered',
        'icon': Icons.check_circle_outline_rounded
      },
    ];

    // ============================ THIS IS THE MAIN FIX ============================
    // This map CORRECTLY maps the GRANULAR backend/driver statuses to the VISUAL timeline index.
    // The keys MUST exactly match the status strings from the backend and driver app.
    final Map<String, int> statusMap = {
      // Initial States -> Step 0
      'Pending Payment': 0,
      'Awaiting Driver Arrival': 0,
      'Order Placed': 0,

      // Processing States -> Step 1
      'Processing': 1,
      'DRIVER_ENROUTE_PICKUP': 1, // Driver is going to the customer

      // Driver Assigned State -> Step 2
      'Driver Assigned': 2,

      // In Transit/Refilling States -> Step 3
      'PICKED_UP_ENROUTE_STATION': 3,
      'CYLINDER_REFILLING': 3,

      // Out for Delivery State -> Step 4
      'Out for Delivery': 4, // From order.model.js status enum
      'OUT_FOR_DELIVERY':
          4, // From driver_order_details_screen.dart status update

      // Final States -> Step 5
      'Delivered': 5,
      'DELIVERED': 5,
      'Customer Unavailable': 5,
      'Issue Reported': 5,
      'Payment Failed': 5,
      'Canceled by Customer': 5,
      'Canceled by Admin': 5,
      'Canceled': 5,
    };
    // ==============================================================================

    String currentOrderStatus = order.status;
    int currentStepIndex = statusMap[currentOrderStatus] ??
        0; // Default to the first step if unknown

    // Logic for handling canceled/terminal orders
    if (currentOrderStatus.toLowerCase().contains('cancel') ||
        currentOrderStatus == 'Customer Unavailable' ||
        currentOrderStatus == 'Issue Reported' ||
        currentOrderStatus == 'Payment Failed') {
      return _buildTimelineStep(
          icon: _getStatusVisuals(order.status, themeProvider)['icon'],
          title: order.formattedStatus,
          subtitle: "This order has reached a final state.",
          themeProvider: themeProvider,
          isCurrent: true,
          isFirst: true,
          isLast: true,
          isCompleted: false);
    }

    return Column(
      children: List.generate(timelineSteps.length, (index) {
        final step = timelineSteps[index];
        final bool isCompleted = index < currentStepIndex;
        final bool isCurrent = index == currentStepIndex;

        String subtitle = "Pending";
        if (isCompleted) {
          subtitle = "${step['title'] as String} Completed";
        }
        if (isCurrent) {
          subtitle = order.formattedStatus;
        }

        return _buildTimelineStep(
          icon: step['icon'] as IconData,
          title: step['title'] as String,
          subtitle: subtitle,
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isFirst: index == 0,
          isLast: index == timelineSteps.length - 1,
          themeProvider: themeProvider,
        );
      }),
    );
  }

  Widget _buildTimelineStep(
      {required IconData icon,
      required String title,
      required String subtitle,
      required bool isFirst,
      required bool isLast,
      required bool isCompleted,
      required bool isCurrent,
      required ThemeProvider themeProvider}) {
    final Color activeColor = themeProvider.gas2doorTeal;
    final Color inactiveColor = themeProvider.tertiaryText.withOpacity(0.4);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                  width: 2,
                  height: 4,
                  color: isFirst
                      ? Colors.transparent
                      : (isCompleted || isCurrent
                          ? activeColor
                          : inactiveColor)),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted || isCurrent ? activeColor : inactiveColor,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              Expanded(
                  child: Container(
                      width: 2,
                      color: isLast
                          ? Colors.transparent
                          : (isCompleted ? activeColor : inactiveColor))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0.0 : 24.0, top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.w500,
                          fontSize: 15,
                          color: isCurrent
                              ? activeColor
                              : themeProvider.primaryText)),
                  if (isCurrent || isCompleted)
                    Text(subtitle,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: themeProvider.secondaryText)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildItemsOrderedCard(
      app_order.Order order, ThemeProvider themeProvider) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦'); // Changed symbol
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items Ordered (${order.items.length})',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: order.items.length,
              itemBuilder: (context, index) {
                final item = order.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.propane_tank_outlined,
                          color: themeProvider.gas2doorTeal, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text('${item.quantity}x ${item.productName}',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: themeProvider.primaryText,
                                  fontWeight: FontWeight.w500))),
                      Text(
                          currencyFormat
                              .format((item.unitPrice * item.quantity) / 100),
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.primaryText)),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) => Divider(
                  color: themeProvider.tertiaryText.withOpacity(0.2),
                  height: 1,
                  thickness: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryAddressCard(
      app_order.Order order, ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery Address',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined,
                    color: themeProvider.gas2doorPrimaryBlue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(order.deliveryAddressSnapshot.fullAddress,
                        style: GoogleFonts.inter(
                            fontSize: 14.5,
                            color: themeProvider.secondaryText,
                            height: 1.4))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSummaryCard(
      app_order.Order order, ThemeProvider themeProvider) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦'); // Changed symbol
    double totalAmount =
        (order.itemsSubtotal / 100) + (order.deliveryFee / 100);
    if (order.serviceFeeAmount > 0) {
      totalAmount += (order.serviceFeeAmount / 100);
    }
    if (order.vatAmount > 0) {
      totalAmount += (order.vatAmount / 100);
    }
    if (order.discountAmount > 0) {
      totalAmount -= (order.discountAmount / 100);
    }
    if (order.walletAmountUsed > 0) {
      totalAmount -= (order.walletAmountUsed / 100);
    }

    // FIX: Removed condition for _isStillVerifying as it's not present here.
    // The finalAmountPaid is the source of truth for total paid.
    if (order.finalAmountPaid > 0) {
      totalAmount = order.finalAmountPaid / 100;
    }

    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Summary',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            _buildDetailRow(
                "Items Subtotal:",
                currencyFormat.format(order.itemsSubtotal / 100),
                themeProvider),
            _buildDetailRow(
                "VAT:",
                '+ ${currencyFormat.format(order.vatAmount / 100)}',
                themeProvider),
            _buildDetailRow(
                "Service Fee:",
                '+ ${currencyFormat.format(order.serviceFeeAmount / 100)}',
                themeProvider),
            _buildDetailRow(
                "Delivery Fee${order.isExpressDelivery ? ' (Express)' : ''}:",
                '+ ${currencyFormat.format(order.deliveryFee / 100)}', // FIX: /100 for kobo
                themeProvider),
            if (order.discountAmount > 0)
              _buildDetailRow(
                  "Discount Applied:",
                  '- ${currencyFormat.format(order.discountAmount / 100)}',
                  themeProvider,
                  isDiscount: true),
            if (order.walletAmountUsed > 0)
              _buildDetailRow(
                  "Wallet Deduction:",
                  '- ${currencyFormat.format(order.walletAmountUsed / 100)}',
                  themeProvider,
                  isDiscount: true),
            Divider(
                height: 24,
                thickness: 0.5,
                color: themeProvider.tertiaryText.withOpacity(0.4)),
            _buildDetailRow('Total Payable:',
                currencyFormat.format(totalAmount), themeProvider,
                isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      String label, String value, ThemeProvider themeProvider,
      {bool isTotal = false, bool isDiscount = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: isTotal ? 16 : 14,
                  color: themeProvider.secondaryText,
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: isTotal ? 17 : 15,
                  color: valueColor ??
                      (isDiscount
                          ? themeProvider.successColor
                          : themeProvider.primaryText),
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard(DriverInfoForOrder driver, app_order.Order order,
      ThemeProvider themeProvider) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Driver',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        themeProvider.gas2doorTeal.withOpacity(0.15),
                    child: Icon(Icons.person_rounded,
                        size: 30, color: themeProvider.gas2doorTeal)),
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
                      if (driver.vehicleType != null &&
                          driver.licensePlate != null)
                        Text('${driver.vehicleType} - ${driver.licensePlate}',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: themeProvider.secondaryText)),
                    ],
                  ),
                ),
                if (driver.phone != null && driver.phone!.isNotEmpty)
                  IconButton(
                      icon: Icon(Icons.call_outlined,
                          color: themeProvider.gas2doorPrimaryBlue, size: 26),
                      onPressed: () => _handleInitiateCall(driver.phone),
                      tooltip: "Call Driver"),
                IconButton(
                    icon: Icon(Icons.chat_bubble_outline_rounded,
                        color: themeProvider.gas2doorPrimaryBlue, size: 26),
                    onPressed: () async {
                      HapticFeedback.lightImpact();

                      if (order.customer?.id == null) {
                        _showFeedbackSnackbar(
                            "Cannot initiate chat: Your user ID is missing.",
                            isError: true);
                        return;
                      }

                      try {
                        final chatDetails =
                            await _apiService.initiateChatSession(
                          orderId: order.id,
                          // <<-- FIX: Added the required 'senderId' parameter -->>
                          senderId: order.customer!.id,
                          recipientId: driver.id,
                        );

                        if (mounted) {
                          Navigator.of(context, rootNavigator: true)
                              .pushNamed(ChatScreen.routeName, arguments: {
                            'orderId': chatDetails['chatId'],
                            'currentUserId': order.customer!.id,
                            'recipientId': driver.id,
                            'recipientName': driver.name,
                            'recipientPhoneNumber': driver.phone,
                            // 'recipientPhotoUrl' can be added if available on the driver model
                          });
                        }
                      } catch (e) {
                        _showFeedbackSnackbar(
                            e.toString().replaceFirst("Exception: ", ""),
                            isError: true);
                        Sentry.captureException(e,
                            stackTrace: StackTrace.current);
                      }
                    },
                    tooltip: "Chat with Driver")
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      app_order.Order order, ThemeProvider themeProvider) {
    List<Widget> buttons = [];
    String currentOrderStatus = order.status;

    if (currentOrderStatus == "Delivered" && order.feedback == null) {
      buttons.add(CustomButton(
        text: 'Submit Feedback',
        onPressed: () {
          _logger.info(
              'User pressed Submit Feedback button for order: ${order.id}'); // Log info
          Sentry.addBreadcrumb(Breadcrumb(
              category: 'ui_action',
              message: 'Submit Feedback button pressed',
              data: {'order_id': order.id},
              level: SentryLevel.info)); // Sentry breadcrumb
          _promptForFeedbackIfNeeded(order);
        },
        color: themeProvider.primaryActionColor,
        icon: Icon(Icons.rate_review_outlined, color: Colors.white),
      ));
    }

    /*if (currentOrderStatus == 'Driver Assigned' ||
        currentOrderStatus == 'Processing' ||
        currentOrderStatus == 'Out for Delivery') {
      buttons.add(
        CustomButton(
          text: 'Track My Order',
          onPressed: () {
            HapticFeedback.lightImpact();
            _logger.info(
                'User pressed Track My Order button for order: ${order.id}'); // Log info
            Sentry.addBreadcrumb(Breadcrumb(
                category: 'ui_action',
                message: 'Track My Order button pressed',
                data: {'order_id': order.id},
                level: SentryLevel.info)); // Sentry breadcrumb
            Navigator.of(context).pushNamed(
              TrackDriverScreen.routeName,
              arguments: {
                'orderId': order.id,
                'customerId': widget.customerId,
              },
            );
          },
          color: themeProvider.gas2doorTeal,
          icon: Icon(Icons.location_searching_rounded,
              color: Colors.white), // Using white for better contrast
        ),
      );
    }*/

    if (currentOrderStatus == 'Pending Payment' ||
        currentOrderStatus == 'Order Placed' ||
        currentOrderStatus == 'Processing') {
      buttons.add(CustomButton(
          text: 'Cancel Order',
          onPressed:
              _isCancellingOrder ? null : () => _handleCancelOrder(order.id),
          color: themeProvider.errorColor.withOpacity(0.15),
          textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600, color: themeProvider.errorColor),
          icon: Icon(Icons.cancel_outlined, color: themeProvider.errorColor),
          elevation: 0));
    }

    buttons.add(
      Padding(
        padding: EdgeInsets.only(top: buttons.isNotEmpty ? 12.0 : 0.0),
        child: TextButton.icon(
            icon: Icon(Icons.support_agent_outlined,
                color: themeProvider.secondaryText),
            label: Text('Get Help / Support',
                style: GoogleFonts.inter(color: themeProvider.secondaryText)),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showFeedbackSnackbar('Support channel not yet implemented.');
              Sentry.addBreadcrumb(Breadcrumb(
                  category: 'ui_action',
                  message: 'Support button pressed',
                  data: {'order_id': order.id},
                  level: SentryLevel.info));
            }),
      ),
    );

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons
            .map((button) => Padding(
                padding: const EdgeInsets.only(top: 14.0), child: button))
            .toList());
  }

  Color _getStatusColor(String status, ThemeProvider themeProvider) {
    if (status == 'Delivered') {
      return themeProvider.successColor;
    } else if (status.contains('Canceled')) {
      return themeProvider.errorColor;
    } else if (status == 'Order Placed' ||
        status == 'Processing' ||
        status == 'Driver Assigned' ||
        status == 'Out for Delivery' ||
        status == 'Customer Unavailable' ||
        status == 'Issue Reported') {
      return themeProvider.warningColor;
    } else if (status == 'Pending Payment') {
      return themeProvider.secondaryText.withOpacity(0.8);
    } else if (status.contains('Failed') || status.contains('Discrepancy')) {
      return themeProvider.errorColor;
    }
    return themeProvider.secondaryText;
  }

  // This helper method determines the color and icon for a given status
  Map<String, dynamic> _getStatusVisuals(
      String status, ThemeProvider themeProvider) {
    // << MODIFIED: Updated to handle the unified status list >>
    if (status == 'Delivered') {
      return {'color': themeProvider.successColor, 'icon': Icons.check_circle};
    } else if (status.contains('Canceled')) {
      return {'color': themeProvider.errorColor, 'icon': Icons.cancel};
    } else if (status == 'Out for Delivery') {
      return {
        'color': themeProvider.warningColor,
        'icon': Icons.local_shipping
      };
    } else if (status == 'Processing' || status == 'Driver Assigned') {
      return {
        'color': themeProvider.warningColor,
        'icon': Icons.hourglass_top_rounded
      };
    } else if (status == 'Customer Unavailable') {
      return {
        'color': themeProvider.errorColor,
        'icon': Icons.person_off_outlined
      };
    } else {
      // Covers Pending Payment, Awaiting Driver Arrival, Order Placed
      return {
        'color': themeProvider.secondaryText.withOpacity(0.8),
        'icon': Icons.pending_actions_outlined
      };
    }
  }
}
