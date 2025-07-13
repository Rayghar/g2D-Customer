// File: lib/screens/admin/admin_run_management_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../models/admin/admin_run_management_model.dart';
import '../../services/api_service.dart';
import './admin_active_run_details_screen.dart';
import './admin_order_details_screen.dart';
import '../../models/admin/admin_order_summary_model.dart';

class AdminRunManagementScreen extends StatefulWidget {
  static const String routeName = '/admin_run_management';
  const AdminRunManagementScreen({super.key});

  @override
  State<AdminRunManagementScreen> createState() =>
      _AdminRunManagementScreenState();
}

class _AdminRunManagementScreenState extends State<AdminRunManagementScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;

  List<AdminPickupBatchSummary> _pendingBatches = [];
  List<AdminActiveRunInfo> _activeRuns = [];
  List<AdminUnassignedOrder> _unassignedOrders = [];

  // --- NEW: State for managing order selection for batching ---
  final Set<String> _selectedOrderIds = {};

  late TabController _tabController;
  late AnimationController _entryAnimController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _apiService.adminGetPendingBatches(),
        _apiService.adminGetActiveRuns(),
        // --- FIX: Fetch orders with a status that makes them assignable ---
        _apiService.adminGetOrders(status: 'Order Placed', limit: 100),
      ]);

      if (mounted) {
        // The unassigned orders list is now built from the response of adminGetOrders
        final unassignedOrdersResponse = results[2] as Map<String, dynamic>;
        final rawOrders =
            unassignedOrdersResponse['orders'] as List<AdminOrderSummaryModel>;

        setState(() {
          _pendingBatches = results[0] as List<AdminPickupBatchSummary>;
          _activeRuns = results[1] as List<AdminActiveRunInfo>;
          // Convert the summary model to the specific unassigned model
          _unassignedOrders = rawOrders
              .map((order) => AdminUnassignedOrder.fromOrderSummary(order))
              .toList();

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
              "Failed to load run data: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  // --- NEW: Handler to create a run from selected orders ---
  Future<void> _handleCreateRunFromSelection() async {
    if (_selectedOrderIds.isEmpty) {
      _showFeedbackSnackbar("Please select at least one order to create a run.",
          isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      await _apiService.adminCreateRunFromOrders(_selectedOrderIds.toList());
      _showFeedbackSnackbar(
          "Run created successfully! It is now in 'Pending Batches'.");

      // Clear selection and refresh all data
      _selectedOrderIds.clear();
      await _fetchAllData(isRefresh: true);
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
            isError: true);
        setState(() => _isLoading = false);
      }
    }
    // No finally block needed for isLoading, as it's handled on success/error
  }

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor:
          isError ? themeProvider.errorColor : themeProvider.successColor,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _handleAssignDriverToBatch(AdminPickupBatchSummary batch) async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      // 1. Fetch the list of available drivers
      final availableDrivers = await _apiService.adminGetAvailableDrivers();
      if (!mounted) return;

      if (availableDrivers.isEmpty) {
        _showFeedbackSnackbar("No drivers are currently online and available.",
            isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // 2. Show a dialog for the admin to select a driver
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      AvailableDriverForMap? selectedDriver =
          await showDialog<AvailableDriverForMap>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: themeProvider.cardBackground,
            title: Text("Assign Driver to Batch",
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableDrivers.length,
                itemBuilder: (context, index) {
                  final driver = availableDrivers[index];
                  return ListTile(
                    title: Text(driver.name,
                        style: GoogleFonts.inter(
                            color: themeProvider.primaryText)),
                    subtitle: Text("Load: ${driver.currentLoadKg}kg",
                        style: GoogleFonts.inter(
                            color: themeProvider.secondaryText, fontSize: 12)),
                    onTap: () => Navigator.of(dialogContext).pop(driver),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text("Cancel",
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
              )
            ],
          );
        },
      );

      // 3. If a driver was selected, make the API call
      if (selectedDriver != null && mounted) {
        await _apiService.adminAssignDriverToRun(batch.id, selectedDriver.id);
        _showFeedbackSnackbar(
            "Driver ${selectedDriver.name} assigned successfully to batch ${batch.id}.");
        await _fetchAllData(isRefresh: true); // Refresh the screen
      } else {
        // If dialog was cancelled, stop the loading indicator
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
            isError: true);
        setState(() => _isLoading = false);
      }
    }
    // The loading state is now correctly handled within the try/catch/finally blocks.
  }

  Future<void> _handleAssignDriverToOrder(AdminUnassignedOrder order) async {
    setState(() => _isLoading = true);
    try {
      final availableDrivers = await _apiService.adminGetAvailableDrivers();
      if (!mounted || availableDrivers.isEmpty) {
        _showFeedbackSnackbar("No drivers available for assignment.",
            isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final selectedDriverId = availableDrivers.first.id;

      // --- FIX: Calls the now-existing adminAssignDriver method ---
      await _apiService.adminAssignDriver(order.orderId, selectedDriverId);
      _showFeedbackSnackbar(
          "Driver assigned successfully to order ${order.orderId}.");
      await _fetchAllData(isRefresh: true);
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
            isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  void _viewActiveRunDetails(AdminActiveRunInfo run) {
    Navigator.pushNamed(context, AdminActiveRunDetailsScreen.routeName,
        arguments: {'runId': run.runId});
  }

  void _viewOrderDetails(String orderId) {
    Navigator.pushNamed(context, AdminOrderDetailsScreen.routeName,
        arguments: {'orderId': orderId});
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String appLogoPath = 'assets/images/gas2door_logo.png';
    final Color adminAccentColor = themeProvider.gas2doorPurple;

    return Scaffold(
      backgroundColor: themeProvider.appPrimaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        title: Row(children: [
          Image.asset(appLogoPath,
              height: 28,
              color: adminAccentColor,
              errorBuilder: (ctx, err, st) => Icon(Icons.route_outlined,
                  color: adminAccentColor, size: 28)),
          const SizedBox(width: 10),
          Text('Run & Operations',
              style: GoogleFonts.inter(
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 18)),
        ]),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: themeProvider.primaryText),
            onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
              icon:
                  Icon(Icons.refresh_rounded, color: themeProvider.primaryText),
              onPressed: () => _fetchAllData(isRefresh: true),
              tooltip: "Refresh Data")
        ],
      ),
      body: _isLoading &&
              _pendingBatches.isEmpty &&
              _activeRuns.isEmpty &&
              _unassignedOrders.isEmpty
          ? Center(child: CircularProgressIndicator(color: adminAccentColor))
          : _errorMessage != null
              ? _buildErrorState(themeProvider)
              : FadeTransition(
                  opacity: _entryAnimController,
                  child: Column(
                    children: [
                      Container(
                        color: themeProvider.cardBackground,
                        child: TabBar(
                          controller: _tabController,
                          labelColor: adminAccentColor,
                          unselectedLabelColor: themeProvider.secondaryText,
                          indicatorColor: adminAccentColor,
                          tabs: const [
                            Tab(text: 'Pending Batches'),
                            Tab(text: 'Active Runs'),
                            Tab(text: 'Unassigned'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildListSection(
                                _pendingBatches,
                                "No pending pickup batches.",
                                themeProvider,
                                (item) => _buildPendingBatchCard(
                                    item, themeProvider)),
                            _buildListSection(
                                _activeRuns,
                                "No active pickup runs.",
                                themeProvider,
                                (item) =>
                                    _buildActiveRunCard(item, themeProvider)),
                            _buildListSection(
                                _unassignedOrders,
                                "No unassigned orders.",
                                themeProvider,
                                (item) => _buildUnassignedOrderCardInteractive(
                                    item, themeProvider)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: _selectedOrderIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _handleCreateRunFromSelection,
              label: Text("Create Run (${_selectedOrderIds.length})"),
              icon: const Icon(Icons.add_road_rounded),
              backgroundColor: themeProvider.gas2doorTeal,
            )
          : null, // Only show button when orders are selected
    );
  }

  Widget _buildUnassignedOrderCardInteractive(
      AdminUnassignedOrder order, ThemeProvider themeProvider) {
    final bool isSelected = _selectedOrderIds.contains(order.orderId);
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      border: isSelected
          ? BorderSide(color: themeProvider.gas2doorTeal, width: 2)
          : null,
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: themeProvider.gas2doorTeal,
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              _selectedOrderIds.add(order.orderId);
            } else {
              _selectedOrderIds.remove(order.orderId);
            }
          });
        },
        title: Text(
          "Order ...${order.orderId.substring(order.orderId.length - 6)}",
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w600, color: themeProvider.primaryText),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Customer: ${order.customerName}"),
            Text("Items: ${order.cylinderDetails}",
                overflow: TextOverflow.ellipsis),
            Text("Address: ${order.addressSnippet}",
                overflow: TextOverflow.ellipsis),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildListSection(List<dynamic> items, String emptyMessage,
      ThemeProvider themeProvider, Widget Function(dynamic item) cardBuilder) {
    if (_isLoading && items.isEmpty) {
      return Center(
          child:
              CircularProgressIndicator(color: themeProvider.gas2doorPurple));
    }
    if (items.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(emptyMessage,
                  style: GoogleFonts.inter(
                      color: themeProvider.secondaryText, fontSize: 15),
                  textAlign: TextAlign.center)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: _entryAnimController,
                  curve: Interval((0.2 + (index * 0.1)).clamp(0.0, 1.0), 1.0,
                      curve: Curves.easeOutCubic))),
          child: cardBuilder(items[index]),
        );
      },
    );
  }

  Widget _buildPendingBatchCard(
      AdminPickupBatchSummary batch, ThemeProvider themeProvider) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "Batch ID: ...${batch.id.substring(batch.id.length - 6)} (${batch.zoneDescription})",
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 6),
            _buildInfoRowRunMngmt(Icons.format_list_numbered_rounded,
                "${batch.orderCount} Orders", themeProvider),
            _buildInfoRowRunMngmt(
                Icons.scale_outlined,
                "Weight: ~${batch.totalWeightKg.toStringAsFixed(1)} kg",
                themeProvider),
            _buildInfoRowRunMngmt(
                Icons.timer_outlined,
                "Est. Time: ${batch.estimatedTimeMinutes.toInt()} mins",
                themeProvider),
            const SizedBox(height: 10),
            CustomButton(
                text: "View & Assign Driver",
                onPressed: () => _handleAssignDriverToBatch(batch),
                color: themeProvider.gas2doorTeal,
                height: 40,
                icon: const Icon(Icons.person_add_alt_1_rounded,
                    color: Colors.white, size: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRunCard(
      AdminActiveRunInfo run, ThemeProvider themeProvider) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "Run ID: ...${run.runId.substring(run.runId.length - 6)} (Driver: ${run.driverInfo.name})",
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 6),
            _buildInfoRowRunMngmt(Icons.delivery_dining_outlined,
                "Status: ${run.currentStatusSummary}", themeProvider),
            _buildInfoRowRunMngmt(
                Icons.check_circle_outline_rounded,
                "Progress: ${run.completedStops} / ${run.totalStops} Stops Done",
                themeProvider),
            Text(
                "Started: ${DateFormat('hh:mm a').format(run.startTime.toLocal())}",
                style: GoogleFonts.inter(
                    fontSize: 11, color: themeProvider.tertiaryText)),
            const SizedBox(height: 10),
            CustomButton(
                text: "View Run Details",
                onPressed: () => _viewActiveRunDetails(run),
                color: themeProvider.gas2doorPrimaryBlue,
                height: 40,
                icon: const Icon(Icons.map_outlined,
                    color: Colors.white, size: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildUnassignedOrderCard(
      AdminUnassignedOrder order, ThemeProvider themeProvider) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
                onTap: () => _viewOrderDetails(order.orderId),
                child: Text(
                    "Order ID: ...${order.orderId.substring(order.orderId.length - 6)} (Customer: ${order.customerName})",
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.gas2doorPrimaryBlue,
                        decoration: TextDecoration.underline))),
            const SizedBox(height: 6),
            _buildInfoRowRunMngmt(Icons.location_on_outlined,
                order.addressSnippet, themeProvider),
            _buildInfoRowRunMngmt(Icons.inventory_2_outlined,
                "Items: ${order.cylinderDetails}", themeProvider),
            if (order.reasonUnassigned != null)
              _buildInfoRowRunMngmt(Icons.info_outline_rounded,
                  "Reason: ${order.reasonUnassigned}", themeProvider,
                  color: themeProvider.warningColor),
            Text(
                "Placed: ${DateFormat('hh:mm a, dd MMM').format(order.orderPlacedTime.toLocal())}",
                style: GoogleFonts.inter(
                    fontSize: 11, color: themeProvider.tertiaryText)),
            const SizedBox(height: 10),
            CustomButton(
                text: "Manually Assign Driver",
                onPressed: () => _handleAssignDriverToOrder(order),
                color: themeProvider.gas2doorPurple.withOpacity(0.8),
                height: 40,
                icon: const Icon(Icons.person_search_rounded,
                    color: Colors.white, size: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowRunMngmt(
      IconData icon, String text, ThemeProvider themeProvider,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: color ?? themeProvider.secondaryText.withOpacity(0.8)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: color ?? themeProvider.secondaryText),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1)),
        ],
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
            Text('Failed to Load Run Data',
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
                onPressed: () => _fetchAllData(isRefresh: true),
                color: themeProvider.gas2doorPrimaryBlue,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
