// File: lib/screens/admin/admin_customer_list_screen.dart

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
import '../../models/admin/admin_customer_summary_model.dart';
import '../../services/api_service.dart'; // <-- Import real service
import './admin_customer_details_screen.dart';

class AdminCustomerListScreen extends StatefulWidget {
  static const String routeName = '/admin_customer_list';
  const AdminCustomerListScreen({super.key});

  @override
  State<AdminCustomerListScreen> createState() =>
      _AdminCustomerListScreenState();
}

class _AdminCustomerListScreenState extends State<AdminCustomerListScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService(); // <-- Use real ApiService
  bool _isLoading = true;
  List<AdminCustomerSummaryModel> _customers = [];
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isSearchBarVisible = false;

  int _currentPage = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;

  late AnimationController _listAnimationController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fetchCustomers(page: 1);
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
      _fetchCustomers(page: _currentPage + 1, isLoadMore: true);
    }
  }

  /// INTEGRATED: Fetches customers from the backend API.
  Future<void> _fetchCustomers(
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
      final paginatedResponse = await _apiService.adminGetCustomers(
        page: page,
        searchQuery: _searchController.text.trim(),
      );

      if (mounted) {
        final List<AdminCustomerSummaryModel> fetchedCustomers =
            paginatedResponse['customers'];
        setState(() {
          if (isLoadMore) {
            _customers.addAll(fetchedCustomers);
          } else {
            _customers = fetchedCustomers;
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
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchCustomers(page: 1, isRefresh: true);
      }
    });
  }

  void _navigateToCustomerDetails(String customerId) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, AdminCustomerDetailsScreen.routeName,
        arguments: {'customerId': customerId});
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
                hintText: "Search Customers (Name, Email, Phone)...",
                prefixIcon: Icons.search_rounded,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) =>
                    _fetchCustomers(page: 1, isRefresh: true),
              )
            : Text('Customer Management',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 18)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
                _isSearchBarVisible
                    ? Icons.close_rounded
                    : Icons.search_rounded,
                color: adminAccentColor,
                size: 26),
            onPressed: () => setState(() {
              _isSearchBarVisible = !_isSearchBarVisible;
              if (!_isSearchBarVisible && _searchController.text.isNotEmpty) {
                _searchController.clear();
              }
            }),
            tooltip: _isSearchBarVisible ? "Close Search" : "Search Customers",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchCustomers(page: 1, isRefresh: true),
        color: adminAccentColor,
        backgroundColor: themeProvider.cardBackground,
        child: _buildBody(themeProvider),
      ),
    );
  }

  Widget _buildBody(ThemeProvider themeProvider) {
    if (_isLoading && _customers.isEmpty) {
      return _buildLoadingShimmer(themeProvider);
    }
    if (_errorMessage != null) {
      return _buildErrorState(themeProvider);
    }
    if (_customers.isEmpty) {
      return _buildEmptyState(themeProvider,
          isFiltered: _searchController.text.isNotEmpty);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12.0),
      itemCount: _customers.length + (_isFetchingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _customers.length && _isFetchingMore) {
          return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: CircularProgressIndicator()));
        }
        if (index >= _customers.length) return const SizedBox.shrink();

        final customer = _customers[index];
        final itemAnimation =
            Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                .animate(
          CurvedAnimation(
            parent: _listAnimationController,
            curve: Interval((0.05 * index).clamp(0.0, 1.0),
                (0.5 + 0.05 * index).clamp(0.0, 1.0),
                curve: Curves.easeOutCubic),
          ),
        );
        return FadeTransition(
          opacity: _listAnimationController,
          child: SlideTransition(
            position: itemAnimation,
            child: _AdminCustomerListItemWidget(
              customer: customer,
              themeProvider: themeProvider,
              onTap: () => _navigateToCustomerDetails(customer.id),
            ),
          ),
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
                          width: 180, height: 18, themeProvider: themeProvider),
                      const SizedBox(height: 8),
                      _buildSkeletonLine(
                          width: 220, height: 14, themeProvider: themeProvider),
                      const SizedBox(height: 6),
                      _buildSkeletonLine(
                          width: 150, height: 14, themeProvider: themeProvider),
                    ],
                  ))
                ],
              )),
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
            Text('Failed to Load Customers',
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
              onPressed: () => _fetchCustomers(page: 1, isRefresh: true),
              color: themeProvider.gas2doorPrimaryBlue,
              icon: Icon(Icons.refresh_rounded,
                  color: themeProvider.infoColorOnDarkBgs),
            )
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
                    : Icons.people_outline_rounded,
                color: themeProvider.secondaryText.withOpacity(0.6),
                size: 70),
            const SizedBox(height: 24),
            Text(
              isFiltered ? 'No Customers Match Search' : 'No Customers Found',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.primaryText),
            ),
            const SizedBox(height: 12),
            Text(
              isFiltered
                  ? 'Try adjusting your search term.'
                  : 'There are currently no customers registered in the system.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  color: themeProvider.secondaryText,
                  height: 1.5),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 20),
              CustomButton(
                text: 'Clear Search',
                onPressed: () {
                  _searchController.clear();
                },
                color: themeProvider.secondaryText.withOpacity(0.2),
                textStyle: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w500),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class _AdminCustomerListItemWidget extends StatelessWidget {
  final AdminCustomerSummaryModel customer;
  final ThemeProvider themeProvider;
  final VoidCallback onTap;

  const _AdminCustomerListItemWidget({
    required this.customer,
    required this.themeProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
          radius: 22,
          backgroundColor: customer.isActive
              ? themeProvider.gas2doorPurple.withOpacity(0.15)
              : themeProvider.tertiaryText.withOpacity(0.1),
          backgroundImage:
              customer.photoUrl != null && customer.photoUrl!.isNotEmpty
                  ? NetworkImage(customer.photoUrl!)
                  : null,
          child: (customer.photoUrl == null || customer.photoUrl!.isEmpty)
              ? Text(
                  customer.name.isNotEmpty
                      ? customer.name.substring(0, 1).toUpperCase()
                      : 'C',
                  style: GoogleFonts.inter(
                      color: customer.isActive
                          ? themeProvider.gas2doorPurple
                          : themeProvider.tertiaryText,
                      fontWeight: FontWeight.w600))
              : null,
        ),
        title: Text(customer.name,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: themeProvider.primaryText)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(customer.email,
                style: GoogleFonts.inter(
                    fontSize: 13, color: themeProvider.secondaryText)),
            Text(customer.phone,
                style: GoogleFonts.inter(
                    fontSize: 13, color: themeProvider.secondaryText)),
            const SizedBox(height: 3),
            Row(
              children: [
                Text('Joined: ${customer.formattedRegistrationDate}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: themeProvider.tertiaryText)),
                const Spacer(),
                Text('Orders: ${customer.totalOrders}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: themeProvider.tertiaryText,
                        fontWeight: FontWeight.w500)),
              ],
            ),
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
