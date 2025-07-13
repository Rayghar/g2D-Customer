// File: lib/screens/driver/driver_dashboard_screen.dart (Shell)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For HapticFeedback

import '../../providers/theme_provider.dart';
// Import the screen files for the tabs
import './driver_dashboard_home_screen.dart';
import './driver_stats_screen.dart';
import './driver_messages_list_screen.dart';
import './driver_profile_screen.dart';

// --- Simplified DriverProfile Model (only what the shell needs) ---
class DriverProfileBasic {
  final String id;
  final String name;
  bool isAvailable;

  DriverProfileBasic({
    required this.id,
    required this.name,
    this.isAvailable = true,
  });

  DriverProfileBasic copyWith({
    String? name,
    bool? isAvailable,
  }) {
    return DriverProfileBasic(
      id: id,
      name: name ?? this.name,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
// --- End Simplified Model ---

class DriverDashboardScreen extends StatefulWidget {
  static const String routeName = '/driver_dashboard';
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;

  bool _isLoadingProfile = true;
  DriverProfileBasic? _driverProfile;
  bool _isUpdatingAvailability = false;

  String? _errorMessage; // Kept for potential future use

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(), // Key for Dashboard Home tab
    GlobalKey<NavigatorState>(), // Key for Stats tab
    GlobalKey<NavigatorState>(), // Key for Messages tab
    GlobalKey<NavigatorState>(), // Key for Profile tab
  ];

  late final List<Widget> _screenOptions;

  // TODO: Replace with actual driver ID from authentication service
  final String _mockDriverId = "driver123";

  @override
  void initState() {
    super.initState();
    _fetchDriverProfile();

    _screenOptions = <Widget>[
      DriverDashboardHomeScreen(
          driverId: _mockDriverId, navigatorKey: _navigatorKeys[0]),
      DriverStatsScreen(
          driverId: _mockDriverId), // Pass driverId if stats are specific
      DriverMessagesListScreen(currentUserId: _mockDriverId),
      DriverProfileScreen(driverId: _mockDriverId),
    ];
  }

  Future<void> _fetchDriverProfile({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (!isRefresh) _isLoadingProfile = true;
      _errorMessage = null;
    });

    // TODO: Replace with actual API call to fetch driver's basic profile
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _driverProfile = DriverProfileBasic(
          id: _mockDriverId,
          name: "Tunde Adebayo", // Mock name, fetch real name
          isAvailable: true, // Default or fetched availability
        );
        _isLoadingProfile = false;
      });
    }
    // Example error handling:
    // catch (e) {
    //   if (mounted) {
    //     setState(() {
    //       _isLoadingProfile = false;
    //       _errorMessage = "Failed to load profile.";
    //     });
    //   }
    // }
  }

  Future<void> _toggleAvailability(bool value) async {
    HapticFeedback.lightImpact();
    if (!mounted || _driverProfile == null) return;

    final originalAvailability = _driverProfile!.isAvailable;
    setState(() {
      _isUpdatingAvailability = true;
      _driverProfile = _driverProfile!.copyWith(isAvailable: value);
    });

    // TODO: Replace with actual API call to update driver availability
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate API
    bool success = true; // Simulate success

    if (mounted) {
      if (success) {
        _showFeedbackSnackbar(
            "Availability updated to ${value ? 'Online' : 'Offline'}.",
            context);
      } else {
        _showFeedbackSnackbar("Failed to update availability.", context,
            isError: true);
        // Revert state on failure
        _driverProfile =
            _driverProfile!.copyWith(isAvailable: originalAvailability);
      }
      setState(() => _isUpdatingAvailability = false);
    }
  }

  void _showFeedbackSnackbar(String message, BuildContext ctx,
      {ThemeProvider? themeProvider, bool isError = false}) {
    final tp = themeProvider ?? Provider.of<ThemeProvider>(ctx, listen: false);
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor:
            isError ? tp.errorColor : tp.successColor.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 6,
      ),
    );
  }

  void _onItemTapped(int index) {
    HapticFeedback.lightImpact();
    if (_selectedIndex == index) {
      if (_navigatorKeys[index].currentState != null &&
          _navigatorKeys[index].currentState!.canPop()) {
        _navigatorKeys[index].currentState!.popUntil((route) => route.isFirst);
      }
    }
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color driverAccentColor =
        themeProvider.gas2doorTeal; // Driver specific accent

    final List<String> appBarTitles = <String>[
      _isLoadingProfile
          ? 'Driver Dashboard'
          : 'Hi, ${_driverProfile?.name.split(" ").first ?? "Driver"}!',
      'Your Stats',
      'Messages',
      'My Profile',
    ];

    return Scaffold(
      backgroundColor:
          themeProvider.appSecondaryBackground, // Polished background
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground, // Consistent with admin
        elevation: 1.0, // Subtle elevation
        shadowColor: themeProvider.cardShadowColorGlobal
            .withOpacity(0.3), // Consistent shadow
        automaticallyImplyLeading: false,
        title: Text(
          appBarTitles[_selectedIndex],
          style: GoogleFonts.inter(
              // Consistent Typography
              color: themeProvider.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: 18),
        ),
        actions: [
          if (_selectedIndex == 0 &&
              !_isLoadingProfile &&
              _driverProfile != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                children: [
                  Text(
                    _driverProfile!.isAvailable ? 'Online' : 'Offline',
                    style: GoogleFonts.inter(
                      // Consistent Typography
                      color: _driverProfile!.isAvailable
                          ? themeProvider.successColor
                          : themeProvider.secondaryText.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  _isUpdatingAvailability
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14.0), // Centered padding for loader
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                color: driverAccentColor, // Themed loader
                              )))
                      : Switch.adaptive(
                          value: _driverProfile!.isAvailable,
                          onChanged: _isUpdatingAvailability
                              ? null
                              : _toggleAvailability,
                          activeColor: driverAccentColor, // Driver accent
                          inactiveThumbColor:
                              themeProvider.secondaryText.withOpacity(0.6),
                          activeTrackColor: driverAccentColor.withOpacity(0.5),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                ],
              ),
            ),
          ],
          // Example of a global action (e.g., notifications)
          // IconButton(
          //   icon: Icon(Icons.notifications_none_outlined, color: themeProvider.secondaryText),
          //   onPressed: () { /* Navigate to driver notifications */ },
          // ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screenOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart_rounded),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: driverAccentColor, // Driver accent for selected item
        unselectedItemColor:
            themeProvider.secondaryText.withOpacity(0.7), // Polished unselected
        selectedLabelStyle: GoogleFonts.inter(
            // Consistent Typography
            fontWeight: FontWeight.w600,
            fontSize: 12.0), // Balanced font size
        unselectedLabelStyle:
            GoogleFonts.inter(fontSize: 11.5), // Consistent Typography
        showUnselectedLabels: true,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: themeProvider.cardBackground, // Consistent with AppBar
        elevation: 8.0, // Standard elevation
      ),
    );
  }
}
