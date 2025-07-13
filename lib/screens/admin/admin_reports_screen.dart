// File: lib/screens/admin/admin_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math'; // <<< ADDED IMPORT FOR Random
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
// Import defined report models
import '../../models/admin/admin_report_model.dart';
// import 'package:fl_chart/fl_chart.dart'; // For future chart implementation

// Mock AdminAnalyticsService - Replace with actual service
class MockAdminAnalyticsService {
  final Random _random = Random(); // <<< INSTANTIATE Random HERE

  Future<Map<String, dynamic>> getReportData(
      String periodQuery, DateTimeRange? customRange) async {
    print(
        "MockAdminAnalyticsService: Fetching reports for $periodQuery, Custom Range: $customRange");
    await Future.delayed(const Duration(milliseconds: 1200));

    // Simulate data based on period/range
    double revenueMultiplier = 1.0;
    int orderMultiplier = 1;
    if (periodQuery.contains("today")) {
      revenueMultiplier = 0.1;
      orderMultiplier = 1;
    } else if (periodQuery.contains("month")) {
      revenueMultiplier = 2.5;
      orderMultiplier = 2;
    }

    if (customRange != null) {
      final days = customRange.duration.inDays;
      revenueMultiplier = days / 7.0; // Simple scaling
      orderMultiplier = (days / 10)
          .ceil()
          .clamp(1, 100); // Ensure orderMultiplier is at least 1
    }

    return {
      'salesOverview': SalesOverviewStats(
          totalRevenue: 1250350.75 * revenueMultiplier,
          totalOrders: (78 * orderMultiplier).toInt(),
          averageOrderValue: 16030.14,
          revenueTrend: List.generate(
              7,
              (i) => DailyRevenue(
                  date: DateTime.now().subtract(Duration(days: i)),
                  revenue: (_random.nextDouble() * 20000 +
                          50000) * // <<< USE _random instance
                      revenueMultiplier /
                      7))).toJson(),
      'orderStats': OrderReportStats(
              ordersByStatus: {
            "Pending": (5 * orderMultiplier).toInt(),
            "Processing": (10 * orderMultiplier).toInt(),
            "Out for Delivery": (8 * orderMultiplier).toInt(),
            "Delivered": (50 * orderMultiplier).toInt(),
            "Cancelled": (5 * orderMultiplier).toInt()
          },
              popularCylinders: {
            "12.5 KG": (45 * orderMultiplier).toInt(),
            "6 KG": (25 * orderMultiplier).toInt(),
            "5 KG": (8 * orderMultiplier).toInt()
          },
              peakTimes: List.generate(
                  24,
                  (i) => HourlyOrders(
                      hour: i,
                      orderCount: (_random.nextInt(5) + 1) *
                          orderMultiplier))) // <<< USE _random instance
          .toJson(),
      'customerStats': CustomerReportStats(
          newRegistrations: (15 * orderMultiplier).toInt(),
          totalActiveCustomers: 850 + (20 * orderMultiplier).toInt(),
          topCustomers: [
            TopCustomer(
                customerId: "C001",
                name: "Aisha K.",
                orderCount: 5 * orderMultiplier,
                totalSpent: 75000 * revenueMultiplier),
            TopCustomer(
                customerId: "C002",
                name: "Bello M.",
                orderCount: 4 * orderMultiplier,
                totalSpent: 60000 * revenueMultiplier)
          ]).toJson(),
      'driverStats': DriverReportStats(
          totalActiveDrivers: 22,
          avgDeliveriesPerDriver: 3.5 * orderMultiplier,
          avgDeliveryTimeMinutes: 45.2,
          topDrivers: [
            TopDriver(
                driverId: "D001",
                name: "Tunde A.",
                deliveryCount: 15 * orderMultiplier,
                averageRating: 4.8),
            TopDriver(
                driverId: "D002",
                name: "Grace O.",
                deliveryCount: 12 * orderMultiplier,
                averageRating: 4.5)
          ]).toJson(),
    };
  }
}

class AdminReportsScreen extends StatefulWidget {
  static const String routeName = '/admin_reports';
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedPeriod = "This Week";
  DateTimeRange? _customDateRange;

  SalesOverviewStats _salesStats = SalesOverviewStats();
  OrderReportStats _orderStats = OrderReportStats();
  CustomerReportStats _customerStats = CustomerReportStats();
  DriverReportStats _driverStats = DriverReportStats();

