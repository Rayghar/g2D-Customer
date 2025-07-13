// File: lib/screens/admin/admin_active_run_details_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../services/api_service.dart';
import '../../models/admin/admin_run_management_model.dart'; // Ensure this file is correctly updated
// Import screens for navigation
import './admin_order_details_screen.dart';
import './admin_driver_details_screen.dart';
import '../../models/driver_profile_model.dart';
import '../../screens/driver/driver_profile_screen.dart';

class AdminActiveRunDetailsScreen extends StatefulWidget {
  static const String routeName = '/admin_active_run_details';
  final String runId;

  const AdminActiveRunDetailsScreen({super.key, required this.runId});

  @override
  State<AdminActiveRunDetailsScreen> createState() =>
      _AdminActiveRunDetailsScreenState();
}

class _AdminActiveRunDetailsScreenState
    extends State<AdminActiveRunDetailsScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  AdminActiveRunDetailModel? _runData;
  String? _errorMessage;

  GoogleMapController? _mapController;
  // Changed from final to late for assignment in setState
  late Set<Marker> _markers = {};
  late Set<Polyline> _polylines = {};
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _stopPendingIcon;
  BitmapDescriptor? _stopCompletedIcon;
  BitmapDescriptor? _stopIssueIcon;

  late AnimationController _entryAnimController;

  static const CameraPosition _initialCameraPosition =
      CameraPosition(target: LatLng(6.5244, 3.3792), zoom: 10.5);

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _loadCustomMarkerIcons();
    _fetchRunDetails();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCustomMarkerIcons() async {
    _driverIcon = await BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(size: Size(48, 48)),
            'assets/images/marker_driver.png')
        .catchError((e) =>
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure));
    _stopPendingIcon = await BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(size: Size(40, 40)),
            'assets/images/marker_stop_pending.png')
        .catchError((e) =>
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange));
    _stopCompletedIcon = await BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(size: Size(40, 40)),
            'assets/images/marker_stop_completed.png')
        .catchError((e) =>
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen));
    _stopIssueIcon = await BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(size: Size(40, 40)),
            'assets/images/marker_stop_issue.png')
        .catchError((e) =>
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed));
    if (mounted) setState(() {});
  }

  Future<void> _fetchRunDetails({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final fetchedRunData = await _apiService.adminGetRunDetails(widget.runId);
      if (mounted) {
        setState(() {
          _runData = fetchedRunData;
          _isLoading = false;
          _errorMessage = null;
        });
        _updateMapWithRunDetails();
        _entryAnimController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Failed to load run details: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  void _updateMapWithRunDetails() {
    if (!mounted || _runData == null) return;
    final Set<Marker> newMarkers = {};
    final Set<Polyline> newPolylines = {};
    List<LatLng> routePointsForBounds = [];

    if (_runData!.driverInfo.currentLocation != null && _driverIcon != null) {
      newMarkers.add(Marker(
          markerId: MarkerId('driver_${_runData!.driverInfo.id}'),
          position: _runData!.driverInfo.currentLocation!,
          icon: _driverIcon!,
          infoWindow: InfoWindow(
              title: _runData!.driverInfo.name, snippet: "Current Location"),
          onTap: () => _navigateToAdminDriverDetails(_runData!.driverInfo.id)));
      routePointsForBounds.add(_runData!.driverInfo.currentLocation!);
    }

    for (final stop in _runData!.sequencedStops) {
      BitmapDescriptor icon =
          _stopPendingIcon ?? BitmapDescriptor.defaultMarker;
      final statusLower = stop.status.toLowerCase();

      if (statusLower.contains("picked up") ||
          statusLower.contains("delivered") ||
          statusLower.contains("completed")) {
        icon = _stopCompletedIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else if (statusLower.contains("issue") ||
          statusLower.contains("failed")) {
        icon = _stopIssueIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      }

      newMarkers.add(Marker(
          markerId: MarkerId(stop.orderId),
          position: stop.deliveryLocation,
          icon: icon,
          infoWindow: InfoWindow(
              title: "${stop.sequence}. ${stop.recipientName}",
              snippet: "Status: ${stop.status}\nItems: ${stop.itemsPreview}"),
          onTap: () => _navigateToAdminOrderDetails(stop.orderId)));
      routePointsForBounds.add(stop.deliveryLocation);
    }

    if (_runData!.routePolyline != null &&
        _runData!.routePolyline!.isNotEmpty) {
      List<LatLng> decodedPolyline = _decodePolyline(_runData!.routePolyline!);
      if (decodedPolyline.isNotEmpty) {
        newPolylines.add(Polyline(
          polylineId: PolylineId(_runData!.runId),
          points: decodedPolyline,
          color: Theme.of(context).primaryColor.withOpacity(0.7),
          width: 4,
        ));
      }
    }

    setState(() {
      _markers = newMarkers;
      _polylines = newPolylines;
    });

    if (routePointsForBounds.isNotEmpty) {
      _fitBounds(routePointsForBounds);
    }
  }

  Future<void> _fitBounds(List<LatLng> points) async {
    if (_mapController != null && points.isNotEmpty) {
      LatLngBounds bounds = _calculateBounds(points);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _mapController != null) {
          _mapController!
              .animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
        }
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      points.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    return points;
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty)
      return LatLngBounds(
          southwest: const LatLng(0, 0), northeast: const LatLng(0, 0));
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (LatLng point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    if (points.length == 1) {
      minLat -= 0.02;
      maxLat += 0.02;
      minLng -= 0.02;
      maxLng += 0.02;
    }
    return LatLngBounds(
        southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  void _navigateToAdminOrderDetails(String orderId) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, AdminOrderDetailsScreen.routeName,
        arguments: {'orderId': orderId});
  }

  void _navigateToAdminDriverDetails(String driverId) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, AdminDriverDetailsScreen.routeName,
        arguments: {'driverId': driverId});
  }

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color adminAccentColor = themeProvider.gas2doorPurple;
    final String shortRunId =
        _runData?.runId.length != null && _runData!.runId.length > 6
            ? _runData!.runId.substring(_runData!.runId.length - 6)
            : (_runData?.runId ?? widget.runId);

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        title: Text('Run #$shortRunId',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, color: themeProvider.primaryText)),
        backgroundColor: themeProvider.appSecondaryBackground,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: adminAccentColor))
          : _runData == null || _errorMessage != null
              ? _buildErrorState(themeProvider)
              : FadeTransition(
                  opacity: _entryAnimController,
                  child: Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.35,
                        child: GoogleMap(
                          initialCameraPosition:
                              _initialCameraPosition, // Use the static initial position
                          markers: _markers,
                          polylines: _polylines,
                          onMapCreated: (controller) {
                            _mapController = controller;
                            // No need to call _updateMapWithRunDetails here, it's called after fetch
                          },
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          zoomGesturesEnabled: true,
                          scrollGesturesEnabled: true,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchRunDetails,
                          color: adminAccentColor,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRunOverviewCard(themeProvider),
                                const SizedBox(height: 20),
                                Text(
                                  "Stops on Run",
                                  style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: themeProvider.primaryText),
                                ),
                                const SizedBox(height: 10),
                                _buildStopsList(themeProvider),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ---
  // Helper Methods
  // ---

  Widget _buildErrorState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? "An unknown error occurred.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 16, color: themeProvider.secondaryText),
            ),
            const SizedBox(height: 30),
            // Removed isLoading, buttonColor as they might not be defined in your CustomButton
            CustomButton(
              text: "Retry",
              onPressed: _fetchRunDetails,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunOverviewCard(ThemeProvider themeProvider) {
    if (_runData == null) return const SizedBox.shrink();

    return CustomCard(
      // CustomCard might not have a 'child' parameter if it's implicitly handling content.
      // If it takes a 'child', ensure your CustomCard widget definition supports it.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Driver: ${_runData!.driverInfo.name}",
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText),
              ),
              GestureDetector(
                onTap: () =>
                    _navigateToAdminDriverDetails(_runData!.driverInfo.id),
                child: Text(
                  "View Driver",
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: themeProvider.gas2doorPrimaryBlue,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Driver ID: ${_runData!.driverInfo.id}",
            style: GoogleFonts.inter(
                fontSize: 13, color: themeProvider.secondaryText),
          ),
          const SizedBox(height: 8),
          // Accessing vehicleMake, vehicleModel, vehicleLicensePlate - ensure these are in your RunDriverInfo model
          Text(
            "Vehicle: ${_runData!.driverInfo.vehicleMake} ${_runData!.driverInfo.vehicleModel} (${_runData!.driverInfo.vehicleLicensePlate})",
            style: GoogleFonts.inter(
                fontSize: 13, color: themeProvider.secondaryText),
          ),
          const Divider(height: 20),
          _buildInfoRow("Total Stops:",
              "${_runData!.sequencedStops.length} stops", themeProvider),
          _buildInfoRow(
              "Completed Stops:",
              "${_runData!.sequencedStops.where((s) => s.status.toLowerCase().contains('completed')).length}",
              themeProvider),
          _buildInfoRow(
              "Pending Stops:",
              "${_runData!.sequencedStops.where((s) => s.status.toLowerCase().contains('pending')).length}",
              themeProvider),
          _buildInfoRow(
              "Issues:",
              "${_runData!.sequencedStops.where((s) => s.status.toLowerCase().contains('issue') || s.status.toLowerCase().contains('failed')).length}",
              themeProvider),
          if (_runData!.estimatedCompletionTime != null)
            _buildInfoRow(
              "Estimated Completion:",
              DateFormat('h:mm a').format(_runData!.estimatedCompletionTime!),
              themeProvider,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 14, color: themeProvider.secondaryText),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: themeProvider.primaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildStopsList(ThemeProvider themeProvider) {
    if (_runData == null || _runData!.sequencedStops.isEmpty) {
      return Text(
        "No stops found for this run.",
        style: GoogleFonts.inter(color: themeProvider.secondaryText),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _runData!.sequencedStops.length,
      itemBuilder: (context, index) {
        final stop = _runData!.sequencedStops[index];
        return CustomCard(
          // Removed 'padding' parameter as it's likely not defined in CustomCard
          child: _AdminRunStopListItemWidget(
            stop: stop,
            themeProvider: themeProvider,
            onTap: () => _navigateToAdminOrderDetails(stop.orderId),
          ),
        );
      },
    );
  }
}

class _AdminRunStopListItemWidget extends StatelessWidget {
  final AdminOptimizedStopInfo stop;
  final ThemeProvider themeProvider;
  final VoidCallback onTap;

  const _AdminRunStopListItemWidget(
      {required this.stop, required this.themeProvider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Replaced themeProvider.gas2doorOrange with Colors.orangeAccent
    Color statusColor = Colors.orangeAccent; // Default pending
    IconData statusIcon = Icons.pending_actions;

    final statusLower = stop.status.toLowerCase();

    if (statusLower.contains("picked up") ||
        statusLower.contains("delivered") ||
        statusLower.contains("completed")) {
      statusColor = themeProvider.gas2doorTeal;
      statusIcon = Icons.check_circle_outline;
    } else if (statusLower.contains("issue") ||
        statusLower.contains("failed")) {
      statusColor = Colors.redAccent;
      statusIcon = Icons.error_outline;
    }

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      leading: CircleAvatar(
        backgroundColor: themeProvider.gas2doorPrimaryBlue.withOpacity(0.8),
        child: Text(stop.sequence.toString(),
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      title: Text(
          "Order #${stop.orderId.length > 4 ? stop.orderId.substring(stop.orderId.length - 4) : stop.orderId} - ${stop.recipientName}",
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: themeProvider.primaryText)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stop.addressSnippet,
              style: GoogleFonts.inter(
                  fontSize: 13, color: themeProvider.secondaryText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text("Task: ${stop.itemsPreview}",
              style: GoogleFonts.inter(
                  fontSize: 12, color: themeProvider.tertiaryText)),
          if (stop.estimatedPickupTime != null)
            Text(
                "ETA: ${DateFormat('hh:mm a').format(stop.estimatedPickupTime!)}",
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: themeProvider.gas2doorTeal,
                    fontWeight: FontWeight.w500)),
        ],
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  stop.status.capitalizeAdminActiveRun(),
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor),
                ),
              ],
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

extension StringCapitalizeExtensionAdminActiveRun on String {
  String capitalizeAdminActiveRun() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
