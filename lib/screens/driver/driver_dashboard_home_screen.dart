// File: lib/screens/driver/driver_dashboard_home_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Corrected Google Maps Import
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Corrected import// Provider import is correct, assuming package is in pubspec.yaml
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
// import 'package:intl/intl.dart'; // Only if needed for date formatting

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
// Import DriverOrderDetailsScreen - make sure its route is defined
import './driver_order_details_screen.dart';

// Re-define the full models here, as this screen uses them extensively
// Consider moving these to lib/models if they are used in other files
class DriverProfile {
  final String id;
  final String name;
  bool isAvailable;
  LatLng? currentLocation;
  // Include stats fields if the summary needs them directly,
  // otherwise, the stats screen handles them. Let's keep summary here.
  int totalOrdersExecuted;
  double totalRevenueMade;
  int totalOrdersCancelled;

  DriverProfile({
    required this.id,
    required this.name,
    this.isAvailable = true,
    this.currentLocation,
    this.totalOrdersExecuted = 0,
    this.totalRevenueMade = 0.0,
    this.totalOrdersCancelled = 0,
  });

  DriverProfile copyWith({
    String? name,
    bool? isAvailable,
    LatLng? currentLocation,
    int? totalOrdersExecuted,
    double? totalRevenueMade,
    int? totalOrdersCancelled,
  }) {
    return DriverProfile(
      id: id,
      name: name ?? this.name,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLocation: currentLocation ?? this.currentLocation,
      totalOrdersExecuted: totalOrdersExecuted ?? this.totalOrdersExecuted,
      totalRevenueMade: totalRevenueMade ?? this.totalRevenueMade,
      totalOrdersCancelled: totalOrdersCancelled ?? this.totalOrdersCancelled,
    );
  }
}

class PickupRunBatch {
  final String id;
  final int orderCount;
  final String zone;
  final double estimatedTimeMinutes;
  final double estimatedEarnings;
  final List<String> orderIds;
  final double totalWeightKg;

  PickupRunBatch({
    required this.id,
    required this.orderCount,
    required this.zone,
    required this.estimatedTimeMinutes,
    required this.estimatedEarnings,
    required this.orderIds,
    required this.totalWeightKg,
  });
}

class OptimizedPickupStop {
  final String orderId;
  final String customerName;
  final String addressSnippet;
  final String fullAddress;
  final LatLng location;
  final int sequence;
  String status;
  final String cylinderDetails;
  final String customerId; // Added customer ID to link to chat
  final String? customerPhoneNumber; // Added phone for call from details

  OptimizedPickupStop({
    required this.orderId,
    required this.customerName,
    required this.addressSnippet,
    required this.fullAddress,
    required this.location,
    required this.sequence,
    this.status = "Pending Pickup",
    required this.cylinderDetails,
    required this.customerId, // Added
    this.customerPhoneNumber, // Added
  });
}
// --- End Models ---

class DriverDashboardHomeScreen extends StatefulWidget {
  // Note: This screen is part of the shell's IndexedStack,
  // it doesn't have its own routeName for direct navigation via pushNamed.
  // static const String routeName = '/driver_dashboard_home'; // NOT NEEDED

  final String driverId; // Receive driver ID from the shell
  // Receive a GlobalKey for its Navigator
  final GlobalKey<NavigatorState> navigatorKey;

  const DriverDashboardHomeScreen({
    super.key,
    required this.driverId,
    required this.navigatorKey,
  });

  @override
  State<DriverDashboardHomeScreen> createState() =>
      _DriverDashboardHomeScreenState();
}

