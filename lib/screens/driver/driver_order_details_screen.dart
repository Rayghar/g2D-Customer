// File: lib/screens/driver/driver_order_details_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
// import 'package:intl/intl.dart'; // If displaying dates/times

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/input.dart'; // For issue reporting dialog
import '../customer/chat_screen.dart'; // For ChatScreen.routeName

// TODO: Import your actual OrderService, UserService, AuthProvider
// import '../../services/order_service.dart';
// import '../../services/auth_service.dart'; // To get currentDriverId

class DriverOrderDetailsScreen extends StatefulWidget {
  static const String routeName = '/driver_order_details';

  final String orderId;
  final String customerName;
  final String fullAddress;
  final String cylinderDetails; // e.g., "1x 12.5KG, 2x 5KG Empty"
  final String initialStopStatus;
  final String? customerPhoneNumber;
  final String? customerId; // For chat
  final int? sequenceNumber; // Optional: "Stop X of Y"
  final String driverId; // <<< ADDED: Driver's own ID

  const DriverOrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.fullAddress,
    required this.cylinderDetails,
    required this.initialStopStatus,
    this.customerPhoneNumber,
    this.customerId,
    this.sequenceNumber,
    required this.driverId, // <<< REQUIRED NOW
  });

  @override
  State<DriverOrderDetailsScreen> createState() =>
      _DriverOrderDetailsScreenState();
}

