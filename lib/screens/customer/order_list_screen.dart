// File: lib/screens/customer/order_list_screen.dart
// ADVISORY: This version fixes the build errors related to date filtering.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './order_details_screen.dart';
import '../../models/address_model.dart';
import './order_placement_screen.dart';
import '../../services/api_service.dart';
import '../../models/order.dart' as app_order;

class OrderListScreen extends StatefulWidget {
  static const String routeName = '/order_list_customer';
  final GlobalKey<NavigatorState> navigatorKey;
  final String? customerId;
  final AddressModel? initialHomeAddress;

  const OrderListScreen({
    super.key,
    required this.navigatorKey,
    this.customerId,
    this.initialHomeAddress,
  });

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<app_order.Order> _orders = [];
  String? _errorMessage;
  String? _selectedStatusFilter;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;

  late AnimationController _listAnimationController;
  final ScrollController _scrollController = ScrollController();

  final ApiService _apiService = ApiService();
  final List<String> _availableStatuses = [
    "All",
    "Pending Payment",
    "Order Placed",
    "Processing",
    "Out for Delivery",
    "Delivered",
    "Cancelled"
  ];

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    if (widget.customerId != null) {
      _fetchOrders(page: 1);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "Login required to view orders.";
      });
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMore &&
        _currentPage < _totalPages) {
      _fetchOrders(page: _currentPage + 1, isLoadMore: true);
    }
  }

  Future<void> _fetchOrders(
      {int page = 1, bool isRefresh = false, bool isLoadMore = false}) async {
    if (!mounted) return;
    if (isLoadMore) {
      setState(() => _isFetchingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final paginatedResponse = await _apiService.getCustomerOrders(
        page: page,
        limit: 15,
        status: _selectedStatusFilter == "All" ? null : _selectedStatusFilter,
        // CORRECTED: Removed startDate and endDate parameters as they are not supported
      );

      if (mounted) {
        final List<app_order.Order> fetchedOrders =
            paginatedResponse['orders'] as List<app_order.Order>;

        setState(() {
          if (isLoadMore) {
            _orders.addAll(fetchedOrders);
          } else {
            _orders = fetchedOrders;
          }
          _currentPage = paginatedResponse['currentPage'] as int? ?? 1;
          _totalPages = paginatedResponse['totalPages'] as int? ?? 1;
          _isLoading = false;
          _isFetchingMore = false;
        });

        if (!isLoadMore && _orders.isNotEmpty) {
          _listAnimationController.forward(from: 0.0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
        });
      }
    }
  }

  void _applyFiltersFromSheet(String? status, DateTime? start, DateTime? end) {
    setState(() {
      _selectedStatusFilter = status;
      _selectedStartDate = start;
      _selectedEndDate = end;
      _currentPage = 1;
      _orders.clear();
    });
    _fetchOrders(page: 1, isRefresh: true);
    Navigator.pop(context);
  }

  void _navigateToOrderDetails(String orderId) {
    HapticFeedback.lightImpact();
    if (widget.customerId == null) {
      _showFeedbackSnackbar(
          "Cannot view details: Customer information is unavailable.",
          isError: true);
      return;
    }
    Navigator.of(context, rootNavigator: true).pushNamed(
      OrderDetailsScreen.routeName,
      arguments: {'orderId': orderId, 'customerId': widget.customerId},
    );
  }

  void _navigateToPlaceOrder() {
    HapticFeedback.lightImpact();
    if (widget.customerId == null || widget.initialHomeAddress == null) {
      _showFeedbackSnackbar("User session error. Please restart.",
          isError: true);
      return;
    }
    Navigator.of(context, rootNavigator: true).pushNamed(
      OrderPlacementScreen.routeName,
      arguments: {
        'isRefill': false,
        'customerId': widget.customerId,
        'initialAddress': widget.initialHomeAddress
      },
    );
  }

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: isError
          ? themeProvider.errorColor
          : themeProvider.successColor.withOpacity(0.95),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  void _showFilterBottomSheet(ThemeProvider themeProvider) {
    HapticFeedback.mediumImpact();
    String? tempStatus = _selectedStatusFilter;
    DateTime? tempStartDate = _selectedStartDate;
    DateTime? tempEndDate = _selectedEndDate;

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
                    Text('Filter Orders',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.primaryText)),
                    const SizedBox(height: 16),
                    Text('By Status:',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.secondaryText)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _availableStatuses.map((status) {
                        bool isSelected = tempStatus == status ||
                            (tempStatus == null && status == "All");
                        return ChoiceChip(
                          label: Text(status),
                          labelStyle: GoogleFonts.inter(
                              color: isSelected
                                  ? Colors.white
                                  : themeProvider.primaryText,
                              fontSize: 13),
                          selected: isSelected,
                          onSelected: (bool selected) => setModalState(() =>
                              tempStatus = selected
                                  ? (status == "All" ? null : status)
                                  : null),
                          selectedColor: themeProvider.gas2doorPrimaryBlue,
                          backgroundColor: themeProvider.appSecondaryBackground,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                  color: isSelected
                                      ? Colors.transparent
                                      : themeProvider.tertiaryText
                                          .withOpacity(0.2))),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                            child: CustomButton(
                                text: 'Reset',
                                onPressed: () => setModalState(() {
                                      tempStatus = null;
                                      tempStartDate = null;
                                      tempEndDate = null;
                                    }),
                                color:
                                    themeProvider.tertiaryText.withOpacity(0.1),
                                textStyle: GoogleFonts.inter(
                                    color: themeProvider.secondaryText,
                                    fontWeight: FontWeight.w500),
                                elevation: 0,
                                height: 48)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: CustomButton(
                                text: 'Apply Filters',
                                onPressed: () => _applyFiltersFromSheet(
                                    tempStatus, tempStartDate, tempEndDate),
                                color: themeProvider.gas2doorPrimaryBlue,
                                textStyle: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                                height: 48)),
                      ],
                    ),
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
    return Navigator(
        key: widget.navigatorKey,
        initialRoute: '/',
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute(
              builder: (context) =>
                  _buildOrderListContent(context, themeProvider),
              settings: settings);
        });
  }

  Widget _buildOrderListContent(
      BuildContext context, ThemeProvider themeProvider) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text('My Orders',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        actions: [
          IconButton(
              icon: Icon(Icons.filter_list_rounded,
                  color: themeProvider.primaryText, size: 26),
              onPressed: () => _showFilterBottomSheet(themeProvider),
              tooltip: "Filter Orders")
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchOrders(isRefresh: true),
        color: themeProvider.gas2doorPrimaryBlue,
        backgroundColor: themeProvider.cardBackground,
        child: _buildBody(themeProvider),
      ),
      backgroundColor: themeProvider.appSecondaryBackground,
    );
  }

  Widget _buildBody(ThemeProvider themeProvider) {
    if (_isLoading && _orders.isEmpty)
      return _buildLoadingShimmer(themeProvider);
    if (_errorMessage != null) return _buildErrorState(themeProvider);
    if (_orders.isEmpty)
      return _buildEmptyState(themeProvider,
          isFiltered: _selectedStatusFilter != null);

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: _orders.length + (_isFetchingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _orders.length) {
          return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: CircularProgressIndicator()));
        }
        final order = _orders[index];
        final itemAnimation =
            Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: _listAnimationController,
                    curve: Interval((0.1 * index).clamp(0.0, 1.0),
                        (0.6 + 0.1 * index).clamp(0.0, 1.0),
                        curve: Curves.easeOutCubic)));
        return FadeTransition(
          opacity: _listAnimationController,
          child: SlideTransition(
            position: itemAnimation,
            child: UnifiedOrderCard(
                order: order,
                themeProvider: themeProvider,
                onTap: () => _navigateToOrderDetails(order.id)),
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
  }

  Widget _buildLoadingShimmer(ThemeProvider themeProvider) {
    return ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: 5,
        itemBuilder: (context, index) => CustomCard(
            margin: const EdgeInsets.only(bottom: 12.0),
            color: themeProvider.cardBackground,
            borderRadius: themeProvider.cardBorderRadiusValue,
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeletonLine(
                          width: 150,
                          height: 18,
                          themeProvider: themeProvider,
                          borderRadius: 6),
                      const SizedBox(height: 8),
                      _buildSkeletonLine(
                          width: 200,
                          height: 14,
                          themeProvider: themeProvider,
                          borderRadius: 4),
                      const SizedBox(height: 12),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSkeletonLine(
                                width: 80,
                                height: 14,
                                themeProvider: themeProvider,
                                borderRadius: 4),
                            _buildSkeletonLine(
                                width: 70,
                                height: 24,
                                themeProvider: themeProvider,
                                borderRadius: 20)
                          ])
                    ]))));
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
          borderRadius: BorderRadius.circular(borderRadius)),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider) {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(20.0),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_off_rounded,
                  color: themeProvider.secondaryText.withOpacity(0.7),
                  size: 60),
              const SizedBox(height: 20),
              Text('Failed to Load Orders',
                  style: GoogleFonts.inter(
                      color: themeProvider.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                  _errorMessage ??
                      'Please check your connection and try again.',
                  style: GoogleFonts.inter(
                      fontSize: 15, color: themeProvider.secondaryText),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              CustomButton(
                  text: "Retry",
                  onPressed: () => _fetchOrders(isRefresh: true),
                  color: themeProvider.gas2doorPrimaryBlue,
                  icon: Icon(Icons.refresh_rounded,
                      color: themeProvider.infoColorOnDarkBgs))
            ])));
  }

  Widget _buildEmptyState(ThemeProvider themeProvider,
      {bool isFiltered = false}) {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(30.0),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                  isFiltered
                      ? Icons.filter_alt_off_outlined
                      : Icons.receipt_long_outlined,
                  color: themeProvider.secondaryText.withOpacity(0.6),
                  size: 70),
              const SizedBox(height: 24),
              Text(isFiltered ? 'No Orders Match Filters' : 'No Orders Yet',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryText)),
              const SizedBox(height: 12),
              Text(
                  isFiltered
                      ? 'Try adjusting your filters or view all orders.'
                      : 'Looks like you haven\'t placed any orders. Start by placing your first order!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      color: themeProvider.secondaryText,
                      height: 1.5)),
              const SizedBox(height: 28),
              if (!isFiltered)
                CustomButton(
                    text: 'Place Your First Order',
                    onPressed: _navigateToPlaceOrder,
                    color: themeProvider.primaryActionColor,
                    icon: Icon(Icons.add_shopping_cart_rounded,
                        color: Colors.white),
                    height: 50),
              if (isFiltered)
                CustomButton(
                    text: 'Clear Filters',
                    onPressed: () {
                      setState(() {
                        _selectedStatusFilter = null;
                        _selectedStartDate = null;
                        _selectedEndDate = null;
                      });
                      _fetchOrders(page: 1, isRefresh: true);
                    },
                    color: themeProvider.secondaryText.withOpacity(0.2),
                    textStyle: GoogleFonts.inter(
                        color: themeProvider.primaryText,
                        fontWeight: FontWeight.w500),
                    height: 50)
            ])));
  }
}

