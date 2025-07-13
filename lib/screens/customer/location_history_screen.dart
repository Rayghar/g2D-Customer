// File: lib/screens/customer/location_history_screen.dart (Modified - Simplified)

import 'dart:async';
import 'package:flutter/material.dart';
// Removed Maps_flutter import as map is removed
// import 'package:Maps_flutter/Maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
// Removed url_launcher as it's not directly needed for static history screen
// import 'package:url_launcher/url_launcher.dart';
// Removed socket_io_client as live tracking is removed
// import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:intl/intl.dart'; // For DateFormat

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart'; // For retry button
import '../../widgets/card.dart'; // For info panel

// Simplified LocationPoint model (no longer needs toLatLng if not used with map)
// Consider moving this to lib/models/location_point.dart
class LocationPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final String? description; // Added for more context in the list

  LocationPoint(
      {required this.lat,
      required this.lng,
      required this.timestamp,
      this.description});

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      description: json['description'] as String?,
    );
  }
}

class LocationHistoryScreen extends StatefulWidget {
  static const String routeName = '/location_history';
  final String orderId;
  // This screen is typically reached from OrderDetailsScreen, so it might need customerId for context/API
  final String customerId; // <<< ADDED

  const LocationHistoryScreen(
      {super.key,
      required this.orderId,
      required this.customerId}); // <<< ADDED customerId

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<LocationPoint> _locationHistory = [];
  String? _errorMessage;

  // Removed map-related state variables
  // GoogleMapController? _mapController;
  // final Set<Marker> _markers = {};
  // final Set<Polyline> _polylines = {};
  // static const CameraPosition _initialCameraPosition = ...;
  // BitmapDescriptor? _startMarkerIcon;
  // BitmapDescriptor? _endMarkerIcon;

  // Removed animation controller related to old map panel
  // late AnimationController _entryAnimController;
  // late Animation<double> _fadeAnimation;

  late AnimationController
      _listContentAnimationController; // New for list content fade/slide
  late Animation<double> _listContentFadeAnimation;