class _DriverDashboardHomeScreenState extends State<DriverDashboardHomeScreen>
    with TickerProviderStateMixin {
  bool _isLoadingProfileAndRuns =
      true; // Combined loading for initial screen data
  bool _isLoadingActiveRunDetails = false;
  bool _isLoadingStatsSummary = true; // Loading for the stats summary card

  DriverProfile? _driverProfile; // Full profile model here

  List<PickupRunBatch> _availablePickupRuns = [];
  List<OptimizedPickupStop> _activeOptimizedRoute = [];
  String? _activeRunId;

  String? _errorMessage; // Error messages specific to this screen's fetches

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  BitmapDescriptor? _driverMarkerIcon;
  BitmapDescriptor? _pickupMarkerIcon;
  BitmapDescriptor? _pickupMarkerDoneIcon;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(6.5244, 3.3792), // Lagos
    zoom: 12.0,
  );

  // Define route names *within* this nested navigator
  static const String rootRoute = '/'; // Root of this tab
  static const String orderDetailsRoute = '/orderDetails';

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcons();
    // Initial fetch for data needed on THIS screen
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (!isRefresh) {
        _isLoadingProfileAndRuns = true;
        _isLoadingStatsSummary = true;
      }
      _errorMessage = null; // Clear previous errors
    });

    // Simulate fetching Profile, Available Runs, AND Stats summary
    // In a real app, you might have separate calls or one combined endpoint
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        // Mock fetched data
        _driverProfile = DriverProfile(
          id: widget.driverId, // Use passed driver ID
          name: "Driver Tunde", // Mock name
          isAvailable: true, // Mock availability
          currentLocation: const LatLng(6.5881, 3.3420), // Mock location
          totalOrdersExecuted: 45, // Mock stats summary
          totalRevenueMade: 78500.0,
          totalOrdersCancelled: 3,
        );

        // Mock Available Pickup Runs Fetch (only if online)
        if (_driverProfile?.isAvailable == true) {
          _availablePickupRuns = [
            PickupRunBatch(
                id: "BATCH001",
                orderCount: 3,
                zone: "Lekki Phase 1 - VI",
                estimatedTimeMinutes: 28,
                estimatedEarnings: 1800,
                totalWeightKg: 37.5,
                orderIds: ["ORDCUST01", "ORDCUST02", "ORDCUST03"]),
            PickupRunBatch(
                id: "BATCH002",
                orderCount: 2,
                zone: "Victoria Island - Ikoyi",
                estimatedTimeMinutes: 22,
                estimatedEarnings: 1200,
                totalWeightKg: 18.5,
                orderIds: ["ORDCUST04", "ORDCUST05"]),
          ];
        } else {
          _availablePickupRuns.clear();
        }

        _isLoadingProfileAndRuns = false;
        _isLoadingStatsSummary = false; // Stats summary loaded with profile
      });
    }
    // TODO: Handle error case and set _errorMessage if fetch fails
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCustomMarkerIcons() async {
    _driverMarkerIcon ??=
        await BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    _pickupMarkerIcon ??=
        await BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    _pickupMarkerDoneIcon ??=
        await BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    if (mounted) setState(() {});
  }

  Future<void> _acceptAndStartRun(PickupRunBatch batch) async {
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar("Accepting run ${batch.id} & optimizing...", context);
    setState(() {
      _isLoadingActiveRunDetails = true;
      _availablePickupRuns
          .removeWhere((b) => b.id == batch.id); // Optimistic UI update
    });

    // Simulate backend call and optimization
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      // IMPORTANT: Backend response for accepted run details
      final mockRoute = [
        OptimizedPickupStop(
            orderId: batch.orderIds[0],
            customerId: "custABC", // Mock Customer ID
            customerPhoneNumber: "08011112222", // Mock Phone Number
            customerName: "Ada Eze", // Use actual customer name
            addressSnippet: "10 Admiralty Way, Lekki",
            fullAddress: "10 Admiralty Way, Lekki Phase 1, Lagos",
            location: const LatLng(6.4320, 3.4520),
            sequence: 1,
            cylinderDetails: "1x 12.5KG",
            status: "Pending Pickup"),
        if (batch.orderIds.length > 1)
          OptimizedPickupStop(
              orderId: batch.orderIds[1],
              customerId: "custDEF", // Mock Customer ID
              customerPhoneNumber: "08033334444", // Mock Phone Number
              customerName: "Bola Ahmed",
              addressSnippet: "25 Kofo Abayomi, VI",
              fullAddress: "25 Kofo Abayomi Street, Victoria Island, Lagos",
              location: const LatLng(6.4280, 3.4300),
              sequence: 2,
              cylinderDetails: "1x 6KG",
              status: "Pending Pickup"),
        if (batch.orderIds.length > 2)
          OptimizedPickupStop(
              orderId: batch.orderIds[2],
              customerId: "custGHI", // Mock Customer ID
              customerPhoneNumber: "08055556666", // Mock Phone Number
              customerName: "Chidi Okeke",
              addressSnippet: "50 Glover Rd, Ikoyi",
              fullAddress: "50 Glover Road, Ikoyi, Lagos",
              location: const LatLng(6.4450, 3.4210),
              sequence: 3,
              cylinderDetails: "1x 12.5KG",
              status: "Pending Pickup"),
      ];

      setState(() {
        _activeRunId = "RUN_${batch.id}";
        _activeOptimizedRoute =
            mockRoute.where((stop) => stop.orderId.isNotEmpty).toList();
        _isLoadingActiveRunDetails = false;
      });
      _updateMapForActiveRun();
      // After accepting a run, driver is likely busy, don't show other available runs
      setState(() {
        _availablePickupRuns.clear(); // Clear available runs
      });
    }
  }

  void _updateMapForActiveRun() {
    if (!mounted) return;
    _markers.clear();
    _polylines.clear();

    if (_activeOptimizedRoute.isEmpty) {
      if (_driverProfile?.currentLocation != null &&
          _driverMarkerIcon != null) {
        _markers.add(Marker(
            markerId: const MarkerId('driver_current_loc'),
            position: _driverProfile!.currentLocation!,
            icon: _driverMarkerIcon!));
        if (_mapController != null)
          _mapController!.animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(
                  target: _driverProfile!.currentLocation!, zoom: 14)));
      }
      setState(() {});
      return;
    }

    List<LatLng> routePoints = [];

    if (_driverProfile?.currentLocation != null && _driverMarkerIcon != null) {
      _markers.add(Marker(
          markerId: const MarkerId('driver_current_loc'),
          position: _driverProfile!.currentLocation!,
          icon: _driverMarkerIcon!,
          infoWindow: const InfoWindow(title: "Your Current Location")));
      routePoints.add(_driverProfile!.currentLocation!);
    }

    for (var stop in _activeOptimizedRoute) {
      bool isPickedUp = stop.status.toLowerCase() == "picked up";
      _markers.add(Marker(
        markerId: MarkerId(stop.orderId),
        position: stop.location,
        icon: isPickedUp
            ? (_pickupMarkerDoneIcon ?? BitmapDescriptor.defaultMarker)
            : (_pickupMarkerIcon ?? BitmapDescriptor.defaultMarker),
        infoWindow: InfoWindow(
            title: "${stop.sequence}. ${stop.customerName}",
            snippet: "${stop.addressSnippet} (${stop.cylinderDetails})"),
        onTap: () => _navigateToDriverStopDetails(stop),
      ));
      routePoints.add(stop.location);
    }

    if (routePoints.length >= 2) {
      _polylines.add(Polyline(
        polylineId: PolylineId(_activeRunId ?? 'active_run_route'),
        points: routePoints,
        color: Theme.of(context).primaryColor.withOpacity(0.8),
        width: 5,
      ));
    }

    if (_mapController != null && _markers.isNotEmpty) {
      LatLngBounds bounds = _calculateBounds(routePoints);
      Future.delayed(const Duration(milliseconds: 100), () {
        _mapController
            ?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70.0));
      });
    }
    setState(() {});
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
          southwest: _initialCameraPosition.target,
          northeast: _initialCameraPosition.target);
    }
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (LatLng point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    if (points.length == 1) {
      minLat -= 0.005;
      maxLat += 0.005;
      minLng -= 0.005;
      maxLng += 0.005;
    }
    return LatLngBounds(
        southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  // --- Navigation to DriverOrderDetailsScreen ---
  void _navigateToDriverStopDetails(OptimizedPickupStop stop) {
    HapticFeedback.lightImpact();
    // Use the route name defined in DriverOrderDetailsScreen
    // Use the internal navigator if available, otherwise the root navigator
    NavigatorState? navigator = widget.navigatorKey.currentState;
    if (navigator == null || !mounted) {
      // Fallback to root navigator if internal one isn't ready or screen is unmounted
      Navigator.pushNamed(context, DriverOrderDetailsScreen.routeName,
          arguments: {
            'orderId': stop.orderId,
            'customerName': stop.customerName,
            'fullAddress': stop.fullAddress,
            'cylinderDetails': stop.cylinderDetails,
            'initialStopStatus': stop.status, // Pass the current status
            'location': stop.location, // Pass location if needed in details
            'sequenceNumber': stop.sequence, // Pass sequence
            'customerId': stop.customerId, // Pass customer ID for chat link
            'customerPhoneNumber':
                stop.customerPhoneNumber, // Pass phone number for call link
            'driverId': widget.driverId, // Pass the current driver's ID
          }).then((result) =>
          _handleDetailsResult(result, stop)); // Use dedicated handler
      return;
    }

    navigator.pushNamed(orderDetailsRoute, // Use internal route name
        arguments: {
          'orderId': stop.orderId,
          'customerName': stop.customerName,
          'fullAddress': stop.fullAddress,
          'cylinderDetails': stop.cylinderDetails,
          'initialStopStatus': stop.status, // Pass the current status
          'location': stop.location, // Pass location if needed in details
          'sequenceNumber': stop.sequence, // Pass sequence
          'customerId': stop.customerId, // Pass customer ID for chat link
          'customerPhoneNumber':
              stop.customerPhoneNumber, // Pass phone number for call link
          'driverId': widget.driverId, // Pass the current driver's ID
        }).then((result) =>
        _handleDetailsResult(result, stop)); // Use dedicated handler
  }

  // Handler for the result coming back from DriverOrderDetailsScreen
  void _handleDetailsResult(dynamic result, OptimizedPickupStop originalStop) {
    if (!mounted) return; // Check if widget is still mounted

    if (result != null && result is Map<String, dynamic>) {
      final newStatus = result['newStatus'] as String?;
      final updatedOrderId = result['orderId'] as String?;

      if (newStatus != null &&
          updatedOrderId != null &&
          updatedOrderId == originalStop.orderId) {
        // Update the status of the stop in the local _activeOptimizedRoute list
        setState(() {
          final index = _activeOptimizedRoute
              .indexWhere((s) => s.orderId == originalStop.orderId);
          if (index != -1) {
            _activeOptimizedRoute[index].status = newStatus;
          }
        });
        // Update the map markers to reflect the status change
        _updateMapForActiveRun();

        // Check if all pickups in the current run are completed or have issues
        // Use status keys consistent with potential customer timeline mapping
        bool allDone = _activeOptimizedRoute.every((s) =>
            // Add statuses that indicate the driver is finished with this stop
            s.status == "Cylinder Picked Up by Driver" ||
            s.status == "Pickup Failed: Customer Unavailable" ||
            s.status == "Pickup Failed: Issue Reported");

        if (allDone) {
          // All stops processed, maybe end the run or show a completion message
          _showFeedbackSnackbar("All pickups processed for this run!", context);
          // Optionally prompt the driver to end the run or auto-end
          Future.delayed(const Duration(seconds: 3), () {
            // Show snackbar then auto-end
            if (mounted) _endCurrentRun();
          });
        }
      }
    }
  }

  void _endCurrentRun({bool showSnackbar = true}) {
    HapticFeedback.mediumImpact();
    setState(() {
      _activeOptimizedRoute.clear();
      _activeRunId = null;
      _markers.clear();
      _polylines.clear();
    });
    if (showSnackbar)
      _showFeedbackSnackbar("Current pickup run ended.", context);
    // After ending the run, refresh the dashboard to show available runs again
    _fetchDashboardData(isRefresh: true);
    if (_mapController != null && _driverProfile?.currentLocation != null) {
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: _driverProfile!.currentLocation!, zoom: 12)));
    } else if (_mapController != null) {
      _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(_initialCameraPosition));
    }
  }

  // Use a snackbar helper specific to this screen if needed, or rely on the shell's
  void _showFeedbackSnackbar(String message, BuildContext ctx,
      {bool isError = false}) {
    // Here, we can access ThemeProvider directly
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

    // The content of this screen is now wrapped in an internal Navigator
    // This Navigator handles navigation *within* the Dashboard tab (e.g., to Order Details)
    return Navigator(
      key: widget.navigatorKey, // Assign the key received from the shell
      initialRoute: rootRoute, // Define the root route for this tab
      onGenerateRoute: (RouteSettings settings) {
        WidgetBuilder builder;
        // Handle routes specific to this tab's navigation
        switch (settings.name) {
          case rootRoute:
            // The main content of the Dashboard tab
            builder = (BuildContext context) =>
                _buildDashboardContent(context, themeProvider);
            break;
          case orderDetailsRoute: // Route for DriverOrderDetailsScreen within this tab
            // Arguments are passed from _navigateToDriverStopDetails
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              builder = (BuildContext context) => DriverOrderDetailsScreen(
                    orderId: args['orderId'] as String,
                    customerName: args['customerName'] as String,
                    fullAddress: args['fullAddress'] as String,
                    cylinderDetails: args['cylinderDetails'] as String,
                    initialStopStatus: args['initialStopStatus'] as String,
                    customerPhoneNumber: args['customerPhoneNumber'] as String?,
                    customerId: args['customerId'] as String?,
                    sequenceNumber: args['sequenceNumber'] as int?,
                    driverId: args['driverId'] as String, // Pass the driverId
                  );
            } else {
              // Handle missing arguments for order details
              builder = (BuildContext context) => Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: Center(
                      child: Text(
                          'Error: Missing order details arguments for ${settings.name}')));
            }
            break;

          default:
            // Should not happen if routing within the tab is managed correctly
            builder = (BuildContext context) => Scaffold(
                  body: Center(
                      child: Text(
                          'Unknown route: ${settings.name} in Dashboard tab')),
                );
        }
        return MaterialPageRoute(builder: builder, settings: settings);
      },
    );
  }

  // --- New method to build the main content of the Dashboard tab root ---
  Widget _buildDashboardContent(
      BuildContext context, ThemeProvider themeProvider) {
    // Add a RefreshIndicator only to the main content of this screen
    return RefreshIndicator(
      onRefresh: () => _fetchDashboardData(isRefresh: true),
      color: themeProvider.gas2doorPrimaryBlue,
      backgroundColor: themeProvider.cardBackground,
      child:
          _isLoadingProfileAndRuns // Check combined loading state for main content
              ? Center(
                  child: CircularProgressIndicator(
                      color: themeProvider.gas2doorPrimaryBlue))
              : ListView(
                  // Use ListView to allow scrolling even if content is shorter than screen
                  padding:
                      const EdgeInsets.only(top: 12.0), // Padding at the top
                  children: [
                    // Always show stats summary at the top of the dashboard view
                    _buildDriverStatsSummary(themeProvider),
                    const SizedBox(height: 12), // Spacing after stats summary

                    // Display either the active run section or the available runs section
                    if (_activeOptimizedRoute.isNotEmpty)
                      _buildActiveRunSection(themeProvider)
                    else
                      _buildAvailableRunsSection(themeProvider),

                    // Ensure there's some padding at the very bottom
                    const SizedBox(height: 20.0),
                  ],
                ),
    );
  }

  // --- Build Active Run Section ---
  Widget _buildActiveRunSection(ThemeProvider themeProvider) {
    // This logic was previously inside the main build method's conditional branch
    if (_isLoadingActiveRunDetails && _activeOptimizedRoute.isEmpty) {
      return Center(
          child: CircularProgressIndicator(
              color: themeProvider.gas2doorPrimaryBlue));
    }

    // Changed to return a Column directly to be a child of the parent ListView
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height *
              0.40, // Adjust height as needed
          child: GoogleMap(
            initialCameraPosition:
                _initialCameraPosition, // This will be updated by animateCamera later
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _updateMapForActiveRun();
            },
            markers: _markers,
            polylines: _polylines,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            padding: const EdgeInsets.only(bottom: 10, top: 10),
          ),
        ),
        // Use a card header or just text for the list title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text("Pickup Stops",
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.primaryText)),
        ),
        ListView.separated(
          // This list of stops should be inside the ListView of the home screen
          physics:
              const NeverScrollableScrollPhysics(), // Prevent ListView nesting scroll issues
          shrinkWrap: true, // Essential for ListView inside ListView
          padding: const EdgeInsets.symmetric(
              horizontal: 12.0, vertical: 0.0), // Apply padding here
          itemCount: _activeOptimizedRoute.length,
          itemBuilder: (context, index) {
            final stop = _activeOptimizedRoute[index];
            return _OptimizedStopCardWidget(
              stop: stop,
              themeProvider: themeProvider,
              onNavigate: () {
                // TODO: Implement actual navigation to stop location (e.g., using url_launcher with geo: scheme)
                _showFeedbackSnackbar(
                    "Navigation to ${stop.addressSnippet} not implemented yet.",
                    context);
              },
              onUpdateStatus: () => _navigateToDriverStopDetails(stop),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(height: 10),
        ),

        if (_activeOptimizedRoute
            .isNotEmpty) // Only show end run button if there's a run
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomButton(
              text: "End Current Pickup Run",
              onPressed: () => _endCurrentRun(),
              color: themeProvider.errorColor.withOpacity(0.85),
              icon: Icon(Icons.cancel_schedule_send_outlined,
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white),
            ),
          )
      ],
    );
  }

  // --- Build Available Runs Section ---
  Widget _buildAvailableRunsSection(ThemeProvider themeProvider) {
    // This logic was previously inside the main build method's conditional branch
    // Corrected loading check: Use _isLoadingProfileAndRuns for initial load check
    if (_isLoadingProfileAndRuns &&
        _availablePickupRuns.isEmpty &&
        _errorMessage == null) {
      return _buildLoadingShimmer(themeProvider, 2); // itemCount for shimmer
    }
    if (_errorMessage != null) {
      return _buildErrorState(themeProvider);
    }
    if (_availablePickupRuns.isEmpty) {
      // Note: Pass _driverProfile.isAvailable from the state if available
      bool isOnline = _driverProfile?.isAvailable ??
          true; // Default to true if profile not loaded/null
      return _buildEmptyState(
          themeProvider, "No pickup runs available currently.",
          isOnline: isOnline);
    }

    return ListView.builder(
      // This list of batches should be inside the ListView of the home screen
      physics:
          const NeverScrollableScrollPhysics(), // Prevent ListView nesting scroll issues
      shrinkWrap: true, // Essential for ListView inside ListView
      padding: const EdgeInsets.symmetric(
          horizontal: 12.0, vertical: 0.0), // Apply padding here
      itemCount: _availablePickupRuns.length,
      itemBuilder: (context, index) {
        final batch = _availablePickupRuns[index];
        return _PickupRunBatchCardWidget(
          batch: batch,
          themeProvider: themeProvider,
          onAccept: () => _acceptAndStartRun(batch),
        );
      },
    );
  }

  // --- Build Stats Summary Section (for Dashboard tab) ---
  Widget _buildDriverStatsSummary(ThemeProvider themeProvider) {
    return CustomCard(
      margin: const EdgeInsets.symmetric(
          horizontal: 12), // Apply horizontal margin here
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _isLoadingStatsSummary // Use specific loading for stats summary if needed separately
                ? _buildSkeletonItem(height: 80, themeProvider: themeProvider)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Your Performance Snapshot",
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.primaryText)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                              Icons.check_circle_outline,
                              _driverProfile?.totalOrdersExecuted.toString() ??
                                  '0',
                              "Orders", // Use profile data
                              themeProvider.successColor,
                              themeProvider),
                          _buildStatItem(
                              Icons.attach_money_rounded,
                              "₦${_driverProfile?.totalRevenueMade.toStringAsFixed(0) ?? '0'}",
                              "Revenue", // Use profile data
                              themeProvider.gas2doorPrimaryBlue,
                              themeProvider),
                          _buildStatItem(
                              Icons.cancel_outlined,
                              _driverProfile?.totalOrdersCancelled.toString() ??
                                  '0',
                              "Cancelled", // Use profile data
                              themeProvider.errorColor,
                              themeProvider),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }

  // Helper for Stats Summary items
  Widget _buildStatItem(IconData icon, String value, String label, Color color,
      ThemeProvider themeProvider) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: themeProvider.primaryText)),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, color: themeProvider.secondaryText)),
      ],
    );
  }

  // --- Helper for skeleton loading items ---
  Widget _buildSkeletonItem(
      {double height = 50,
      double width = double.infinity,
      EdgeInsetsGeometry? margin,
      required ThemeProvider themeProvider}) {
    return Container(
      height: height,
      width: width,
      margin: margin ??
          const EdgeInsets.symmetric(
              vertical: 0.0), // No vertical margin by default in list item
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.grey[800]!.withOpacity(0.5)
            : Colors.grey[300]!.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12.0),
      ),
    );
  }

  // --- Method for building loading shimmer list ---
  Widget _buildLoadingShimmer(ThemeProvider themeProvider, int itemCount) {
    return ListView.builder(
      physics:
          const NeverScrollableScrollPhysics(), // Prevent scrolling shimmer list
      shrinkWrap: true,
      padding: const EdgeInsets.all(12.0), // Apply padding here
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return CustomCard(
          margin: const EdgeInsets.only(bottom: 16.0),
          color: themeProvider.cardBackground,
          borderRadius: themeProvider.cardBorderRadiusValue,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonLine(
                    width: 180,
                    height: 20,
                    themeProvider: themeProvider,
                    borderRadius: 5),
                const SizedBox(height: 10),
                _buildSkeletonLine(
                    width: double.infinity,
                    height: 16,
                    themeProvider: themeProvider),
                const SizedBox(height: 6),
                _buildSkeletonLine(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 16,
                    themeProvider: themeProvider),
                const SizedBox(height: 12),
                Align(
                    alignment: Alignment.centerRight,
                    child: _buildSkeletonLine(
                        width: 100,
                        height: 36,
                        themeProvider: themeProvider,
                        borderRadius: 8)),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Helper for skeleton lines within cards ---
  Widget _buildSkeletonLine(
      {required double width,
      required double height,
      required ThemeProvider themeProvider,
      double borderRadius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.grey[700]!.withOpacity(0.6)
            : Colors.grey[300]!,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  // --- Error and Empty States (moved here) ---
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
            Text('Oops! Something Went Wrong',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Failed to load data. Please check your connection and try again.',
              style: GoogleFonts.inter(
                  color: themeProvider.secondaryText, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: "Retry",
              onPressed: () => _fetchDashboardData(
                  isRefresh: true), // Retry dashboard fetches
              color: themeProvider.gas2doorPrimaryBlue,
              icon: Icon(Icons.refresh_rounded,
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider, String message,
      {required bool isOnline}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                isOnline
                    ? Icons.explore_off_outlined
                    : Icons.power_settings_new_rounded,
                color: themeProvider.secondaryText.withOpacity(0.6),
                size: 70),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.primaryText),
            ),
            if (!isOnline) ...[
              // Only show this hint if offline
              const SizedBox(height: 12),
              Text(
                'Toggle your status to "Online" to see available pickup runs.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14, color: themeProvider.secondaryText),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// --- Reusable Card Widgets (Keep these helpers here or in a shared file) ---
// Moved these from the shell as they are used specifically in this screen
class _PickupRunBatchCardWidget extends StatelessWidget {
  final PickupRunBatch batch;
  final ThemeProvider themeProvider;
  final VoidCallback onAccept;

  const _PickupRunBatchCardWidget({
    required this.batch,
    required this.themeProvider,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 16),
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Pickup Run: ${batch.zone}",
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.pin_drop_outlined,
                "${batch.orderCount} Pickups", themeProvider),
            _buildInfoRow(
                Icons.scale_outlined,
                "Total Weight: ~${batch.totalWeightKg.toStringAsFixed(1)} kg",
                themeProvider),
            _buildInfoRow(
                Icons.timer_outlined,
                "Est. ${batch.estimatedTimeMinutes.toInt()} mins",
                themeProvider),
            _buildInfoRow(
                Icons.attach_money_rounded,
                "Est. Earnings: ₦${batch.estimatedEarnings.toStringAsFixed(0)}",
                themeProvider),
            const SizedBox(height: 16),
            CustomButton(
              text: "View Details & Accept Run",
              onPressed: onAccept,
              color: themeProvider.gas2doorTeal,
              icon: Icon(Icons.directions_run_rounded,
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white,
                  size: 18),
              height: 45,
              textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String text, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: themeProvider.secondaryText.withOpacity(0.9)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: themeProvider.secondaryText,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptimizedStopCardWidget extends StatelessWidget {
  final OptimizedPickupStop stop;
  final ThemeProvider themeProvider;
  final VoidCallback onNavigate;
  final VoidCallback onUpdateStatus;

  const _OptimizedStopCardWidget({
    required this.stop,
    required this.themeProvider,
    required this.onNavigate,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    bool isPickedUp = stop.status.toLowerCase() == "picked up";
    Color statusColor = isPickedUp
        ? themeProvider.successColor
        : (stop.status.toLowerCase().contains("issue")
            ? themeProvider.errorColor
            : themeProvider.warningColor);

    return CustomCard(
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: themeProvider.gas2doorPrimaryBlue,
                  child: Text(stop.sequence.toString(),
                      style: GoogleFonts.inter(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(stop.customerName,
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.primaryText))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(15)),
                  child: Text(stop.status,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
                padding: const EdgeInsets.only(left: 44.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.addressSnippet,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: themeProvider.secondaryText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text("Details: ${stop.cylinderDetails}",
                        style: GoogleFonts.inter(
                            fontSize: 13, color: themeProvider.tertiaryText)),
                  ],
                )),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.navigation_outlined,
                      size: 18, color: themeProvider.gas2doorTeal),
                  label: Text("Navigate",
                      style: GoogleFonts.inter(
                          color: themeProvider.gas2doorTeal,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                  onPressed: onNavigate,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10)),
                ),
                const SizedBox(width: 8),
                CustomButton(
                  text: stop.status == "Pending Pickup"
                      ? "View Details"
                      : (isPickedUp ? "View/Log Issue" : "Update Status"),
                  onPressed: onUpdateStatus,
                  color: isPickedUp
                      ? themeProvider.secondaryText.withOpacity(0.2)
                      : themeProvider.gas2doorPrimaryBlueLightVer,
                  textStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isPickedUp
                          ? themeProvider.secondaryText
                          : (themeProvider.infoColorOnDarkBgs ?? Colors.white)),
                  height: 38,
                  borderRadius: 8,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