class _DriverOrderDetailsScreenState extends State<DriverOrderDetailsScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  late String _currentLocalStatus;

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _sectionSlideAnimations;

  @override
  void initState() {
    super.initState();
    _currentLocalStatus = widget.initialStopStatus;

    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _sectionSlideAnimations = List.generate(
      3, // Assuming 3 main sections in the UI
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(0.1 + (index * 0.15),
              0.8 + (index * 0.1).clamp(0.0, 1.0), // Clamped max to 1.0
              curve: Curves.easeOutCubic),
        ),
      ),
    );
    _entryAnimController.forward();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  // Updated to pop back statuses that align with customer timeline/driver actions
  Future<void> _updatePickupStatus(String driverActionStatus,
      {String? driverNotes}) async {
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Map driver actions/statuses to potential customer-facing statuses for pop result
    String statusToPop;
    switch (driverActionStatus) {
      case "At Location":
        statusToPop =
            "Driver Enroute to Pickup Cylinder"; // Re-using existing customer key for demo, though "At Pickup Location" would be better
        break;
      case "Cylinder Picked Up by Driver":
        statusToPop =
            "Driver Enroute to Gas Station"; // Or "Out for Delivery" if it's the final pickup
        break;
      case "Customer Unavailable for Pickup":
        statusToPop =
            "Pickup Failed: Customer Unavailable"; // Using a specific driver-side failure key
        break;
      case "Pickup Issue Reported by Driver":
        statusToPop =
            "Pickup Failed: Issue Reported"; // Using a specific driver-side failure key
        break;
      // Add other potential statuses if needed
      default:
        statusToPop = driverActionStatus; // Default to the status itself
    }

    // TODO: Replace with actual API call to update status on the backend
    // Pass widget.orderId, driverActionStatus, and optionally driverNotes
    print(
        "MOCK API CALL: Driver action for order ${widget.orderId}: $driverActionStatus");
    if (driverNotes != null) print("MOCK API CALL: Notes: $driverNotes");

    // Mock update simulation:
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      _showFeedbackSnackbar(
          'Status updated to "$driverActionStatus"${driverNotes != null && driverNotes.isNotEmpty ? ' with notes: "$driverNotes"' : ''} (mock).',
          context);

      // Update local status immediately for UI responsiveness
      setState(() {
        _currentLocalStatus =
            driverActionStatus; // Update local status to the driver action
        _isLoading = false; // Set loading false after mock API completes
      });

      // Pop after a short delay to show snackbar, returning the status relevant to the HOME screen's list
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context, {
            'orderId': widget.orderId,
            'newStatus': statusToPop
          }); // Pop back mapped status
        }
      });
    }
    // No need to set _isLoading = false if navigating away (handled inside mounted check)
  }

  Future<void> _launchNavigation() async {
    HapticFeedback.lightImpact();
    String query = Uri.encodeComponent(widget.fullAddress);
    // Try Google Maps first, then a generic geo intent
    Uri googleMapsUrl =
        Uri.parse('google.navigation:q=$query&mode=d'); // d for driving
    Uri geoUrl = Uri.parse('geo:0,0?q=$query'); // Generic geo intent

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted)
          _showFeedbackSnackbar('Could not launch maps application.', context,
              isError: true);
      }
    } catch (e) {
      print("Error launching maps: $e");
      if (mounted)
        _showFeedbackSnackbar('Error launching maps application.', context,
            isError: true);
    }
  }

  Future<void> _makePhoneCall() async {
    if (widget.customerPhoneNumber == null ||
        widget.customerPhoneNumber!.isEmpty) {
      _showFeedbackSnackbar('Customer phone number not available.', context,
          isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    final Uri launchUri = Uri(scheme: 'tel', path: widget.customerPhoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted)
          _showFeedbackSnackbar('Could not launch phone dialer.', context,
              isError: true);
      }
    } catch (e) {
      print("Error launching phone dialer: $e");
      if (mounted)
        _showFeedbackSnackbar('Error launching phone dialer.', context,
            isError: true);
    }
  }

  void _navigateToChat() {
    HapticFeedback.lightImpact();
    if (widget.customerId == null) {
      _showFeedbackSnackbar('Customer ID not available for chat.', context,
          isError: true);
      return;
    }
    // Use the driverId passed to THIS screen
    final String currentDriverId = widget.driverId;

    // Use the route name defined in ChatScreen from main.dart (or shared folder)
    // Ensure the parent navigator is used (popUntil if needed)
    Navigator.pushNamed(
        context, '/chat', // Use the global route name defined in main.dart
        arguments: {
          'orderId': widget.orderId,
          'currentUserId': currentDriverId, // Pass the driver's ID
          'recipientId': widget.customerId!, // Pass the customer's ID
          'recipientName': widget.customerName, // Pass customer name
          'recipientPhoneNumber': widget
              .customerPhoneNumber, // Pass phone if needed in chat screen header
          // 'recipientPhotoUrl': 'customer_photo_url_placeholder', // Include if available
        });
  }

  Future<void> _reportIssueDialog() async {
    HapticFeedback.mediumImpact();
    String? issueNotes;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    issueNotes = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) {
          TextEditingController notesController = TextEditingController();
          return AlertDialog(
            backgroundColor: themeProvider.cardBackground,
            shape: RoundedRectangleBorder(
                borderRadius: themeProvider.cardBorderRadius),
            title: Text('Report Pickup Issue',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600)),
            content: CustomInput(
              controller: notesController,
              hintText:
                  'Describe the issue (e.g., cylinder damaged, customer not home after waiting, wrong size provided)...',
              labelText: "Issue Notes",
              maxLines: 4,
              minLines: 2,
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(
                          color: themeProvider.secondaryText))),
              TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, notesController.text.trim()),
                  child: Text('Submit Notes',
                      style: GoogleFonts.inter(
                          color: themeProvider.gas2doorPrimaryBlue,
                          fontWeight: FontWeight.w600))),
            ],
          );
        });

    if (issueNotes != null) {
      // Call the status update with the specific status and notes
      _updatePickupStatus(
          "Pickup Issue Reported by Driver", // This is the driver action
          driverNotes: issueNotes.isNotEmpty
              ? issueNotes
              : "No specific notes provided."); // Send notes to backend
    }
  }

  void _showFeedbackSnackbar(String message, BuildContext ctx,
      {bool isError = false}) {
    if (!mounted) return;
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
    final shortOrderId = widget.orderId.length > 6
        ? widget.orderId.substring(widget.orderId.length - 6)
        : widget.orderId;
    final appBarTitle = widget.sequenceNumber != null
        ? "Stop ${widget.sequenceNumber}: Order #$shortOrderId"
        : "Pickup: Order #$shortOrderId";

    // Determine button visibility based on current local status
    // These checks use the driver's granular local status (_currentLocalStatus)
    bool canMarkPickedUp = _currentLocalStatus
            .toLowerCase()
            .contains("pending") ||
        _currentLocalStatus.toLowerCase().contains(
            "enroute") || // Assuming "Enroute" can also be updated to picked up
        _currentLocalStatus
            .toLowerCase()
            .contains("at location"); // Assuming "At Location" can be updated

    bool canReportIssueOrNotAvailable = !_currentLocalStatus
            .toLowerCase()
            .contains("picked up") && // Already completed pickup
        !_currentLocalStatus
            .toLowerCase()
            .contains("unavailable") && // Already marked unavailable
        !_currentLocalStatus
            .toLowerCase()
            .contains("issue"); // Already reported issue

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text(
          appBarTitle,
          style: GoogleFonts.inter(
              color: themeProvider.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: 17),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          // Pop with the latest local status when backing out
          // The status returned here should ideally map to a state the calling screen (Home Tab) understands
          onPressed: () => Navigator.of(context).pop({
            'orderId': widget.orderId,
            'newStatus': _currentLocalStatus
          }), // Popping back the driver's last action status
        ),
      ),
      body: FadeTransition(
        opacity: _entryAnimController,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SlideTransition(
                position: _sectionSlideAnimations[0],
                child: CustomCard(
                  color: themeProvider.cardBackground,
                  borderRadius: themeProvider.cardBorderRadiusValue,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pickup For: ${widget.customerName}',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.primaryText)),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined,
                                color: themeProvider.secondaryText, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(widget.fullAddress,
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: themeProvider.secondaryText,
                                        height: 1.4))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: CustomButton(
                                text: 'Navigate',
                                onPressed: _isLoading
                                    ? null
                                    : _launchNavigation, // Disable if loading
                                color: themeProvider.gas2doorPrimaryBlue
                                    .withOpacity(0.15),
                                textStyle: GoogleFonts.inter(
                                    color: themeProvider.gas2doorPrimaryBlue,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                                icon: Icon(Icons.navigation_rounded,
                                    color: themeProvider.gas2doorPrimaryBlue,
                                    size: 20),
                                height: 45,
                                elevation: 0,
                              ),
                            ),
                            if (widget.customerPhoneNumber != null &&
                                widget.customerPhoneNumber!.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: CustomButton(
                                  text: 'Call',
                                  onPressed: _isLoading
                                      ? null
                                      : _makePhoneCall, // Disable if loading
                                  color: themeProvider.gas2doorTeal
                                      .withOpacity(0.15),
                                  textStyle: GoogleFonts.inter(
                                      color: themeProvider.gas2doorTeal,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                  icon: Icon(Icons.call_outlined,
                                      color: themeProvider.gas2doorTeal,
                                      size: 20),
                                  height: 45,
                                  elevation: 0,
                                ),
                              ),
                            ],
                            if (widget.customerId != null) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: CustomButton(
                                  text: 'Chat',
                                  onPressed: _isLoading
                                      ? null
                                      : _navigateToChat, // Disable if loading
                                  color: themeProvider.gas2doorPurple
                                      .withOpacity(0.15),
                                  textStyle: GoogleFonts.inter(
                                      color: themeProvider.gas2doorPurple,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                  icon: Icon(Icons.chat_bubble_outline_rounded,
                                      color: themeProvider.gas2doorPurple,
                                      size: 20),
                                  height: 45,
                                  elevation: 0,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SlideTransition(
                position: _sectionSlideAnimations[1],
                child: CustomCard(
                  color: themeProvider.cardBackground,
                  borderRadius: themeProvider.cardBorderRadiusValue,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cylinders to Pickup:',
                            style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: themeProvider.primaryText)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.propane_tank_outlined,
                                color: themeProvider.secondaryText, size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(widget.cylinderDetails,
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: themeProvider.primaryText,
                                        fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SlideTransition(
                position: _sectionSlideAnimations[2],
                child: CustomCard(
                  color: themeProvider.cardBackground,
                  borderRadius: themeProvider.cardBorderRadiusValue,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Update Pickup Status:',
                            style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: themeProvider.primaryText)),
                        const SizedBox(height: 4),
                        Text('Current: $_currentLocalStatus',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: themeProvider.secondaryText,
                                fontStyle: FontStyle.italic)),
                        const SizedBox(height: 16),
                        // Only show status buttons if they are applicable based on DRIVER'S local status
                        if (canMarkPickedUp) ...[
                          // Added 'At Location' button based on common workflow
                          if (_currentLocalStatus.toLowerCase() !=
                              "at location")
                            CustomButton(
                              text: _isLoading &&
                                      _currentLocalStatus.toLowerCase() ==
                                          "at location"
                                  ? 'Updating...'
                                  : 'I am at Location',
                              onPressed: _isLoading
                                  ? null
                                  : () => _updatePickupStatus(
                                      "At Location"), // Driver action
                              color: themeProvider.gas2doorPrimaryBlue,
                              icon: Icon(Icons.location_on_outlined,
                                  color: themeProvider.infoColorOnDarkBgs ??
                                      Colors.white),
                              height: 50,
                              textStyle: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: themeProvider.infoColorOnDarkBgs ??
                                      Colors.white),
                            ),
                          if (_currentLocalStatus.toLowerCase() ==
                                  "at location" ||
                              _currentLocalStatus
                                  .toLowerCase()
                                  .contains("pending"))
                            const SizedBox(height: 12),

                          CustomButton(
                            text: _isLoading &&
                                    _currentLocalStatus.contains(
                                        "Cylinder Picked Up by Driver")
                                ? 'Updating...'
                                : 'Confirm Cylinder(s) Picked Up',
                            onPressed: _isLoading
                                ? null
                                : () => _updatePickupStatus(
                                    "Cylinder Picked Up by Driver"), // Driver action
                            color: themeProvider.successColor,
                            icon: Icon(Icons.check_circle_outline_rounded,
                                color: themeProvider.infoColorOnDarkBgs ??
                                    Colors.white,
                                size: 22),
                            height: 50,
                            textStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: themeProvider.infoColorOnDarkBgs ??
                                    Colors.white),
                          ),
                          if (canReportIssueOrNotAvailable)
                            const SizedBox(
                                height:
                                    12), // Spacing if report buttons will show
                        ],
                        if (canReportIssueOrNotAvailable) ...[
                          CustomButton(
                            text: _isLoading &&
                                    _currentLocalStatus
                                        .contains("Customer Unavailable")
                                ? 'Updating...'
                                : 'Customer Not Available',
                            onPressed: _isLoading
                                ? null
                                : () => _updatePickupStatus(
                                    "Customer Unavailable for Pickup"), // Driver action
                            color: themeProvider.warningColor.withOpacity(0.9),
                            textStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: themeProvider.isDarkMode
                                    ? Colors
                                        .black87 // Ensure good contrast in dark mode
                                    : Colors.black87),
                            icon: Icon(Icons.person_off_outlined,
                                color: themeProvider.isDarkMode
                                    ? Colors.black87
                                    : Colors.black87,
                                size: 20),
                            height: 50,
                          ),
                          const SizedBox(height: 12),
                          CustomButton(
                            text: _isLoading &&
                                    _currentLocalStatus
                                        .contains("Issue Reported")
                                ? 'Updating...'
                                : 'Report Other Issue',
                            onPressed: _isLoading ? null : _reportIssueDialog,
                            color: themeProvider.errorColor.withOpacity(0.85),
                            icon: Icon(Icons.report_problem_outlined,
                                color: themeProvider.infoColorOnDarkBgs ??
                                    Colors.white,
                                size: 20),
                            height: 50,
                            textStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: themeProvider.infoColorOnDarkBgs ??
                                    Colors.white),
                          ),
                        ],
                        // Show a message if no actions are available
                        if (!canMarkPickedUp && !canReportIssueOrNotAvailable)
                          Center(
                              child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text("Status already updated for this stop.",
                                style: GoogleFonts.inter(
                                    color: themeProvider.secondaryText,
                                    fontStyle: FontStyle.italic)),
                          )),
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
}
