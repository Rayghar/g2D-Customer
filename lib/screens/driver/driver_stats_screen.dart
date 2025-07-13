// File: lib/screens/driver/driver_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:intl/intl.dart'; // For NumberFormat

import '../../providers/theme_provider.dart';
import '../../widgets/card.dart';
import '../../widgets/button.dart';

// Mock data model for stats
class DriverStats {
  final int totalOrdersExecuted;
  final double totalRevenueMade;
  final int totalOrdersCancelled;
  final double averageRating; // Added
  final double acceptanceRate; // Added (e.g., 0.0 to 1.0)
  final double averageDeliveryTimeMinutes; // Added

  DriverStats({
    required this.totalOrdersExecuted,
    required this.totalRevenueMade,
    required this.totalOrdersCancelled,
    this.averageRating = 0.0,
    this.acceptanceRate = 0.0,
    this.averageDeliveryTimeMinutes = 0.0,
  });
}

class DriverStatsScreen extends StatefulWidget {
  final String driverId;

  const DriverStatsScreen({
    super.key,
    required this.driverId,
  });

  @override
  State<DriverStatsScreen> createState() => _DriverStatsScreenState();
}

class _DriverStatsScreenState extends State<DriverStatsScreen>
    with TickerProviderStateMixin {
  bool _isLoadingStats = true;
  DriverStats? _driverStats;
  String? _errorMessage;

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _sectionSlideAnimations;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _sectionSlideAnimations = List.generate(
      3, // Number of main sections animated
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(
              0.1 + (index * 0.1), 0.8 + (index * 0.08).clamp(0.0, 0.2),
              curve: Curves.easeOutCubic),
        ),
      ),
    );
    _fetchDriverStats();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchDriverStats({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingStats = true;
      if (isRefresh) _errorMessage = null;
    });

    // TODO: Replace with actual API call to fetch stats for widget.driverId
    await Future.delayed(Duration(milliseconds: isRefresh ? 500 : 900));

    if (mounted) {
      setState(() {
        _driverStats = DriverStats(
          totalOrdersExecuted: 125 + (isRefresh ? 5 : 0),
          totalRevenueMade: 185750.00 + (isRefresh ? 2500 : 0),
          totalOrdersCancelled: 7 + (isRefresh ? 1 : 0),
          averageRating: 4.7,
          acceptanceRate: 0.92, // 92%
          averageDeliveryTimeMinutes: 35.5,
        );
        _isLoadingStats = false;
        _errorMessage = null;
      });
      _entryAnimController.forward(from: 0.0);
    }
    // catch (e) {
    //   if (mounted) {
    //     setState(() {
    //       _isLoadingStats = false;
    //       _errorMessage = "Failed to load stats: ${e.toString()}";
    //     });
    //   }
    // }
  }

  Widget _buildStatDetailRow(
      String label, String value, IconData icon, ThemeProvider themeProvider,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon,
              color: themeProvider.secondaryText.withOpacity(0.8), size: 22),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 15, color: themeProvider.secondaryText)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? themeProvider.primaryText)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color driverAccentColor =
        themeProvider.gas2doorTeal; // Driver's theme accent

    return Scaffold(
      // Added Scaffold
      backgroundColor:
          themeProvider.appSecondaryBackground, // Consistent background
      body: RefreshIndicator(
        onRefresh: () => _fetchDriverStats(isRefresh: true),
        color: driverAccentColor, // Themed refresh indicator
        backgroundColor: themeProvider.cardBackground,
        child: _isLoadingStats
            ? Center(child: CircularProgressIndicator(color: driverAccentColor))
            : _errorMessage != null
                ? _buildErrorState(themeProvider, _errorMessage!)
                : _driverStats == null
                    ? _buildEmptyState(
                        themeProvider, "No performance stats available yet.")
                    : FadeTransition(
                        opacity: _entryAnimController,
                        child: ListView(
                          padding: const EdgeInsets.all(16.0),
                          children: [
                            SlideTransition(
                              position: _sectionSlideAnimations[0],
                              child: Text(
                                  "Your Performance Statistics", // Clearer title for the screen content
                                  style: GoogleFonts.inter(
                                      fontSize: 20, // Adjusted size
                                      fontWeight: FontWeight.bold,
                                      color: themeProvider.primaryText)),
                            ),
                            const SizedBox(height: 16), // Consistent spacing
                            SlideTransition(
                              position: _sectionSlideAnimations[1],
                              child: CustomCard(
                                // Standardized Card
                                color: themeProvider.cardBackground,
                                borderRadius:
                                    themeProvider.cardBorderRadiusValue,
                                elevation: 2.0, // Consistent elevation
                                shadowColor: themeProvider.cardShadowColorGlobal
                                    .withOpacity(0.3),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Overall Summary',
                                          style: GoogleFonts.inter(
                                              fontSize: 17, // Adjusted size
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  themeProvider.primaryText)),
                                      const SizedBox(
                                          height:
                                              4), // Reduced space before divider
                                      Divider(
                                          color: themeProvider.tertiaryText
                                              .withOpacity(
                                                  0.2)), // Subtle divider
                                      const SizedBox(
                                          height: 10), // Consistent spacing
                                      _buildStatDetailRow(
                                          "Total Orders Completed:",
                                          _driverStats!.totalOrdersExecuted
                                              .toString(),
                                          Icons.check_circle_outline_rounded,
                                          themeProvider,
                                          valueColor:
                                              themeProvider.successColor),
                                      _buildStatDetailRow(
                                          "Total Revenue Earned:",
                                          "₦${NumberFormat("#,##0").format(_driverStats!.totalRevenueMade)}",
                                          Icons.account_balance_wallet_outlined,
                                          themeProvider,
                                          valueColor: themeProvider
                                              .gas2doorPrimaryBlue),
                                      _buildStatDetailRow(
                                          "Orders Cancelled/Failed:",
                                          _driverStats!.totalOrdersCancelled
                                              .toString(),
                                          Icons.cancel_outlined,
                                          themeProvider,
                                          valueColor: themeProvider.errorColor),
                                      _buildStatDetailRow(
                                          "Average Rating:",
                                          "${_driverStats!.averageRating.toStringAsFixed(1)} ★",
                                          Icons.star_half_rounded,
                                          themeProvider,
                                          valueColor:
                                              themeProvider.warningColor),
                                      _buildStatDetailRow(
                                          "Acceptance Rate:",
                                          "${(_driverStats!.acceptanceRate * 100).toStringAsFixed(0)}%",
                                          Icons.thumb_up_alt_outlined,
                                          themeProvider),
                                      _buildStatDetailRow(
                                          "Avg. Delivery Time:",
                                          "${_driverStats!.averageDeliveryTimeMinutes.toStringAsFixed(1)} mins",
                                          Icons.timer_outlined,
                                          themeProvider),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SlideTransition(
                              position: _sectionSlideAnimations[2],
                              child: CustomCard(
                                // Standardized Card for future charts
                                color: themeProvider.cardBackground,
                                borderRadius:
                                    themeProvider.cardBorderRadiusValue,
                                elevation: 2.0,
                                shadowColor: themeProvider.cardShadowColorGlobal
                                    .withOpacity(0.3),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Performance Trends (Chart Placeholder)',
                                          style: GoogleFonts.inter(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  themeProvider.primaryText)),
                                      const SizedBox(height: 12),
                                      Container(
                                        // Placeholder for chart
                                        height:
                                            180, // Defined height for chart area
                                        decoration: BoxDecoration(
                                            color: themeProvider
                                                .appSecondaryBackground
                                                .withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(
                                                themeProvider
                                                        .cardBorderRadiusValue /
                                                    2),
                                            border: Border.all(
                                                color: themeProvider
                                                    .tertiaryText
                                                    .withOpacity(0.3))),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Future chart integration (e.g., weekly earnings, orders trend)",
                                          style: GoogleFonts.inter(
                                              color:
                                                  themeProvider.secondaryText,
                                              fontStyle: FontStyle.italic,
                                              fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: themeProvider.errorColor, size: 50), // Adjusted size
            const SizedBox(height: 16), // Consistent spacing
            Text('Error Loading Stats',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 17)), // Adjusted size
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                  color: themeProvider.secondaryText,
                  fontSize: 14), // Adjusted size
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24), // Consistent spacing
            CustomButton(
              // Standardized Button
              text: "Retry",
              onPressed: () => _fetchDriverStats(isRefresh: true),
              color: themeProvider
                  .gas2doorPrimaryBlue, // Use a consistent action color
              textStyle: GoogleFonts.inter(
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white,
                  fontWeight: FontWeight.w600),
              icon: Icon(Icons.refresh_rounded,
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white),
              height: 48, // Consistent height
              borderRadius: themeProvider.cardBorderRadiusValue,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard_outlined,
                color: themeProvider.secondaryText.withOpacity(0.5),
                size: 60), // Adjusted size
            const SizedBox(height: 20), // Consistent spacing
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 17, // Adjusted size
                  fontWeight: FontWeight.w500,
                  color: themeProvider.primaryText),
            ),
            const SizedBox(height: 10), // Consistent spacing
            Text(
              'Complete more deliveries to see your performance statistics here.', // More specific advice
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: themeProvider.secondaryText
                      .withOpacity(0.9)), // Adjusted size
            ),
          ],
        ),
      ),
    );
  }
}
