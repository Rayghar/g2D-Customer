// File: lib/screens/admin/admin_order_details_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/input.dart';
import '../../services/api_service.dart';
import '../../models/admin/admin_order_detail_model.dart';
import '../../models/admin/admin_run_management_model.dart'
    show AvailableDriverForMap;
import './admin_customer_details_screen.dart';
import './admin_driver_details_screen.dart';

class AdminOrderDetailsScreen extends StatefulWidget {
  static const String routeName = '/admin_order_details';
  final String orderId;

  const AdminOrderDetailsScreen({super.key, required this.orderId});

  @override
  State<AdminOrderDetailsScreen> createState() =>
      _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  AdminOrderDetailModel? _orderData;
  String? _errorMessage;

  bool _isUpdatingStatus = false;
  bool _isAssigningDriver = false;
  bool _isAddingNote = false;
  final TextEditingController _adminNoteController = TextEditingController();

  late AnimationController _entryAnimController;

  final List<String> _orderStatusOptions = [
    "Order Placed",
    "Order Confirmed",
    "Processing",
    "Driver Assigned",
    "Out for Delivery",
    "Delivered",
    "Cancelled",
    "Payment Pending",
    "Payment Failed",
    "Refunded"
  ];

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fetchOrderDetails();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    _adminNoteController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrderDetails({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final fetchedData =
          await _apiService.adminGetOrderDetails(widget.orderId);
      if (mounted) {
        setState(() {
          _orderData = fetchedData;
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
              "Failed to load order details: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  Future<void> _handleUpdateOrderStatus(String newStatus) async {
    HapticFeedback.mediumImpact();
    if (!mounted || _orderData == null) return;
    setState(() => _isUpdatingStatus = true);

    try {
      await _apiService.adminUpdateOrderStatus(widget.orderId, newStatus);
      if (mounted) {
        _showFeedbackSnackbar('Order status updated to "$newStatus".');
        _fetchOrderDetails(isRefresh: true); // Refresh data from source
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

  Future<void> _handleAssignDriver() async {
    HapticFeedback.lightImpact();
    setState(() => _isAssigningDriver = true);
    try {
      final availableDrivers =
          await _apiService.adminGetAvailableDrivers(); // Use actual API call
      if (!mounted) return;

      if (availableDrivers.isEmpty) {
        _showFeedbackSnackbar('No drivers currently available for assignment.',
            isError: true);
        setState(() => _isAssigningDriver = false);
        return;
      }

      AvailableDriverForMap? selectedDriver = // Use actual model
          await showDialog<AvailableDriverForMap>(
        context: context,
        builder: (BuildContext dialogContext) {
          final themeProvider =
              Provider.of<ThemeProvider>(dialogContext, listen: false);
          return AlertDialog(
            backgroundColor: themeProvider.cardBackground,
            title: Text('Select Driver',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableDrivers.length,
                itemBuilder: (BuildContext context, int index) {
                  final driver = availableDrivers[index];
                  return ListTile(
                    title: Text(driver.name,
                        style: GoogleFonts.inter(
                            color: themeProvider.primaryText)),
                    subtitle: Text(
                        'Online: ${driver.isAvailableOnline ? "Yes" : "No"}', // Adjust according to AvailableDriverForMap fields
                        style: GoogleFonts.inter(
                            color: themeProvider.secondaryText, fontSize: 12)),
                    onTap: () => Navigator.of(dialogContext).pop(driver),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                  child: Text('Cancel',
                      style: GoogleFonts.inter(
                          color: themeProvider.secondaryText)),
                  onPressed: () => Navigator.of(dialogContext).pop())
            ],
          );
        },
      );

      if (selectedDriver != null && mounted) {
        await _apiService.adminAssignDriver(
            // Use actual API call
            widget.orderId,
            selectedDriver.id);
        if (mounted) {
          _showFeedbackSnackbar(
              'Driver ${selectedDriver.name} assigned successfully.');
          _fetchOrderDetails(
              isRefresh: true); // Refresh to get updated driver info
        }
      }
    } catch (e) {
      if (mounted)
        _showFeedbackSnackbar(
            'Error: ${e.toString().replaceFirst("Exception: ", "")}',
            isError: true);
    } finally {
      if (mounted) setState(() => _isAssigningDriver = false);
    }
  }

  Future<void> _handleAddAdminNote() async {
    HapticFeedback.mediumImpact();
    final noteText = _adminNoteController.text.trim();
    if (noteText.isEmpty) {
      _showFeedbackSnackbar('Note cannot be empty.', isError: true);
      return;
    }
    setState(() => _isAddingNote = true);

    try {
      await _apiService.adminAddNoteToOrder(
          widget.orderId, noteText); // Use actual API call
      if (mounted) {
        _showFeedbackSnackbar('Admin note added successfully.');
        _adminNoteController.clear(); // Clear the text field after adding
        _fetchOrderDetails(isRefresh: true); // Refresh to see the new note
      }
    } catch (e) {
      if (mounted)
        _showFeedbackSnackbar(
            'Error: ${e.toString().replaceFirst("Exception: ", "")}',
            isError: true);
    } finally {
      if (mounted) setState(() => _isAddingNote = false);
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

  Future<String?> _showStatusUpdateDialog(
      ThemeProvider themeProvider, String currentStatus) async {
    return await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        String? tempSelectedStatus =
            currentStatus; // For stateful selection in dialog
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: themeProvider.cardBackground,
            title: Text('Update Order Status',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _orderStatusOptions.length,
                itemBuilder: (context, index) {
                  final statusOption = _orderStatusOptions[index];
                  return RadioListTile<String>(
                    title: Text(statusOption,
                        style: GoogleFonts.inter(
                            color: themeProvider.primaryText)),
                    value: statusOption,
                    groupValue: tempSelectedStatus,
                    onChanged: (String? value) {
                      setDialogState(() {
                        // Use setDialogState for dialog's internal state
                        tempSelectedStatus = value;
                      });
                      // Optionally pop immediately on selection, or require a confirm button
                      Navigator.of(dialogContext).pop(value);
                    },
                    activeColor: themeProvider.gas2doorPrimaryBlue,
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Cancel',
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              // Optional: Add a confirm button if you don't pop on RadioListTile change
              // TextButton(
              //   child: Text('Confirm', style: GoogleFonts.inter(color: themeProvider.gas2doorPrimaryBlue, fontWeight: FontWeight.bold)),
              //   onPressed: () => Navigator.of(dialogContext).pop(tempSelectedStatus),
              // ),
            ],
          );
        });
      },
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
        title: Text(
          _isLoading
              ? 'Loading Order...'
              : 'Order #${_orderData?.shortOrderId ?? widget.orderId.substring(widget.orderId.length - 6)}',
          style: GoogleFonts.inter(
              color: themeProvider.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: 17),
        ),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: themeProvider.primaryText),
            onPressed: () => Navigator.of(context).pop()),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: adminAccentColor))
          : _orderData == null || _errorMessage != null
              ? _buildErrorState(themeProvider)
              : FadeTransition(
                  opacity: _entryAnimController,
                  child: RefreshIndicator(
                    // Added RefreshIndicator for pull-to-refresh
                    onRefresh: () => _fetchOrderDetails(isRefresh: true),
                    color: adminAccentColor,
                    child: SingleChildScrollView(
                      physics:
                          const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(0, 0.1),
                                      end: Offset.zero)
                                  .animate(CurvedAnimation(
                                      parent: _entryAnimController,
                                      curve: Curves.easeOut)),
                              child: _buildOrderOverviewCard(
                                  _orderData!, themeProvider)),
                          const SizedBox(height: 16),
                          SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(0, 0.1),
                                      end: Offset.zero)
                                  .animate(CurvedAnimation(
                                      parent: _entryAnimController,
                                      curve: const Interval(0.1, 1.0,
                                          curve: Curves.easeOut))),
                              child: _buildItemsOrderedCard(
                                  _orderData!, themeProvider)),
                          const SizedBox(height: 16),
                          SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(0, 0.1),
                                      end: Offset.zero)
                                  .animate(CurvedAnimation(
                                      parent: _entryAnimController,
                                      curve: const Interval(0.2, 1.0,
                                          curve: Curves.easeOut))),
                              child: _buildDeliveryInfoCard(
                                  _orderData!, themeProvider)),
                          const SizedBox(height: 16),
                          SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(0, 0.1),
                                      end: Offset.zero)
                                  .animate(CurvedAnimation(
                                      parent: _entryAnimController,
                                      curve: const Interval(0.3, 1.0,
                                          curve: Curves.easeOut))),
                              child: _buildPricingSummaryCard(
                                  _orderData!, themeProvider)),
                          const SizedBox(height: 16),
                          if (_orderData!.statusHistory.isNotEmpty) ...[
                            SlideTransition(
                                position: Tween<Offset>(
                                        begin: const Offset(0, 0.1),
                                        end: Offset.zero)
                                    .animate(CurvedAnimation(
                                        parent: _entryAnimController,
                                        curve: const Interval(0.4, 1.0,
                                            curve: Curves.easeOut))),
                                child: _buildOrderStatusHistoryCard(
                                    _orderData!, themeProvider)),
                            const SizedBox(height: 16),
                          ],
                          SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(0, 0.1),
                                      end: Offset.zero)
                                  .animate(CurvedAnimation(
                                      parent: _entryAnimController,
                                      curve: const Interval(0.5, 1.0,
                                          curve: Curves.easeOut))),
                              child: _buildAdminNotesCard(
                                  _orderData!, themeProvider)),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildOrderOverviewCard(
      AdminOrderDetailModel order, ThemeProvider themeProvider) {
    Color statusColor = _getStatusColor(order.status, themeProvider);
    IconData statusIcon = _getStatusIcon(order.status);

    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Order Overview',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.primaryText)),
              InkWell(
                onTap: _isUpdatingStatus
                    ? null
                    : () async {
                        String? newStatus = await _showStatusUpdateDialog(
                            themeProvider, order.status);
                        if (newStatus != null && newStatus != order.status) {
                          _handleUpdateOrderStatus(newStatus);
                        }
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 6),
                    Text(order.status,
                        style: GoogleFonts.inter(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_note_outlined,
                        size: 14, color: statusColor.withOpacity(0.7)),
                  ]),
                ),
              )
            ]),
            const SizedBox(height: 12),
            _buildDetailRowAdmin("Order ID:", order.id, themeProvider),
            _buildDetailRowAdmin(
                "Placed On:", order.formattedOrderDate, themeProvider),
            _buildDetailRowAdmin(
              "Customer:",
              order.customer.name,
              themeProvider,
              // --- FIX: Disable the onTap if the customer ID is invalid ---
              onTap:
                  (order.customer.id.isNotEmpty && order.customer.id != 'N/A')
                      ? () => Navigator.pushNamed(
                          context, AdminCustomerDetailsScreen.routeName,
                          arguments: {'customerId': order.customer.id})
                      : null,
            ),
            _buildDetailRowAdmin(
                "Driver:", order.driver?.name ?? "Not Assigned", themeProvider,
                onTap: order.driver != null &&
                        order.driver!.id.isNotEmpty &&
                        order.driver!.id != 'N/A'
                    ? () => Navigator.pushNamed(context, AdminDriverDetailsScreen.routeName,
                        arguments: {'driverId': order.driver!.id})
                    : null,
                trailing: (order.status != "Delivered" && order.status != "Cancelled")
                    ? TextButton(
                        onPressed:
                            _isAssigningDriver ? null : _handleAssignDriver,
                        child: Text(_isAssigningDriver ? "..." : (order.driver != null ? "Re-assign" : "Assign Driver"),
                            style: GoogleFonts.inter(
                                color: themeProvider.gas2doorTeal,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)))
                    : null),
          ]),
        ));
  }

  Widget _buildItemsOrderedCard(
      AdminOrderDetailModel order, ThemeProvider themeProvider) {
    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Items Ordered (${order.items.length})',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 4),
            if (order.items.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text("No items found in this order.",
                      style: GoogleFonts.inter(
                          color: themeProvider.secondaryText))),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: order.items.length,
              itemBuilder: (context, index) {
                final item = order.items[index];
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(children: [
                      item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? Image.network(item.imageUrl!,
                              width: 30,
                              height: 30,
                              errorBuilder: (_, __, ___) => Icon(
                                  Icons.propane_tank_outlined,
                                  color: themeProvider.gas2doorTeal,
                                  size: 24))
                          : Icon(Icons.propane_tank_outlined,
                              color: themeProvider.gas2doorTeal, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text('${item.quantity}x ${item.name}',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: themeProvider.primaryText))),
                      Text('₦${item.itemTotal.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: themeProvider.primaryText)),
                    ]));
              },
              separatorBuilder: (context, index) =>
                  Divider(color: themeProvider.tertiaryText.withOpacity(0.2)),
            ),
          ]),
        ));
  }

  Widget _buildDeliveryInfoCard(
      AdminOrderDetailModel order, ThemeProvider themeProvider) {
    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Delivery Information',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.location_on_outlined,
                  color: themeProvider.gas2doorPrimaryBlue, size: 24),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(order.deliveryAddressFull,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          color: themeProvider.secondaryText,
                          height: 1.4))),
            ]),
            const SizedBox(height: 8),
            _buildDetailRowAdmin(
                "Delivery Type:",
                order.isExpressDelivery
                    ? "Express Delivery"
                    : "Standard Delivery",
                themeProvider),
            // For Admin, LocationHistoryScreen might need different arguments or context
            if (order.status == "Delivered" ||
                order.status == "Out for Delivery")
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      icon: Icon(Icons.route_outlined,
                          size: 18, color: themeProvider.gas2doorTeal),
                      label: Text("View Delivery Route",
                          style: GoogleFonts.inter(
                              color: themeProvider.gas2doorTeal, fontSize: 13)),
                      onPressed: () {
                        // Admin might want to see location history directly associated with the order
                        // Ensure '/location_history' route in main.dart can handle admin context if needed
                        Navigator.pushNamed(context, '/location_history',
                            arguments: {
                              'orderId': order.id,
                              'customerId': order.customer
                                  .id, // Admin context might still need customerId for the API call
                            });
                      }))
          ]),
        ));
  }

  Widget _buildPricingSummaryCard(
      AdminOrderDetailModel order, ThemeProvider themeProvider) {
    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Payment Summary',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            _buildDetailRowAdmin("Items Subtotal:",
                '₦${order.itemsSubtotal.toStringAsFixed(0)}', themeProvider),
            _buildDetailRowAdmin("VAT:",
                '+ ₦${order.vatAmount.toStringAsFixed(0)}', themeProvider),
            _buildDetailRowAdmin(
                "Service Fee:",
                '+ ₦${order.serviceFeeAmount.toStringAsFixed(0)}',
                themeProvider),
            _buildDetailRowAdmin("Delivery Fee:",
                '+ ₦${order.deliveryFee.toStringAsFixed(0)}', themeProvider),
            if (order.discountAmount > 0)
              _buildDetailRowAdmin(
                  "Discount (${order.promoCodeApplied ?? 'N/A'}):",
                  '- ₦${order.discountAmount.toStringAsFixed(0)}',
                  themeProvider,
                  isDiscount: true),
            Divider(
                height: 24,
                color: themeProvider.tertiaryText.withOpacity(0.3),
                thickness: 0.5),
            _buildDetailRowAdmin("Grand Total:",
                '₦${order.grandTotal.toStringAsFixed(2)}', themeProvider,
                isTotal: true),
            const SizedBox(height: 8),
            _buildDetailRowAdmin(
                "Payment Status:", order.paymentStatus, themeProvider,
                color: order.paymentStatus == "Paid"
                    ? themeProvider.successColor
                    : (order.paymentStatus == "Pending"
                        ? themeProvider.warningColor
                        : themeProvider.errorColor)),
            if (order.paymentMethodUsed != null)
              _buildDetailRowAdmin(
                  "Method:", order.paymentMethodUsed!, themeProvider),
            if (order.paymentTransactionId != null)
              _buildDetailRowAdmin(
                  "Transaction ID:", order.paymentTransactionId!, themeProvider,
                  isMultiLine: true),
          ]),
        ));
  }

  Widget _buildOrderStatusHistoryCard(
      AdminOrderDetailModel order, ThemeProvider themeProvider) {
    if (order.statusHistory.isEmpty) {
      return const SizedBox.shrink();
    }
    List<AdminOrderStatusHistoryItem> sortedHistory =
        List.from(order.statusHistory);
    sortedHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Status History',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedHistory.length,
              itemBuilder: (context, index) {
                final historyItem = sortedHistory[index];
                bool isFirstInDisplay = index == 0;
                bool isLastInDisplay = index == sortedHistory.length - 1;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isFirstInDisplay)
                          Container(
                              height: 8,
                              width: 1,
                              color:
                                  themeProvider.tertiaryText.withOpacity(0.5)),
                        Icon(Icons.circle,
                            size: 10,
                            color: isFirstInDisplay
                                ? themeProvider.gas2doorPrimaryBlue
                                : themeProvider.tertiaryText.withOpacity(0.5)),
                        if (!isLastInDisplay)
                          Container(
                              width: 1,
                              height: 30,
                              color: themeProvider.tertiaryText.withOpacity(
                                  0.5)), // Adjusted height for better spacing
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(historyItem.status,
                            style: GoogleFonts.inter(
                                fontWeight: isFirstInDisplay
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isFirstInDisplay
                                    ? themeProvider.gas2doorPrimaryBlue
                                    : themeProvider.primaryText,
                                fontSize: 14)),
                        Text(historyItem.formattedTimestamp,
                            style: GoogleFonts.inter(
                                color: themeProvider.tertiaryText,
                                fontSize: 11)),
                        if (historyItem.updatedBy != null)
                          Text("By: ${historyItem.updatedBy}",
                              style: GoogleFonts.inter(
                                  color: themeProvider.tertiaryText,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic)),
                        if (historyItem.notes != null &&
                            historyItem.notes!.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text("Notes: ${historyItem.notes}",
                                  style: GoogleFonts.inter(
                                      color: themeProvider.tertiaryText,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic))),
                        if (!isLastInDisplay) const SizedBox(height: 12),
                      ],
                    )),
                  ],
                );
              },
            )
          ],
        ),
      ),
    );
  }

  // FIX: This widget is now updated to display a LIST of notes, not a single string.
  Widget _buildAdminNotesCard(
      AdminOrderDetailModel order, ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Internal Admin Notes',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 10),

            // Display existing notes if they exist, otherwise show a message.
            if (order.adminNotes.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: themeProvider.appSecondaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: order.adminNotes
                      .map((noteItem) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              '• [${noteItem.formattedTimestamp}] ${noteItem.note}',
                              style: GoogleFonts.inter(
                                  color: themeProvider.secondaryText,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ))
                      .toList(),
                ),
              )
            else
              Text("No internal notes for this order yet.",
                  style: GoogleFonts.inter(
                      color: themeProvider.secondaryText,
                      fontStyle: FontStyle.italic)),

            const SizedBox(height: 16),
            CustomInput(
              controller: _adminNoteController,
              hintText: "Add a new note for internal records...",
              labelText: "New Note",
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: CustomButton(
                text: _isAddingNote ? "Adding..." : "Add Note",
                onPressed: _isAddingNote ? null : _handleAddAdminNote,
                color: themeProvider.gas2doorTeal,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRowAdmin(
      String label, String value, ThemeProvider themeProvider,
      {bool isTotal = false,
      bool isDiscount = false,
      bool isMultiLine = false,
      VoidCallback? onTap,
      Widget? trailing,
      Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment:
            isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: themeProvider.secondaryText,
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal)),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: GoogleFonts.inter(
                  fontSize: isTotal ? 17 : 14.5,
                  color: color ??
                      (isDiscount
                          ? themeProvider.successColor
                          : (onTap != null
                              ? themeProvider.gas2doorPrimaryBlue
                              : themeProvider.primaryText)),
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                  decoration: onTap != null
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Color _getStatusColor(String status, ThemeProvider themeProvider) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return themeProvider.successColor;
      case 'out for delivery':
      case 'processing':
      case 'order confirmed':
      case 'driver assigned':
      case 'driver enroute to pickup cylinder':
      case 'driver enroute to gas station':
      case 'cylinder refilling':
        return themeProvider.warningColor;
      case 'cancelled':
      case 'pickup issue reported by driver':
      case 'delivery issue reported by driver':
      case 'payment failed':
        return themeProvider.errorColor;
      case 'payment pending':
        return themeProvider.warningColor.withOpacity(0.8);
      default:
        return themeProvider.secondaryText;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Icons.check_circle_outline;
      case 'out for delivery':
        return Icons.local_shipping_outlined;
      case 'processing':
      case 'cylinder refilling':
        return Icons.hourglass_top_rounded;
      case 'order placed': // Explicitly added 'order placed'
        return Icons.playlist_add_check_rounded;
      case 'order confirmed':
        return Icons.thumb_up_alt_outlined;
      case 'driver assigned':
      case 'driver enroute to pickup cylinder':
      case 'driver enroute to gas station':
        return Icons.person_pin_circle_outlined;
      case 'cancelled':
      case 'pickup issue reported by driver':
      case 'delivery issue reported by driver':
        return Icons.cancel_outlined;
      case 'payment pending':
        return Icons.payment_outlined;
      case 'payment failed':
        return Icons.error_outline_rounded;
      default:
        return Icons.info_outline; // Default for unhandled statuses
    }
  }

  Widget _buildErrorState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Could Not Load Order Details',
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
                onPressed: () => _fetchOrderDetails(isRefresh: true),
                color: themeProvider
                    .gas2doorPrimaryBlue, // Now 'color' is correctly passed
                icon: Icon(Icons.refresh_rounded,
                    color: themeProvider.infoColorOnDarkBgs)),
          ],
        ),
      ),
    );
  }
}
