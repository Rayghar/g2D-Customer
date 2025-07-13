// File: lib/screens/admin/admin_driver_list_screen.dart

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
// Import the defined model
import '../../services/api_service.dart'; // Use real ApiService
import '../../models/admin/admin_driver_summary_model.dart';
import './admin_driver_details_screen.dart';
import './admin_add_edit_user_screen.dart';

class AdminDriverListScreen extends StatefulWidget {
  static const String routeName = '/admin_driver_list';
  const AdminDriverListScreen({super.key});

  @override
  State<AdminDriverListScreen> createState() => _AdminDriverListScreenState();
}

class _AdminDriverListScreenState extends State<AdminDriverListScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService(); // Use real ApiService

  // State variables for filters
  String? _selectedAccountStatusFilter;
  bool? _selectedOnlineStatusFilter;

  // All other state variables and controllers remain the same
  bool _isLoading = true;
  List<AdminDriverSummaryModel> _drivers = [];
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isSearchBarVisible = false;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;
  late AnimationController _listAnimationController;
  final ScrollController _scrollController = ScrollController();

  final List<String> _availableAccountStatuses = [
    "All",
    "Active",
    "Pending Approval",
    "Suspended"
  ];
  final Map<String, bool?> _availableOnlineStatusesMap = {
    "All": null,
    "Online": true,
    "Offline": false
  };

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fetchDrivers();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMore &&
        _currentPage < _totalPages) {
      _fetchDrivers(page: _currentPage + 1, isLoadMore: true);
    }
  }

  /// INTEGRATED: Fetches drivers from the backend with current filters.
  Future<void> _fetchDrivers(
      {int page = 1, bool isRefresh = false, bool isLoadMore = false}) async {
    if (!mounted || (isLoadMore && _isFetchingMore)) return;

    setState(() {
      if (isLoadMore)
        _isFetchingMore = true;
      else
        _isLoading = true;
      if (isRefresh) _errorMessage = null;
    });

    try {
      final paginatedResponse = await _apiService.adminGetDrivers(
        page: page,
        searchQuery: _searchController.text.trim(),
        accountStatus: _selectedAccountStatusFilter,
        isAvailableOnline: _selectedOnlineStatusFilter,
      );

      if (mounted) {
        final List<AdminDriverSummaryModel> fetchedDrivers =
            paginatedResponse['drivers'];
        setState(() {
          if (isLoadMore) {
            _drivers.addAll(fetchedDrivers);
          } else {
            _drivers = fetchedDrivers;
          }
          _currentPage = paginatedResponse['currentPage'];
          _totalPages = paginatedResponse['totalPages'];
          if (!isLoadMore) _listAnimationController.forward(from: 0.0);
        });
      }
    } catch (e) {
      if (mounted) _errorMessage = e.toString().replaceFirst("Exception: ", "");
    } finally {
      if (mounted)
        setState(() => {_isLoading = false, _isFetchingMore = false});
    }
  }

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _fetchDrivers(page: 1, isRefresh: true);
    });
  }

  void _navigateToDriverDetails(String driverId) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, AdminDriverDetailsScreen.routeName,
        arguments: {'driverId': driverId});
  }

  void _navigateToAddDriver() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, AdminAddEditUserScreen.routeName,
        arguments: {'initialRole': 'Driver'}).then((result) {
      if (result == true && mounted) {
        _fetchDrivers(page: 1, isRefresh: true);
      }
    });
  }

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    // CORRECTED: Added SnackBar widget as argument
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

  void _showFilterBottomSheet(ThemeProvider themeProvider) {
    HapticFeedback.mediumImpact();
    String? tempAccountStatus = _selectedAccountStatusFilter;
    bool? tempOnlineStatus = _selectedOnlineStatusFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext bc) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Filter Drivers',
                              style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.primaryText)),
                          IconButton(
                              icon: Icon(Icons.close_rounded,
                                  color: themeProvider.secondaryText),
                              onPressed: () => Navigator.pop(context),
                              splashRadius: 20)
                        ]),
                    const SizedBox(height: 16),
                    Text('By Account Status:',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.secondaryText)),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _availableAccountStatuses.map((status) {
                          bool isSelected = tempAccountStatus == status ||
                              (tempAccountStatus == null && status == "All");
                          return ChoiceChip(
                            label: Text(status,
                                style: GoogleFonts.inter(
                                    color: isSelected
                                        ? themeProvider.infoColorOnDarkBgs
                                        : themeProvider.primaryText,
                                    fontSize: 13)),
                            selected: isSelected,
                            onSelected: (bool selected) => setModalState(() =>
                                tempAccountStatus = selected
                                    ? (status == "All" ? null : status)
                                    : null),
                            selectedColor: themeProvider.gas2doorPurple,
                            backgroundColor:
                                themeProvider.appSecondaryBackground,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                    color: isSelected
                                        ? themeProvider.gas2doorPurple
                                        : themeProvider.tertiaryText
                                            .withOpacity(0.5))),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          );
                        }).toList()),
                    const SizedBox(height: 20),
                    Text('By Online Status:',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.secondaryText)),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children:
                            _availableOnlineStatusesMap.entries.map((entry) {
                          bool isSelected = tempOnlineStatus == entry.value;
                          return ChoiceChip(
                            label: Text(entry.key,
                                style: GoogleFonts.inter(
                                    color: isSelected
                                        ? themeProvider.infoColorOnDarkBgs
                                        : themeProvider.primaryText,
                                    fontSize: 13)),
                            selected: isSelected,
                            onSelected: (bool selected) => setModalState(() =>
                                tempOnlineStatus =
                                    selected ? entry.value : null),
                            selectedColor: themeProvider.gas2doorTeal,
                            backgroundColor:
                                themeProvider.appSecondaryBackground,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                    color: isSelected
                                        ? themeProvider.gas2doorTeal
                                        : themeProvider.tertiaryText
                                            .withOpacity(0.5))),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          );
                        }).toList()),
                    const SizedBox(height: 28),
                    Row(children: [
                      Expanded(
                          child: CustomButton(
                              text: 'Reset Filters',
                              onPressed: () => setModalState(() {
                                    tempAccountStatus = null;
                                    tempOnlineStatus = null;
                                  }),
                              color:
                                  themeProvider.tertiaryText.withOpacity(0.15),
                              textStyle: GoogleFonts.inter(
                                  color: themeProvider.secondaryText,
                                  fontWeight: FontWeight.w500),
                              height: 50,
                              elevation: 0)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: CustomButton(
                              text: 'Apply Filters',
                              onPressed: () {
                                setState(() {
                                  _selectedAccountStatusFilter =
                                      tempAccountStatus;
                                  _selectedOnlineStatusFilter =
                                      tempOnlineStatus;
                                });
                                _fetchDrivers(page: 1, isRefresh: true);
                                Navigator.pop(context);
                              },
                              color: themeProvider.gas2doorPrimaryBlue,
                              textStyle: GoogleFonts.inter(
                                  color: themeProvider.infoColorOnDarkBgs,
                                  fontWeight: FontWeight.w600),
                              height: 50)),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
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
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: _isSearchBarVisible
            ? CustomInput(
                controller: _searchController,
                hintText: "Search Drivers (Name, Email, Phone)...",
                // autofocus: true, // REMOVED: autofocus not defined in CustomInput
                prefixIcon: Icons.search_rounded,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) =>
                    _fetchDrivers(page: 1, isRefresh: true))
            : Text('Driver Management',
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
            icon: Icon(
                _isSearchBarVisible
                    ? Icons.close_rounded
                    : Icons.search_rounded,
                color: adminAccentColor,
                size: 26), // Using adminAccentColor for search/filter icons
            onPressed: () => setState(() {
              _isSearchBarVisible = !_isSearchBarVisible;
              if (!_isSearchBarVisible && _searchController.text.isNotEmpty)
                _searchController.clear();
            }),
            tooltip: _isSearchBarVisible ? "Close Search" : "Search Drivers",
          ),
          IconButton(
            icon: Icon(Icons.filter_list_alt,
                color: adminAccentColor, size: 26), // CORRECTED Icon
            onPressed: () => _showFilterBottomSheet(themeProvider),
            tooltip: "Filter Drivers",
          ),
          IconButton(
            icon: Icon(Icons.person_add_alt_1_outlined,
                color: adminAccentColor, size: 26),
            onPressed: _navigateToAddDriver,
            tooltip: "Add New Driver",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchDrivers(page: 1, isRefresh: true),
        color: adminAccentColor,
        backgroundColor: themeProvider.cardBackground,
        child: _buildBody(themeProvider),
      ),
    );
  }

  Widget _buildBody(ThemeProvider themeProvider) {
    if (_isLoading && _drivers.isEmpty)
      return _buildLoadingShimmer(themeProvider);
    if (_errorMessage != null) return _buildErrorState(themeProvider);
    if (_drivers.isEmpty) {
      bool hasFiltersApplied = _selectedAccountStatusFilter != null ||
          _selectedOnlineStatusFilter != null ||
          _searchController.text.isNotEmpty;
      return _buildEmptyState(themeProvider, isFiltered: hasFiltersApplied);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12.0),
      itemCount: _drivers.length + (_isFetchingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _drivers.length && _isFetchingMore)
          return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: CircularProgressIndicator()));
        if (index >= _drivers.length) return const SizedBox.shrink();
        final driver = _drivers[index];
        final itemAnimation =
            Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                .animate(
          CurvedAnimation(
              parent: _listAnimationController,
              curve: Interval((0.05 * index).clamp(0.0, 1.0),
                  (0.5 + 0.05 * index).clamp(0.0, 1.0),
                  curve: Curves.easeOutCubic)),
        );
        return FadeTransition(
          opacity: _listAnimationController,
          child: SlideTransition(
              position: itemAnimation,
              child: _AdminDriverListItemWidget(
                  driver: driver,
                  themeProvider: themeProvider,
                  onTap: () => _navigateToDriverDetails(driver.id))),
        );
      },
    );
  }

  Widget _buildLoadingShimmer(ThemeProvider themeProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: 7,
      itemBuilder: (context, index) {
        return CustomCard(
          margin: const EdgeInsets.only(bottom: 12.0),
          color: themeProvider.cardBackground,
          borderRadius: themeProvider.cardBorderRadiusValue,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildSkeletonLine(
                    width: 44,
                    height: 44,
                    themeProvider: themeProvider,
                    borderRadius: 22),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSkeletonLine(
                        width: 150, height: 16, themeProvider: themeProvider),
                    const SizedBox(height: 6),
                    _buildSkeletonLine(
                        width: 120, height: 12, themeProvider: themeProvider),
                    const SizedBox(height: 4),
                    _buildSkeletonLine(
                        width: 100, height: 12, themeProvider: themeProvider),
                  ],
                )),
                _buildSkeletonLine(
                    width: 70,
                    height: 20,
                    themeProvider: themeProvider,
                    borderRadius: 10),
              ],
            ),
          ),
        );
      },
    );
  }

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

  Widget _buildErrorState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_outlined,
                color: themeProvider.secondaryText.withOpacity(0.7), size: 60),
            const SizedBox(height: 20),
            Text('Failed to Load Drivers',
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
                onPressed: () => _fetchDrivers(page: 1, isRefresh: true),
                color: themeProvider.gas2doorPrimaryBlue,
                icon: Icon(Icons.refresh_rounded,
                    color: themeProvider.infoColorOnDarkBgs)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider,
      {bool isFiltered = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                isFiltered
                    ? Icons.person_search_outlined
                    : Icons.directions_car_filled_outlined,
                color: themeProvider.secondaryText.withOpacity(0.6),
                size: 70),
            const SizedBox(height: 24),
            Text(isFiltered ? 'No Drivers Match Filters' : 'No Drivers Found',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            Text(
                isFiltered
                    ? 'Try adjusting your filter or search criteria.'
                    : 'There are currently no drivers registered. You can add a new driver.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    color: themeProvider.secondaryText,
                    height: 1.5)),
            const SizedBox(height: 20),
            if (isFiltered)
              CustomButton(
                  text: 'Clear Filters & Search',
                  onPressed: () {
                    setState(() {
                      _selectedAccountStatusFilter = null;
                      _selectedOnlineStatusFilter = null;
                      _searchController.clear();
                    });
                    _fetchDrivers(page: 1, isRefresh: true);
                  },
                  color: themeProvider.secondaryText.withOpacity(0.2),
                  textStyle: GoogleFonts.inter(
                      color: themeProvider.primaryText,
                      fontWeight: FontWeight.w500))
            else
              CustomButton(
                  text: 'Add New Driver',
                  onPressed: _navigateToAddDriver,
                  color: themeProvider.gas2doorTeal,
                  icon: Icon(Icons.person_add_alt_1_rounded,
                      color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _AdminDriverListItemWidget extends StatelessWidget {
  final AdminDriverSummaryModel driver;
  final ThemeProvider themeProvider;
  final VoidCallback onTap;

  const _AdminDriverListItemWidget({
    required this.driver,
    required this.themeProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String displayStatusText = driver.accountStatus;

    if (driver.accountStatus.toLowerCase() == 'active') {
      statusColor = driver.isAvailableOnline
          ? themeProvider.successColor
          : themeProvider.secondaryText;
      displayStatusText = driver.isAvailableOnline ? "Online" : "Offline";
    } else if (driver.accountStatus.toLowerCase() == 'pending approval') {
      statusColor = themeProvider.warningColor;
    } else {
      statusColor = themeProvider.errorColor;
    }

    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 1.5,
      shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: themeProvider.gas2doorTeal.withOpacity(0.15),
          backgroundImage:
              driver.photoUrl != null && driver.photoUrl!.isNotEmpty
                  ? NetworkImage(driver.photoUrl!)
                  : null,
          child: (driver.photoUrl == null || driver.photoUrl!.isEmpty)
              ? Text(driver.initials,
                  style: GoogleFonts.inter(
                      color: themeProvider.gas2doorTeal,
                      fontWeight: FontWeight.w600,
                      fontSize: 18))
              : null,
        ),
        title: Text(driver.name,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: themeProvider.primaryText)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(driver.email,
                style: GoogleFonts.inter(
                    fontSize: 13, color: themeProvider.secondaryText)),
            Text(driver.phone,
                style: GoogleFonts.inter(
                    fontSize: 13, color: themeProvider.secondaryText)),
            if (driver.vehicleDetails != null &&
                driver.vehicleDetails!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text("Vehicle: ${driver.vehicleDetails}",
                    style: GoogleFonts.inter(
                        fontSize: 12, color: themeProvider.tertiaryText)),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(15)),
                  child: Text(displayStatusText,
                      style: GoogleFonts.inter(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 11)),
                ),
                const SizedBox(width: 6),
                Icon(Icons.star_rounded,
                    color: themeProvider.warningColor.withOpacity(0.8),
                    size: 14),
                Text(' ${driver.averageRating.toStringAsFixed(1)}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: themeProvider.tertiaryText,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('Deliveries: ${driver.totalDeliveriesCompleted}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: themeProvider.tertiaryText)),
              ],
            )
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: themeProvider.tertiaryText),
        onTap: onTap,
        isThreeLine: true,
      ),
    );
  }
}