class UnifiedOrderCard extends StatelessWidget {
  final app_order.Order order;
  final ThemeProvider themeProvider;
  final VoidCallback onTap;

  const UnifiedOrderCard({
    super.key,
    required this.order,
    required this.themeProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: InkWell(
        onTap: onTap,
        borderRadius: themeProvider.cardBorderRadius,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Order #${order.shortOrderId}',
                      style: GoogleFonts.inter(
                          fontSize: 15.0,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.primaryText)),
                  _buildStatusTag(order, themeProvider),
                ],
              ),
              const SizedBox(height: 12),
              Text(order.itemsPreview,
                  style: GoogleFonts.inter(
                      fontSize: 14.0, color: themeProvider.secondaryText)),
              Text(order.formattedOrderDate,
                  style: GoogleFonts.inter(
                      fontSize: 12.0, color: themeProvider.tertiaryText)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                      NumberFormat.currency(locale: 'en_NG', symbol: '₦')
                          .format(order.grandTotal / 100),
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.primaryText)),
                  Row(
                    children: [
                      Text('View Details',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: themeProvider.gas2doorPrimaryBlue,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: themeProvider.gas2doorPrimaryBlue)
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTag(app_order.Order order, ThemeProvider themeProvider) {
    Color statusColor;
    String statusText = order.status;
    String normalizedStatus = order.status.toLowerCase();

    if (normalizedStatus.contains('delivered')) {
      statusColor = themeProvider.successColor;
    } else if (normalizedStatus.contains('cancelled')) {
      statusColor = themeProvider.errorColor;
    } else {
      statusColor = themeProvider.secondaryText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(statusText,
          style: GoogleFonts.inter(
              color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