  late AnimationController _entryAnimController;
  final MockAdminAnalyticsService _analyticsService =
      MockAdminAnalyticsService();

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fetchReportData();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchReportData({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String periodQuery = _selectedPeriod.toLowerCase().replaceAll(' ', '');
    if (_selectedPeriod == "Custom" && _customDateRange == null) {
      _showFeedbackSnackbar(
          "Please select a custom date range or choose a preset period.",
          isError: true);
      if (mounted) setState(() => _isLoading = false); // Ensure loading stops
      return;
    }

    try {
      final reportData =
          await _analyticsService.getReportData(periodQuery, _customDateRange);
      if (mounted) {
        setState(() {
          _salesStats = SalesOverviewStats.fromJson(
              reportData['salesOverview'] as Map<String, dynamic>);
          _orderStats = OrderReportStats.fromJson(
              reportData['orderStats'] as Map<String, dynamic>);
          _customerStats = CustomerReportStats.fromJson(
              reportData['customerStats'] as Map<String, dynamic>);
          _driverStats = DriverReportStats.fromJson(
              reportData['driverStats'] as Map<String, dynamic>);
          _isLoading = false;
        });
        _entryAnimController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load reports: ${e.toString()}";
        });
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

  void _selectDateRange() async {
    HapticFeedback.lightImpact();
    final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        initialDateRange: _customDateRange ??
            DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 7)),
                end: DateTime.now()),
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
        builder: (context, child) {
          final themeProvider =
              Provider.of<ThemeProvider>(context, listen: false);
          return Theme(
              data: themeProvider.isDarkMode
                  ? themeProvider.darkTheme
                  : themeProvider.lightTheme,
              child: child!);
        });
    if (picked != null && picked != _customDateRange) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = "Custom";
      });
      _fetchReportData(isRefresh: true);
    }
  }

  Widget _buildPeriodSelector(ThemeProvider themeProvider) {
    List<String> periods = ["Today", "This Week", "This Month", "Custom"];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: periods.map((period) {
            bool isSelected = _selectedPeriod == period;
            String labelText = period;
            if (period == "Custom" && _customDateRange != null) {
              labelText =
                  "${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM').format(_customDateRange!.end)}";
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(labelText,
                    style: GoogleFonts.inter(
                        color: isSelected
                            ? themeProvider.infoColorOnDarkBgs
                            : themeProvider.primaryText,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal)),
                selected: isSelected,
                onSelected: (bool selected) {
                  HapticFeedback.lightImpact();
                  if (period == "Custom") {
                    _selectDateRange();
                  } else {
                    setState(() {
                      _selectedPeriod = period;
                      _customDateRange = null;
                    });
                    _fetchReportData(isRefresh: true);
                  }
                },
                selectedColor: themeProvider.gas2doorPrimaryBlue,
                backgroundColor: themeProvider.cardBackground,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: isSelected
                            ? themeProvider.gas2doorPrimaryBlue
                            : themeProvider.tertiaryText.withOpacity(0.3))),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            );
          }).toList(),
        ),
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
        title: Text('Reports & Analytics',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: themeProvider.primaryText),
            onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
              icon:
                  Icon(Icons.refresh_rounded, color: themeProvider.primaryText),
              onPressed: () => _fetchReportData(isRefresh: true),
              tooltip: "Refresh Data")
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: adminAccentColor))
          : _errorMessage != null
              ? _buildErrorState(themeProvider)
              : FadeTransition(
                  opacity: _entryAnimController,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: <Widget>[
                      _buildPeriodSelector(themeProvider),
                      const SizedBox(height: 16),
                      _buildSectionTitle("Sales Performance",
                          Icons.trending_up_rounded, themeProvider),
                      _buildSalesOverviewCard(_salesStats, themeProvider),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Order Insights",
                          Icons.receipt_long_outlined, themeProvider),
                      _buildOrderStatsCard(_orderStats, themeProvider),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Customer Metrics",
                          Icons.people_alt_outlined, themeProvider),
                      _buildCustomerStatsCard(_customerStats, themeProvider),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Driver Performance",
                          Icons.directions_car_filled_outlined, themeProvider),
                      _buildDriverStatsCard(_driverStats, themeProvider),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(
      String title, IconData icon, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon,
              color: themeProvider.primaryText.withOpacity(0.8), size: 22),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.primaryText)),
        ],
      ),
    );
  }

  Widget _buildSalesOverviewCard(
      SalesOverviewStats stats, ThemeProvider themeProvider) {
    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildStatRow(
                  "Total Revenue:",
                  "₦${NumberFormat("#,##0.00").format(stats.totalRevenue)}",
                  themeProvider,
                  isLarge: true),
              _buildStatRow(
                  "Total Orders:", stats.totalOrders.toString(), themeProvider),
              _buildStatRow(
                  "Average Order Value:",
                  "₦${NumberFormat("#,##0.00").format(stats.averageOrderValue)}",
                  themeProvider),
              const SizedBox(height: 12),
              Container(
                height: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    border: Border.all(
                        color: themeProvider.tertiaryText.withOpacity(0.3)),
                    borderRadius: themeProvider.cardBorderRadius),
                child: Text("Sales Chart (fl_chart integration pending)",
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
              )
            ],
          ),
        ));
  }

  Widget _buildOrderStatsCard(
      OrderReportStats stats, ThemeProvider themeProvider) {
    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Orders by Status:",
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryText)),
              const SizedBox(height: 8),
              if (stats.ordersByStatus.isEmpty)
                Text("No status data.",
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
              ...stats.ordersByStatus.entries.map((entry) => _buildDetailRow(
                  entry.key, entry.value.toString(), themeProvider)),
              const SizedBox(height: 12),
              Text("Popular Cylinder Sizes:",
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryText)),
              const SizedBox(height: 8),
              if (stats.popularCylinders.isEmpty)
                Text("No cylinder data.",
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
              ...stats.popularCylinders.entries.map((entry) => _buildDetailRow(
                  entry.key, "${entry.value} orders", themeProvider)),
              const SizedBox(height: 12),
              Text("Peak Order Times (Chart Pending):",
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryText)),
              Container(
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    border: Border.all(
                        color: themeProvider.tertiaryText.withOpacity(0.3)),
                    borderRadius: themeProvider.cardBorderRadius),
                child: Text("Peak Times Chart (fl_chart integration pending)",
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
              )
            ],
          ),
        ));
  }

  Widget _buildCustomerStatsCard(
      CustomerReportStats stats, ThemeProvider themeProvider) {
    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            _buildStatRow("New Customers:", stats.newRegistrations.toString(),
                themeProvider),
            _buildStatRow("Total Active Customers:",
                stats.totalActiveCustomers.toString(), themeProvider),
            if (stats.topCustomers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text("Top Customers:",
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryText)),
              ...stats.topCustomers.map((cust) => _buildDetailRow(
                  "${cust.name} (Orders: ${cust.orderCount})",
                  "Spent: ₦${NumberFormat("#,##0").format(cust.totalSpent)}",
                  themeProvider))
            ]
          ]),
        ));
  }

  Widget _buildDriverStatsCard(
      DriverReportStats stats, ThemeProvider themeProvider) {
    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            _buildStatRow("Total Active Drivers:",
                stats.totalActiveDrivers.toString(), themeProvider),
            _buildStatRow("Avg. Deliveries/Driver:",
                stats.avgDeliveriesPerDriver.toStringAsFixed(1), themeProvider),
            _buildStatRow(
                "Avg. Delivery Time:",
                "${stats.avgDeliveryTimeMinutes.toStringAsFixed(1)} mins",
                themeProvider),
            if (stats.topDrivers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text("Top Drivers:",
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryText)),
              ...stats.topDrivers.map((driver) => _buildDetailRow(
                  "${driver.name} (Deliveries: ${driver.deliveryCount})",
                  "Rating: ${driver.averageRating.toStringAsFixed(1)} ★",
                  themeProvider))
            ]
          ]),
        ));
  }

  Widget _buildStatRow(String label, String value, ThemeProvider themeProvider,
      {bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: isLarge ? 15 : 14,
                  color: themeProvider.secondaryText,
                  fontWeight: isLarge ? FontWeight.w500 : FontWeight.normal)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: isLarge ? 18 : 15,
                  color: themeProvider.primaryText,
                  fontWeight: isLarge ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      String label, String value, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14, color: themeProvider.secondaryText)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w500)),
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
            Icon(Icons.analytics_outlined,
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Could Not Load Reports',
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
                onPressed: () => _fetchReportData(isRefresh: true),
                color: themeProvider.gas2doorPrimaryBlue,
                icon: Icon(Icons.refresh_rounded,
                    color: themeProvider.infoColorOnDarkBgs)),
          ],
        ),
      ),
    );
  }
}

// Helper extension for String capitalization (if not globally available)
extension StringCapitalizeExtensionAdminReports on String {
  String capitalizeFirst() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