  @override
  void initState() {
    super.initState();
    _listContentAnimationController = AnimationController(
        // New controller
        vsync: this,
        duration: const Duration(milliseconds: 600));
    _listContentFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _listContentAnimationController, curve: Curves.easeIn));

    // Removed marker icon loading
    // _loadMarkerIcons();
    _fetchLocationHistory();
  }

  @override
  void dispose() {
    _listContentAnimationController.dispose(); // Dispose new controller
    // Removed map controller dispose
    // _mapController?.dispose();
    super.dispose();
  }

  // Removed _loadMarkerIcons method

  Future<void> _fetchLocationHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      // Removed clearing map elements
      // _polylines.clear();
      // _markers.clear();
    });

    // TODO: Replace with actual API call to GET /api/orders/:orderId/location-history
    // This API should return historical location points from driver's device (if stored/enabled)
    // final orderService = Provider.of<OrderService>(context, listen: false);
    // try {
    //   final List<LocationPoint> history = await orderService.getOrderLocationHistory(widget.orderId, widget.customerId); // Pass customer ID
    //   if (mounted) {
    //     _locationHistory = history; // Store fetched history
    //     // Removed map update
    //     // _updateMapWithHistory(history);
    //     setState(() => _isLoading = false);
    //     _listContentAnimationController.forward(); // Animate list content
    //   }
    // } catch (e) {
    //   if (mounted) {
    //     setState(() {
    //       _errorMessage = "Failed to load location history: ${e.toString()}";
    //       _isLoading = false;
    //     });
    //   }
    // }

    // Mock data fetching:
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      // Simulate a route with simple descriptions for list display
      final mockHistory = [
        LocationPoint(
            lat: 6.4500,
            lng: 3.3900,
            timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
            description: "Order confirmed, driver assigned."),
        LocationPoint(
            lat: 6.4550,
            lng: 3.3950,
            timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
            description: "Driver started journey to pickup point."),
        LocationPoint(
            lat: 6.4600,
            lng: 3.4000,
            timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
            description: "Driver is at pickup location."),
        LocationPoint(
            lat: 6.4650,
            lng: 3.4050,
            timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
            description: "Cylinder picked up, driver enroute to gas station."),
        LocationPoint(
            lat: 6.4680,
            lng: 3.4080,
            timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
            description: "Cylinder refilled and ready for delivery."),
        LocationPoint(
            lat: 6.4700,
            lng: 3.4100,
            timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
            description: "Driver is out for delivery!"),
        LocationPoint(
            lat: 6.4750,
            lng: 3.4150,
            timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
            description: "Order is close to your location."),
      ];
      // To test empty state:
      // final List<LocationPoint> mockHistory = [];
      // To test error state:
      // setState(() { _errorMessage = "No history found for this order."; _isLoading = false; }); return;

      _locationHistory = mockHistory; // Store fetched history
      // Removed map update
      // _updateMapWithHistory(mockHistory);
      setState(() => _isLoading = false);
      _listContentAnimationController.forward(); // Animate list content
    }
  }

  // Removed _updateMapWithHistory method as map is gone

  void _showFeedbackSnackbar(String message, BuildContext ctx,
      {bool isError = false}) {
    final themeProvider = Provider.of<ThemeProvider>(ctx, listen: false);
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError
            ? themeProvider.errorColor
            : themeProvider.successColor.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // This screen is pushed OVER the bottom navigation bar by the root navigator
    // It has its own Scaffold and AppBar
    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text(
          'Tracking History for Order #${widget.orderId.length > 6 ? widget.orderId.substring(widget.orderId.length - 6) : widget.orderId}',
          style: GoogleFonts.inter(
              color: themeProvider.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: 16), // Slightly smaller title
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: themeProvider.gas2doorPrimaryBlue))
          : _errorMessage != null
              ? _buildErrorState(themeProvider, _errorMessage!)
              : _locationHistory.isEmpty
                  ? _buildEmptyState(themeProvider)
                  : FadeTransition(
                      opacity: _listContentFadeAnimation,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _locationHistory.length,
                        itemBuilder: (context, index) {
                          final point = _locationHistory[index];
                          return _buildLocationHistoryItem(point, themeProvider,
                              index, _locationHistory.length);
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                      ),
                    ),
    );
  }

  // Helper for displaying individual history items
  Widget _buildLocationHistoryItem(LocationPoint point,
      ThemeProvider themeProvider, int index, int totalItems) {
    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: themeProvider.gas2doorPrimaryBlue,
                      shape: BoxShape.circle),
                ),
                if (index < totalItems - 1)
                  Container(
                    width: 2,
                    height: 50, // Line length between points
                    color: themeProvider.gas2doorPrimaryBlue.withOpacity(0.5),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point.description ??
                        'Location Update', // Display description
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: themeProvider.primaryText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd,yyyy hh:mm a')
                        .format(point.timestamp.toLocal()),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: themeProvider.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Basic Error & Empty States for this screen ---
  Widget _buildErrorState(ThemeProvider themeProvider, String message) {
    return Center(
      child: CustomCard(
        margin: const EdgeInsets.all(30),
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: themeProvider.errorColor, size: 40),
              const SizedBox(height: 16),
              Text('Failed to Load History',
                  style: GoogleFonts.inter(
                      color: themeProvider.primaryText, fontSize: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              CustomButton(
                  text: "Retry",
                  onPressed: _fetchLocationHistory,
                  color: themeProvider.gas2doorPrimaryBlue)
            ],
          ),
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
            Icon(Icons.timeline_outlined,
                color: themeProvider.secondaryText.withOpacity(0.6), size: 70),
            const SizedBox(height: 24),
            Text(
              'No Location History Available',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.primaryText),
            ),
            const SizedBox(height: 12),
            Text(
              'Location updates for this order will appear here as the delivery progresses.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: themeProvider.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
