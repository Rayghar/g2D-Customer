// File: lib/screens/admin/admin_order_list_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // FIX: Added missing import for HapticFeedback

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/input.dart';
import '../../models/admin/admin_order_summary_model.dart';
import '../../services/api_service.dart';
import './admin_order_details_screen.dart';

class AdminOrderListScreen extends StatefulWidget {
  static const String routeName = '/admin_order_list';
  const AdminOrderListScreen({super.key});

  @override
  State<AdminOrderListScreen> createState() => _AdminOrderListScreenState();
}

class _AdminOrderListScreenState extends State<AdminOrderListScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<AdminOrderSummaryModel> _orders = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = true;
  bool _isFetchingMore = false;
  String? _errorMessage;

  String? _selectedStatusFilter;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isSearchBarVisible = false;

  final List<String> _availableStatuses = [
    "All",
    "Order Placed",
    "Order Confirmed",
    "Processing",
    "Driver Assigned",
    "Out for Delivery",
    "Delivered",
    "Cancelled"
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrders(page: 1);
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
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

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _fetchOrders(page: 1, isRefresh: true);
    });
  }

  Future<void> _fetchOrders(
      {int page = 1, bool isRefresh = false, bool isLoadMore = false}) async {
    if (_isFetchingMore) return;
    setState(() {
      if (isLoadMore)
        _isFetchingMore = true;
      else
        _isLoading = true;
      if (isRefresh) {
        _orders = [];
        _errorMessage = null;
      }
    });

    try {
      final response = await _apiService.adminGetOrders(
        page: page,
        status: _selectedStatusFilter,
        searchQuery: _searchController.text.trim(),
        startDate: _selectedStartDate,
        endDate: _selectedEndDate,
      );
      if (mounted) {
        setState(() {
          final fetchedOrders =
              response['orders'] as List<AdminOrderSummaryModel>;
          if (isLoadMore) {
            _orders.addAll(fetchedOrders);
          } else {
            _orders = fetchedOrders;
          }
          _currentPage = response['currentPage'];
          _totalPages = response['totalPages'];
        });
      }
    } catch (e) {
      if (mounted) _errorMessage = e.toString().replaceFirst("Exception: ", "");
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
    }
  }

  void _navigateToOrderDetails(String orderId) {
    Navigator.pushNamed(context, AdminOrderDetailsScreen.routeName,
        arguments: {'orderId': orderId}).then((value) {
      if (value == true) _fetchOrders(page: 1, isRefresh: true);
    });
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
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Filter Orders',
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
                    Text('By Status:',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.secondaryText)),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _availableStatuses.map((status) {
                          bool isSelected = tempStatus == status ||
                              (tempStatus == null && status == "All");
                          return ChoiceChip(
                            label: Text(status,
                                style: GoogleFonts.inter(
                                    color: isSelected
                                        ? themeProvider.infoColorOnDarkBgs
                                        : themeProvider.primaryText,
                                    fontSize: 13)),
                            selected: isSelected,
                            onSelected: (bool selected) => setModalState(() =>
                                tempStatus = selected
                                    ? (status == "All" ? null : status)
                                    : null),
                            selectedColor: themeProvider.gas2doorPrimaryBlue,
                            backgroundColor:
                                themeProvider.appSecondaryBackground,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                    color: isSelected
                                        ? themeProvider.gas2doorPrimaryBlue
                                        : themeProvider.tertiaryText
                                            .withOpacity(0.5))),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          );
                        }).toList()),
                    const SizedBox(height: 20),
                    Text('By Date Range:',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.secondaryText)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: CustomButton(
                              text: tempStartDate == null
                                  ? 'Start Date'
                                  : DateFormat('dd MMM, yy')
                                      .format(tempStartDate!),
                              onPressed: () async {
                                DateTime? p = await showDatePicker(
                                    context: context,
                                    initialDate: tempStartDate ??
                                        tempEndDate ??
                                        DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: tempEndDate ?? DateTime.now(),
                                    builder: (c, ch) => Theme(
                                        data: themeProvider.isDarkMode
                                            ? themeProvider.darkTheme
                                            : themeProvider.lightTheme,
                                        child: ch!));
                                if (p != null)
                                  setModalState(() => tempStartDate = p);
                              },
                              color: themeProvider.appSecondaryBackground,
                              textStyle: GoogleFonts.inter(
                                  color: themeProvider.primaryText,
                                  fontSize: 14),
                              elevation: 1,
                              icon: Icon(Icons.calendar_today_outlined,
                                  size: 18, color: themeProvider.secondaryText),
                              height: 45)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: CustomButton(
                              text: tempEndDate == null
                                  ? 'End Date'
                                  : DateFormat('dd MMM, yy')
                                      .format(tempEndDate!),
                              onPressed: () async {
                                DateTime? p = await showDatePicker(
                                    context: context,
                                    initialDate: tempEndDate ?? DateTime.now(),
                                    firstDate: tempStartDate ?? DateTime(2020),
                                    lastDate: DateTime.now(),
                                    builder: (c, ch) => Theme(
                                        data: themeProvider.isDarkMode
                                            ? themeProvider.darkTheme
                                            : themeProvider.lightTheme,
                                        child: ch!));
                                if (p != null)
                                  setModalState(() => tempEndDate = p);
                              },
                              color: themeProvider.appSecondaryBackground,
                              textStyle: GoogleFonts.inter(
                                  color: themeProvider.primaryText,
                                  fontSize: 14),
                              elevation: 1,
                              icon: Icon(Icons.calendar_today_outlined,
                                  size: 18, color: themeProvider.secondaryText),
                              height: 45)),
                    ]),
                    const SizedBox(height: 28),
                    Row(children: [
                      Expanded(
                          child: CustomButton(
                              text: 'Reset Filters',
                              onPressed: () => setModalState(() {
                                    tempStatus = null;
                                    tempStartDate = null;
                                    tempEndDate = null;
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
                                  _selectedStatusFilter = tempStatus;
                                  _selectedStartDate = tempStartDate;
                                  _selectedEndDate = tempEndDate;
                                });
                                _fetchOrders(page: 1, isRefresh: true);
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
    final adminAccentColor = themeProvider.gas2doorPurple;

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        title: _isSearchBarVisible
            ? CustomInput(
                controller: _searchController,
                hintText: "Search Order ID, Customer...")
            : Text('Order Management',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600)),
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
                color: adminAccentColor),
            onPressed: () => setState(() {
              _isSearchBarVisible = !_isSearchBarVisible;
              if (!_isSearchBarVisible) _searchController.clear();
            }),
          ),
          IconButton(
            icon: Icon(Icons.filter_list_alt, color: adminAccentColor),
            onPressed: () => _showFilterBottomSheet(themeProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchOrders(page: 1, isRefresh: true),
        color: adminAccentColor,
        child: _buildBody(themeProvider),
      ),
    );
  }

  Widget _buildBody(ThemeProvider themeProvider) {
    if (_isLoading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_orders.isEmpty) {
      return const Center(child: Text("No orders found."));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12.0),
      itemCount: _orders.length + (_isFetchingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _orders.length) {
          return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: CircularProgressIndicator()));
        }
        final order = _orders[index];
        return _AdminOrderListItemWidget(
          order: order,
          themeProvider: themeProvider,
          onTap: () => _navigateToOrderDetails(order.id),
        );
      },
    );
  }
}

class _AdminOrderListItemWidget extends StatelessWidget {
  final AdminOrderSummaryModel order;
  final ThemeProvider themeProvider;
  final VoidCallback onTap;

  const _AdminOrderListItemWidget({
    required this.order,
    required this.themeProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
        margin: const EdgeInsets.only(bottom: 12.0),
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
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(order.status,
                        style: GoogleFonts.inter(
                            color: Colors.blue, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(order.formattedOrderDate,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: themeProvider.secondaryText)),
                const Divider(height: 20),
                Text('Customer: ${order.customer.name}',
                    style: GoogleFonts.inter()),
                Text('Driver: ${order.driver?.name ?? "Unassigned"}',
                    style: GoogleFonts.inter()),
                Text('Items: ${order.itemsPreview}',
                    style: GoogleFonts.inter()),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                      'Total: ₦${NumberFormat("#,##0").format(order.totalAmount)}',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ));
  }
}
