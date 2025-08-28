// File: lib/screens/customer/order_placement_screen.dart
// ADVISORY: This version fixes the navigation error when proceeding to payment.
// UPDATE: Standardized units to kobo for calculations; deliveryFee now in kobo, display /100.

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart'; // Added for internal logging
import 'package:sentry_flutter/sentry_flutter.dart'; // Added for Sentry integration

import '../../models/address_model.dart';
import '../../models/user.dart' as app_user;
import '../../models/system_config_model.dart';
import '../../models/place_order_response_model.dart';
import '../../models/order.dart' as app_order_model;

import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/input.dart';
import './address_list_screen.dart';
import './payment_screen.dart';
import './order_summary_screen.dart';
import './customer_dashboard_screen.dart';

// Initialize a logger for this file
final _logger = Logger('OrderPlacementScreen');

class GasCylinder {
  final String id;
  final String sizeLabel;
  final double price; // price in naira
  final IconData icon;

  GasCylinder({
    required this.id,
    required this.sizeLabel,
    required this.price,
    this.icon = Icons.propane_tank_outlined,
  });
}

class OrderItem {
  final GasCylinder cylinder;
  int quantity;

  OrderItem({required this.cylinder, this.quantity = 1});

  double get itemSubtotal => cylinder.price * quantity * 100; // To kobo

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderItem &&
          runtimeType == other.runtimeType &&
          cylinder.id == other.cylinder.id;

  @override
  int get hashCode => cylinder.id.hashCode;
}

class Promotion {
  final String code;
  final String description;
  final double discountPercentage;
  final double fixedDiscountAmount; // in naira
  final bool freeDelivery;

  Promotion({
    required this.code,
    required this.description,
    this.discountPercentage = 0.0,
    this.fixedDiscountAmount = 0.0,
    this.freeDelivery = false,
  });
}

class OrderPlacementScreen extends StatefulWidget {
  static const String routeName = '/order_placement';
  final bool isRefill;
  final String? refillCylinderSize;
  final AddressModel? initialAddress;
  final String? customerId;
  final String? preselectedCylinderIdFromDeal;
  final String? prefilledPromoCode;

  const OrderPlacementScreen({
    super.key,
    this.isRefill = false,
    this.refillCylinderSize,
    this.initialAddress,
    this.customerId,
    this.preselectedCylinderIdFromDeal,
    this.prefilledPromoCode,
  });

  @override
  State<OrderPlacementScreen> createState() => _OrderPlacementScreenState();
}

class _OrderPlacementScreenState extends State<OrderPlacementScreen>
    with TickerProviderStateMixin {
  final _recipientFormKey = GlobalKey<FormState>();

  AddressModel? _selectedDeliveryAddress;
  bool _isLoadingAddress = true;
  List<GasCylinder> _availableCylindersFromConfig = [];
  final List<OrderItem> _orderItems = [];

  final TextEditingController _promoCodeController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  Promotion? _appliedUIPromotion;
  SystemConfigModel? _systemConfig;

  FeeSettings? _feeSettings;
  bool _isExpressDelivery = false;
  bool _isPlacingOrder = false;
  bool _isSelfRecipient = true;
  final TextEditingController _recipientNameController =
      TextEditingController();
  final TextEditingController _recipientPhoneController =
      TextEditingController();

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _sectionSlideAnimations;

  app_user.User? _currentUserProfile;
  double _walletBalance = 0.0;
  bool _useWalletBalance = false;

  bool _isLoadingInitialData = true;
  String? _initialDataErrorMessage;

  // << NEW: State for Pay on Arrival feature >>
  String _selectedPaymentMethod = 'online';

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _logger.info('OrderPlacementScreen initialized.'); // Log info
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'lifecycle',
        message: 'OrderPlacementScreen initialized',
        level: SentryLevel.info)); // Sentry breadcrumb

    if (widget.initialAddress != null) {
      _selectedDeliveryAddress = widget.initialAddress;
      _isLoadingAddress = false;
      _logger.info('Initial address provided from arguments.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'order_placement',
          message: 'Initial address set from arguments',
          data: {'address_id': widget.initialAddress?.id},
          level: SentryLevel.info));
    }
    if (widget.prefilledPromoCode != null) {
      _promoCodeController.text = widget.prefilledPromoCode!;
      _logger
          .info('Prefilled promo code applied: ${widget.prefilledPromoCode}');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'order_placement',
          message: 'Prefilled promo code set',
          data: {'promo_code': widget.prefilledPromoCode},
          level: SentryLevel.info));
    }

    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    // << FIX: Adjusted the animation interval calculation to prevent the crash >>
    _sectionSlideAnimations = List.generate(
      8, // Number of animated sections
      (index) => Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
          .animate(CurvedAnimation(
              parent: _entryAnimController,
              curve: Interval(
                  (0.08 * index).clamp(0.0, 1.0), // Start time
                  (0.5 + (0.1 * index))
                      .clamp(0.0, 1.0), // End time, clamped to 1.0
                  curve: Curves.easeOutCubic))),
    );

    _initializeScreenData();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    _promoCodeController.dispose();
    _referralCodeController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _logger.info('OrderPlacementScreen disposed.'); // Log info
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'lifecycle',
        message: 'OrderPlacementScreen disposed',
        level: SentryLevel.info)); // Sentry breadcrumb
    super.dispose();
  }

  void _showFeedbackSnackbar(String message,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    Color backgroundColor = themeProvider.gas2doorPrimaryBlue;
    if (isError) {
      backgroundColor = themeProvider.errorColor;
      _logger.warning(
          'Snackbar Error: $message'); // Log warnings for user-facing errors
    } else if (isSuccess) {
      backgroundColor = themeProvider.successColor;
      _logger.info(
          'Snackbar Success: $message'); // Log info for user-facing successes
    } else {
      _logger.info('Snackbar Info: $message'); // Log info for other messages
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: backgroundColor.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 6,
      ),
    );
  }

  Future<void> _initializeScreenData() async {
    // << MODIFIED: This method was updated to store the full system config >>
    if (!mounted) return;
    _logger.info('Initializing screen data...'); // Log info
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'data_loading',
        message: 'Starting initial screen data load',
        level: SentryLevel.info));

    setState(() {
      _isLoadingInitialData = true;
      _initialDataErrorMessage = null;
    });

    try {
      final String? currentUserId =
          widget.customerId ?? await _authService.getUserId();
      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception("User not identified. Please login again.");
      }
      _logger.fine('Current user ID: $currentUserId'); // Log fine (debug-level)

      // Set Sentry user context once user ID is identified
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: currentUserId));
      });

      final results = await Future.wait([
        _apiService.getSystemConfig(),
        _apiService.getMyProfile(),
      ]);

      final systemConfig = results[0] as SystemConfigModel;
      final userProfile = results[1] as app_user.User;

      if (mounted) {
        setState(() {
          _systemConfig = systemConfig; // Store the full config
          _feeSettings = systemConfig.feeSettings;
          _currentUserProfile = userProfile;
          _walletBalance = userProfile.walletBalance;

          // Set more detailed Sentry user context after profile is loaded
          Sentry.configureScope((scope) {
            scope.setUser(SentryUser(
              id: userProfile.id,
              email: userProfile.email, // Be mindful of PII in production
              username: userProfile.name, // Be mindful of PII in production
            ));
          });
          _logger.info('User profile and system config loaded.'); // Log info
          Sentry.addBreadcrumb(Breadcrumb(
              category: 'data_loading',
              message: 'User profile and system config loaded',
              level: SentryLevel.info));

          _availableCylindersFromConfig = systemConfig.cylinderSettings
              .where((cs) => cs.isActive == true)
              .map((cs) => GasCylinder(
                  id: cs.id,
                  sizeLabel: cs.name,
                  price: cs.price /
                      100.0)) // FIX: Divide by 100.0 to convert kobo to naira
              .toList();
          _logger.info(
              'Available cylinders from config: ${_availableCylindersFromConfig.length}'); // Log info

          if (_selectedDeliveryAddress == null &&
              userProfile.defaultAddressId != null &&
              userProfile.defaultAddressId!.isNotEmpty) {
            _fetchAndSetDefaultAddress(userProfile.defaultAddressId!);
          } else {
            _isLoadingAddress = false;
            _logger.info(
                'No default address to fetch or initial address already set.'); // Log info
          }

          _prepopulateItemsIfNeeded();
          if (widget.prefilledPromoCode != null &&
              widget.prefilledPromoCode!.isNotEmpty) {
            _handleApplyPromoCode(); // Apply prefilled promo code on load
          }

          _isLoadingInitialData = false;
        });
        _entryAnimController.forward();
        _logger.info('Initial screen data loaded successfully.'); // Log info
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'data_loading',
            message: 'Initial screen data load complete',
            level: SentryLevel.info));
      }
    } catch (e, st) {
      // Capture stack trace for Sentry
      _logger.severe("Error loading page setup: $e", e, st); // Log severe error
      Sentry.captureException(e, stackTrace: st); // Send error to Sentry
      if (mounted) {
        setState(() {
          _initialDataErrorMessage =
              "Error loading page setup: ${e.toString().replaceFirst("Exception: ", "")}";
          _isLoadingInitialData = false;
          _isLoadingAddress = false;
        });
      }
    }
  }

  Future<void> _fetchAndSetDefaultAddress(String defaultAddressId) async {
    if (!mounted) return;
    _logger.info(
        'Attempting to fetch and set default address: $defaultAddressId'); // Log info
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'address_management',
        message: 'Fetching default address',
        data: {'default_address_id': defaultAddressId},
        level: SentryLevel.info));

    setState(() => _isLoadingAddress = true);
    try {
      final allAddresses = await _apiService.getMyAddresses();
      if (allAddresses.isNotEmpty && mounted) {
        final foundDefault = allAddresses
            .firstWhereOrNull((addr) => addr.id == defaultAddressId);
        setState(() {
          _selectedDeliveryAddress = foundDefault ?? allAddresses.first;
          _isLoadingAddress = false;
        });
        _logger.info(
            'Default address found and set: ${_selectedDeliveryAddress?.id}'); // Log info
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'address_management',
            message: 'Default address set',
            data: {'address_id': _selectedDeliveryAddress?.id},
            level: SentryLevel.info));
      } else if (mounted) {
        setState(() => _isLoadingAddress = false);
        _logger.warning(
            'No addresses found or default address not found, could not set default.'); // Log warning
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'address_management',
            message:
                'Could not set default address (no addresses or not found)',
            level: SentryLevel.warning));
      }
    } catch (e, st) {
      // Capture stack trace for Sentry
      _logger.severe(
          "Error fetching default address: $e", e, st); // Log severe error
      Sentry.captureException(e, stackTrace: st); // Send error to Sentry
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  void _prepopulateItemsIfNeeded() {
    if (_availableCylindersFromConfig.isEmpty) return;
    _logger.info('Checking if items need prepopulation.'); // Log info

    if (widget.isRefill && widget.refillCylinderSize != null) {
      final matchingCylinder = _availableCylindersFromConfig.firstWhereOrNull(
          (cyl) =>
              cyl.sizeLabel
                  .toLowerCase()
                  .contains(widget.refillCylinderSize!.toLowerCase()) ||
              cyl.id == widget.refillCylinderSize);
      if (matchingCylinder != null) {
        _updateOrderItemQuantity(matchingCylinder, 1, fromInit: true);
        _logger.info(
            'Refill item prepopulated: ${matchingCylinder.sizeLabel}'); // Log info
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'order_placement',
            message: 'Refill item prepopulated',
            data: {'cylinder_id': matchingCylinder.id, 'quantity': 1},
            level: SentryLevel.info));
      } else {
        _logger.warning(
            'Refill cylinder size not found: ${widget.refillCylinderSize}'); // Log warning
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'order_placement',
            message: 'Refill cylinder not found for prepopulation',
            data: {'refill_size_attempted': widget.refillCylinderSize},
            level: SentryLevel.warning));
      }
    } else if (widget.preselectedCylinderIdFromDeal != null) {
      final matchingCylinder = _availableCylindersFromConfig.firstWhereOrNull(
          (cyl) => cyl.id == widget.preselectedCylinderIdFromDeal);
      if (matchingCylinder != null) {
        _updateOrderItemQuantity(matchingCylinder, 1, fromInit: true);
        _logger.info(
            'Preselected deal item prepopulated: ${matchingCylinder.sizeLabel}'); // Log info
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'order_placement',
            message: 'Deal item prepopulated',
            data: {'cylinder_id': matchingCylinder.id, 'quantity': 1},
            level: SentryLevel.info));
      } else {
        _logger.warning(
            'Preselected cylinder ID from deal not found: ${widget.preselectedCylinderIdFromDeal}'); // Log warning
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'order_placement',
            message: 'Deal cylinder not found for prepopulation',
            data: {
              'preselected_id_attempted': widget.preselectedCylinderIdFromDeal
            },
            level: SentryLevel.warning));
      }
    }
  }

  Future<void> _handleChangeAddress() async {
    HapticFeedback.lightImpact();
    _logger.info('User initiated change address flow.'); // Log info
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'navigation',
        message: 'Attempting to change delivery address',
        level: SentryLevel.info));

    final String? currentId = widget.customerId ?? _currentUserProfile?.id;
    if (currentId == null || currentId.isEmpty) {
      _showFeedbackSnackbar("User information missing.", isError: true);
      _logger.warning('Cannot change address: User ID missing.'); // Log warning
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'address_management',
          message: 'Cannot change address: User ID missing',
          level: SentryLevel.warning));
      return;
    }
    final result = await Navigator.of(context, rootNavigator: true).pushNamed(
      AddressListScreen.routeName,
      arguments: {
        'isSelectingAddress': true,
        'currentAddressId': _selectedDeliveryAddress?.id,
        'customerId': currentId,
      },
    );

    if (result != null && result is AddressModel && mounted) {
      setState(() => _selectedDeliveryAddress = result);
      _showFeedbackSnackbar('Delivery address updated.', isSuccess: true);
      _logger.info(
          'Delivery address successfully updated to: ${result.fullAddress}'); // Log info
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'address_management',
          message: 'Delivery address updated',
          data: {
            'new_address_id': result.id,
            'full_address': result.fullAddress
          },
          level: SentryLevel.info));
    } else {
      _logger.info(
          'Address change cancelled or no new address selected.'); // Log info
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'address_management',
          message: 'Address selection cancelled or no new address selected',
          level: SentryLevel.info));
    }
  }

  void _updateOrderItemQuantity(GasCylinder cylinder, int change,
      {bool fromInit = false}) {
    if (!fromInit) HapticFeedback.selectionClick();
    setState(() {
      final existingIndex =
          _orderItems.indexWhere((item) => item.cylinder.id == cylinder.id);
      if (existingIndex != -1) {
        _orderItems[existingIndex].quantity += change;
        if (_orderItems[existingIndex].quantity <= 0) {
          final removedCylinderLabel =
              _orderItems[existingIndex].cylinder.sizeLabel;
          _orderItems.removeAt(existingIndex);
          if (!fromInit) {
            _showFeedbackSnackbar(
                '${removedCylinderLabel} removed from order.');
            _logger
                .info('$removedCylinderLabel removed from order.'); // Log info
            Sentry.addBreadcrumb(Breadcrumb(
                category: 'order_item_update',
                message: 'Item removed from order',
                data: {'cylinder_id': cylinder.id, 'quantity_change': change},
                level: SentryLevel.info));
          }
        } else {
          _logger.info(
              '${cylinder.sizeLabel} quantity updated to ${_orderItems[existingIndex].quantity}.'); // Log info
          Sentry.addBreadcrumb(Breadcrumb(
              category: 'order_item_update',
              message: 'Item quantity updated',
              data: {
                'cylinder_id': cylinder.id,
                'quantity_change': change,
                'new_quantity': _orderItems[existingIndex].quantity
              },
              level: SentryLevel.info));
        }
      } else if (change > 0) {
        _orderItems.add(OrderItem(cylinder: cylinder, quantity: change));
        if (!fromInit) {
          _showFeedbackSnackbar('${cylinder.sizeLabel} added to order.',
              isSuccess: true);
          _logger.info(
              '${cylinder.sizeLabel} added to order with quantity $change.'); // Log info
          Sentry.addBreadcrumb(Breadcrumb(
              category: 'order_item_update',
              message: 'Item added to order',
              data: {'cylinder_id': cylinder.id, 'quantity_added': change},
              level: SentryLevel.info));
        }
      }
      _logger.fine(
          'Current order items: ${_orderItems.map((e) => '${e.cylinder.sizeLabel} x ${e.quantity}').join(', ')}'); // Log fine
    });
  }

  double _calculateItemsSubtotal() =>
      _orderItems.fold(0.0, (sum, item) => sum + item.itemSubtotal); // kobo

  double _calculateDeliveryFee() {
    if (_feeSettings == null) return 0.0;
    if (_appliedUIPromotion?.freeDelivery == true) return 0.0;

    double totalDeliveryFeeKobo = _isExpressDelivery
        ? (_feeSettings!.baseDeliveryFee +
                _feeSettings!.expressDeliverySurcharge)
            .toDouble()
        : _feeSettings!.baseDeliveryFee.toDouble(); // FIX: Convert to double

    final int totalQuantity =
        _orderItems.fold(0, (sum, item) => sum + item.quantity);

    const double perAdditionalCylinderSurchargeKobo =
        1500.0; // Assuming this is in kobo, or needs conversion from naira

    if (totalQuantity > 1) {
      totalDeliveryFeeKobo +=
          (totalQuantity - 1) * perAdditionalCylinderSurchargeKobo;
    }
    return totalDeliveryFeeKobo; // Return in kobo
  }

  double _calculateVat(double amount_kobo) => _feeSettings == null
      ? 0.0
      : amount_kobo * (_feeSettings!.vatPercentage / 100);

  double _calculateServiceFee(double subtotal_kobo) => _feeSettings == null
      ? 0.0
      : subtotal_kobo * (_feeSettings!.serviceFeePercentage / 100);

  double _calculateTotalBeforeWallet() {
    final subtotal = _calculateItemsSubtotal(); // kobo
    if (subtotal == 0) return 0.0;
    double discount = 0.0;
    if (_appliedUIPromotion != null) {
      discount = _appliedUIPromotion!.fixedDiscountAmount > 0
          ? _appliedUIPromotion!.fixedDiscountAmount * 100 // naira to kobo
          : subtotal * _appliedUIPromotion!.discountPercentage;
    }
    final subtotalAfterDiscount = subtotal - discount;
    final serviceFee = _calculateServiceFee(subtotalAfterDiscount);
    final vat = _calculateVat(subtotalAfterDiscount);
    final deliveryFee = _calculateDeliveryFee(); // kobo
    return subtotalAfterDiscount + deliveryFee + vat + serviceFee;
  }

  double _getWalletAmountToUse() => _useWalletBalance
      ? min(
          _calculateTotalBeforeWallet(), _walletBalance * 100) // naira to kobo
      : 0.0;

  double _calculateGrandTotal() =>
      _calculateTotalBeforeWallet() - _getWalletAmountToUse();

  void _handleApplyPromoCode() {
    HapticFeedback.lightImpact();
    final code = _promoCodeController.text.trim().toUpperCase();
    FocusScope.of(context).unfocus();
    _logger.info('Attempting to apply promo code: $code'); // Log info
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'promotion',
        message: 'Applying promo code',
        data: {'promo_code_attempted': code},
        level: SentryLevel.info));

    if (code.isEmpty) {
      _showFeedbackSnackbar('Please enter a promo code.', isError: true);
      _logger.warning('Promo code input was empty.'); // Log warning
      return;
    }
    final Map<String, Promotion> validPromotionsForUI = {
      'GAS2DOOR20': Promotion(
          code: 'GAS2DOOR20',
          description: '20% off on total items',
          discountPercentage: 0.20),
      'FREEDEL': Promotion(
          code: 'FREEDEL',
          description: 'Free Delivery Applied!',
          freeDelivery: true),
    };
    if (validPromotionsForUI.containsKey(code)) {
      setState(() => _appliedUIPromotion = validPromotionsForUI[code]);
      _showFeedbackSnackbar('Promo code "$code" applied for estimation!',
          isSuccess: true);
      _logger.info(
          'Promo code "$code" successfully applied for UI estimation.'); // Log info
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'promotion',
          message: 'Promo code applied (UI estimation)',
          data: {
            'promo_code': code,
            'description': _appliedUIPromotion?.description
          },
          level: SentryLevel.info));
    } else {
      setState(() => _appliedUIPromotion = null);
      _showFeedbackSnackbar(
          '"$code" will be attempted. Actual discount applied by server.');
      _logger.info(
          'Promo code "$code" not recognized for UI estimation, will be sent to server.'); // Log info
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'promotion',
          message: 'Promo code not recognized for UI, sending to server',
          data: {'promo_code': code},
          level: SentryLevel.info));
    }
  }

  // << NEW HELPER METHOD >>
  // This is the geometric logic to check if a point is inside a polygon.
  bool _isPointInZone(double lat, double lng, List<List<double>> polygon) {
    if (polygon.isEmpty) return false;
    int intersections = 0;
    for (int i = 0; i < polygon.length; i++) {
      List<double> p1 = polygon[i];
      List<double> p2 = polygon[(i + 1) % polygon.length];

      if (p1.length < 2 || p2.length < 2) continue;
      double p1Lng = p1[0];
      double p1Lat = p1[1];
      double p2Lng = p2[0];
      double p2Lat = p2[1];

      if (lat < p1Lat != lat < p2Lat &&
          lng < (p2Lng - p1Lng) * (lat - p1Lat) / (p2Lat - p1Lat) + p1Lng) {
        intersections++;
      }
    }
    return (intersections % 2) == 1;
  }

  Future<void> _handlePlaceOrder() async {
    // << MODIFIED: This method was updated for both Service Zone and Pay on Arrival features >>
    _logger.info('User initiated order placement.');
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'order_flow',
        message: 'Starting order placement process',
        level: SentryLevel.info));

    if (_selectedDeliveryAddress == null) {
      _showFeedbackSnackbar("Please select a delivery address.", isError: true);
      _logger.warning('Order placement blocked: No delivery address selected.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'order_flow',
          message: 'Order placement failed: No delivery address selected',
          level: SentryLevel.warning));
      return;
    }
    if (_orderItems.isEmpty) {
      _showFeedbackSnackbar("Please add at least one item to your order.",
          isError: true);
      _logger.warning('Order placement blocked: No items in order.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'order_flow',
          message: 'Order placement failed: No items in order',
          level: SentryLevel.warning));
      return;
    }
    if (!_isSelfRecipient &&
        !(_recipientFormKey.currentState?.validate() ?? false)) {
      _showFeedbackSnackbar('Please provide valid recipient details.',
          isError: true);
      _logger.warning('Order placement blocked: Invalid recipient details.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'order_flow',
          message: 'Order placement failed: Invalid recipient details',
          level: SentryLevel.warning));
      return;
    }
    final String? currentActiveCustomerId =
        widget.customerId ?? _currentUserProfile?.id;
    if (currentActiveCustomerId == null || currentActiveCustomerId.isEmpty) {
      _showFeedbackSnackbar("User not identified. Please re-login.",
          isError: true);
      _logger.severe('Order placement blocked: User ID missing or invalid.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'order_flow',
          message: 'Order placement failed: User ID missing',
          level: SentryLevel.fatal));
      return;
    }
    // Service Zone Validation
    final deliveryLat = _selectedDeliveryAddress?.latitude;
    final deliveryLng = _selectedDeliveryAddress?.longitude;
    final activeZones = _systemConfig?.activeZones ?? [];
    String outOfZoneMessage = 'Sorry, we do not currently service your area.';

    if (deliveryLat != null && deliveryLng != null && activeZones.isNotEmpty) {
      bool isAddressInServiceZone = activeZones.any(
          (zone) => _isPointInZone(deliveryLat, deliveryLng, zone.coordinates));
      if (!isAddressInServiceZone) {
        if (activeZones.isNotEmpty)
          outOfZoneMessage = activeZones.first.outOfZoneMessage;
        _showFeedbackSnackbar(outOfZoneMessage, isError: true);
        _logger
            .warning('Order placement blocked: Address not in service zone.');
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'order_flow',
            message: 'Order placement failed: Address not in service zone',
            data: {'lat': deliveryLat, 'lng': deliveryLng},
            level: SentryLevel.warning));
        return;
      }
    } else if (deliveryLat != null &&
        deliveryLng != null &&
        activeZones.isEmpty) {
      _showFeedbackSnackbar(
          "We are not currently accepting orders. Please check back later.",
          isError: true);
      _logger.warning(
          'Order placement blocked: No active service zones configured.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'order_flow',
          message: 'Order placement failed: No active service zones configured',
          level: SentryLevel.warning));
      return;
    }

    setState(() => _isPlacingOrder = true);
    final List<Map<String, dynamic>> orderItemsPayload = _orderItems
        .map((item) => {
              'cylinderId': item.cylinder.id,
              'productName': item.cylinder.sizeLabel,
              'quantity': item.quantity,
              'unitPrice':
                  (item.cylinder.price * 100).toInt() // Convert to kobo
            })
        .toList();
    String recipientNameValue;
    String recipientPhoneValue;
    if (_isSelfRecipient) {
      recipientNameValue = _currentUserProfile?.name ?? 'Self User';
      recipientPhoneValue = _currentUserProfile?.phone ?? '';
      if (recipientPhoneValue.isEmpty && mounted) {
        _showFeedbackSnackbar(
            "Your phone number is missing. Please update your profile.",
            isError: true);
        setState(() => _isPlacingOrder = false);
        _logger.warning(
            'Order placement blocked: Self recipient phone number missing.');
        Sentry.addBreadcrumb(Breadcrumb(
            category: 'order_flow',
            message:
                'Order placement failed: Self recipient phone number missing',
            level: SentryLevel.warning));
        return;
      }
    } else {
      recipientNameValue = _recipientNameController.text.trim();
      recipientPhoneValue = _recipientPhoneController.text.trim();
    }
    final Map<String, dynamic> orderPayloadForApi = {
      'deliveryAddressId': _selectedDeliveryAddress!.id,
      'items': orderItemsPayload,
      'recipientName': recipientNameValue,
      'recipientPhone': recipientPhoneValue,
      'isExpress': _isExpressDelivery,
      'useWalletBalance': _useWalletBalance,
      if (_promoCodeController.text.trim().isNotEmpty)
        'promoCodeApplied': _promoCodeController.text.trim().toUpperCase(),
      if (_referralCodeController.text.trim().isNotEmpty)
        'referralCode': _referralCodeController.text.trim().toUpperCase(),

      // Add the selected payment method to the payload if it's a first time customer
      if (_currentUserProfile?.isFirstTimeCustomer == true)
        'paymentMethod':
            _selectedPaymentMethod == 'on_pickup' ? 'payOnPickup' : 'paystack',
    };

    _logger.fine('Order payload prepared: $orderPayloadForApi');
    Sentry.addBreadcrumb(Breadcrumb(
        category: 'order_flow',
        message: 'Order payload prepared',
        data: orderPayloadForApi,
        level: SentryLevel.debug));

    try {
      final PlaceOrderResponseModel response =
          await _apiService.placeOrder(orderPayloadForApi);
      if (!mounted) {
        _logger.warning('Order placement successful, but screen unmounted.');
        return;
      }

      _logger.info(
          'Order placed successfully. Server response: ${response.message}');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'order_flow',
          message: 'Order API call successful',
          data: {
            'order_id': response.order.id,
            'payment_needed': response.paymentNeeded,
            'referral_code': _referralCodeController.text.trim().toUpperCase(),
          },
          level: SentryLevel.info));

      if (response.paymentNeeded) {
        _showFeedbackSnackbar("Order confirmed. Proceeding to payment...");
        _logger.info(
            'Navigating to PaymentScreen for order ${response.order.id}.');
        Navigator.of(context)
            .pushReplacementNamed(PaymentScreen.routeName, arguments: {
          'orderId': response.order.id,
          'amount': response.grandTotalToPay,
          'customer': _currentUserProfile!,
          'order': response.order,
          'itemDescription':
              '${_orderItems.length} cylinder(s) - Order #${response.order.shortOrderId}',
        });
      } else {
        _showFeedbackSnackbar(
            response.message.isNotEmpty
                ? response.message
                : "Order placed successfully!",
            isSuccess: true);
        _logger.info(
            'Navigating to OrderSummaryScreen for order ${response.order.id} (no payment needed).');
        Navigator.of(context).pushNamedAndRemoveUntil(
            OrderSummaryScreen.routeName,
            ModalRoute.withName(CustomerDashboardScreen.routeName),
            arguments: {
              'orderId': response.order.id,
              'customerId': currentActiveCustomerId, // <-- ADD THIS LINE
              'showConfirmation': true,
              'orderPayload': response.order,
            });
      }
    } catch (e, st) {
      _logger.severe("Order placement failed: $e", e, st);
      Sentry.captureException(e,
          stackTrace: st,
          hint: Hint.withMap({
            'payload_attempted': orderPayloadForApi,
            'delivery_address_id': _selectedDeliveryAddress?.id,
            'user_id': currentActiveCustomerId,
          }));
      if (mounted) {
        _showFeedbackSnackbar(
            "Order placement failed: ${e.toString().replaceFirst("Exception: ", "")}",
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
      _logger.info('Order placement process finished.');
      Sentry.addBreadcrumb(Breadcrumb(
          category: 'order_flow',
          message: 'Order placement process completed',
          level: SentryLevel.info));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appBarTitle = widget.isRefill ? 'Refill Your Gas' : 'Place New Order';
    final double grandTotal = _calculateGrandTotal();

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text(appBarTitle,
            style: GoogleFonts.inter(
                color: themeProvider.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () {
            _logger.info(
                'Back button pressed on OrderPlacementScreen.'); // Log info
            Sentry.addBreadcrumb(Breadcrumb(
                category: 'navigation',
                message: 'Back button pressed from OrderPlacementScreen',
                level: SentryLevel.info));
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _isLoadingInitialData
          ? Center(
              child: CircularProgressIndicator(
                  color: themeProvider.gas2doorPrimaryBlue))
          : _initialDataErrorMessage != null
              ? _buildErrorState(themeProvider, _initialDataErrorMessage!)
              : Stack(
                  children: [
                    FadeTransition(
                      opacity: _entryAnimController,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                        child: Column(
                          children: <Widget>[
                            SlideTransition(
                                position: _sectionSlideAnimations[0],
                                child:
                                    _buildDeliveryAddressCard(themeProvider)),
                            const SizedBox(height: 24),
                            SlideTransition(
                                position: _sectionSlideAnimations[1],
                                child: _buildSelectItemCard(themeProvider)),
                            const SizedBox(height: 24),
                            SlideTransition(
                                position: _sectionSlideAnimations[2],
                                child:
                                    _buildRecipientDetailsCard(themeProvider)),
                            const SizedBox(height: 24),
                            SlideTransition(
                                position: _sectionSlideAnimations[3],
                                child:
                                    _buildDeliveryOptionsCard(themeProvider)),
                            const SizedBox(height: 24),
                            SlideTransition(
                                position: _sectionSlideAnimations[4],
                                child: _buildPromoCodeCard(themeProvider)),
                            const SizedBox(height: 24),
                            if (_walletBalance > 0)
                              SlideTransition(
                                  position: _sectionSlideAnimations[6],
                                  child: _buildWalletUsageCard(themeProvider)),
                            if (_walletBalance > 0) const SizedBox(height: 24),
                            // << NEW: Add payment method card if first time customer >>
                            if (_currentUserProfile?.isFirstTimeCustomer ==
                                true)
                              SlideTransition(
                                  position: _sectionSlideAnimations[5],
                                  child:
                                      _buildPaymentMethodCard(themeProvider)),
                            if (_currentUserProfile?.isFirstTimeCustomer ==
                                true)
                              const SizedBox(height: 24),
                            if (_orderItems.isNotEmpty)
                              SlideTransition(
                                  position: _sectionSlideAnimations[7],
                                  child: _buildOrderSummaryCard(themeProvider)),
                          ],
                        ),
                      ),
                    ),
                    if (_isPlacingOrder)
                      Container(
                        color:
                            themeProvider.appPrimaryBackground.withOpacity(0.7),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: themeProvider.gas2doorPrimaryBlue)),
                      ),
                  ],
                ),
      bottomNavigationBar: (_isLoadingInitialData ||
              _initialDataErrorMessage != null)
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                  color: themeProvider.cardBackground,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5))
                  ],
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20))),
              child: CustomButton(
                text: _isPlacingOrder
                    ? 'Placing Order...'
                    : 'Proceed to Checkout (${NumberFormat.currency(locale: 'en_NG', symbol: '₦').format(grandTotal / 100)})', // FIX: Divide by 100
                onPressed: (_isPlacingOrder ||
                        _orderItems.isEmpty ||
                        _selectedDeliveryAddress == null)
                    ? null
                    : _handlePlaceOrder,
                color:
                    themeProvider.gas2doorPrimaryBlue, // Reverted as requested
                height: 52,
                borderRadius: themeProvider.cardBorderRadiusValue,
                icon: _isPlacingOrder
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Icon(Icons.payment_rounded,
                        color: Colors.white, size: 22),
              ),
            ),
    );
  }

  Widget _buildDeliveryAddressCard(ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Delivery Address',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 10),
            _isLoadingAddress
                ? SizedBox(
                    height: 50,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: themeProvider.gas2doorPrimaryBlue)))
                : Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          color: themeProvider.gas2doorTeal, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                        _selectedDeliveryAddress?.fullAddress ??
                            'Please select an address',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: themeProvider.secondaryText,
                            height: 1.35),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _handleChangeAddress,
                        child: Text(
                            _selectedDeliveryAddress != null
                                ? 'Change'
                                : 'Select',
                            style: GoogleFonts.inter(
                                color: themeProvider.linkColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectItemCard(ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('2. Choose Your Gas',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 10),
            if (_availableCylindersFromConfig.isEmpty && !_isLoadingInitialData)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text("No gas cylinders available at the moment.",
                      style: GoogleFonts.inter(
                          color: themeProvider.secondaryText)))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _availableCylindersFromConfig.length,
                itemBuilder: (context, index) {
                  final cylinder = _availableCylindersFromConfig[index];
                  final currentQuantityInOrder = _orderItems
                          .firstWhereOrNull(
                              (item) => item.cylinder.id == cylinder.id)
                          ?.quantity ??
                      0;
                  final bool isSelected = currentQuantityInOrder > 0;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    decoration: BoxDecoration(
                        color: isSelected
                            ? themeProvider.primaryActionColor.withOpacity(0.05)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? themeProvider.primaryActionColor
                              : themeProvider.tertiaryText.withOpacity(0.2),
                          width: isSelected ? 1.5 : 1.0,
                        )),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(cylinder.icon,
                              color: themeProvider.gas2doorPrimaryBlue,
                              size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cylinder.sizeLabel,
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: themeProvider.primaryText)),
                                Text(
                                    NumberFormat.currency(
                                            locale: 'en_NG', symbol: '₦')
                                        .format(cylinder
                                            .price), // No /100 if price naira
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: themeProvider.secondaryText)),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                                color: themeProvider.appSecondaryBackground,
                                borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: Icon(Icons.remove,
                                        size: 18,
                                        color: currentQuantityInOrder > 0
                                            ? themeProvider.errorColor
                                            : themeProvider.secondaryText
                                                .withOpacity(0.5)),
                                    onPressed: currentQuantityInOrder > 0
                                        ? () => _updateOrderItemQuantity(
                                            cylinder, -1)
                                        : null,
                                    splashRadius: 18,
                                    visualDensity: VisualDensity.compact),
                                Text('$currentQuantityInOrder',
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: themeProvider.primaryText)),
                                IconButton(
                                    icon: Icon(Icons.add,
                                        size: 18,
                                        color:
                                            themeProvider.primaryActionColor),
                                    onPressed: (currentQuantityInOrder < 5)
                                        ? () => _updateOrderItemQuantity(
                                            cylinder, 1)
                                        : null,
                                    splashRadius: 18,
                                    visualDensity: VisualDensity.compact),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(height: 4),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientDetailsCard(ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _recipientFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('3. Recipient Information',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.primaryText)),
              const SizedBox(height: 4),
              SwitchListTile.adaptive(
                title: Text("I will receive this order myself",
                    style: GoogleFonts.inter(
                        color: themeProvider.primaryText, fontSize: 14.5)),
                value: _isSelfRecipient,
                onChanged: (bool value) {
                  setState(() {
                    _isSelfRecipient = value;
                    if (value) {
                      _recipientNameController.clear();
                      _recipientPhoneController.clear();
                      _logger.info('Recipient set to self.'); // Log info
                      Sentry.addBreadcrumb(Breadcrumb(
                          category: 'recipient_details',
                          message: 'Recipient set to self',
                          level: SentryLevel.info));
                    } else {
                      _recipientNameController.text =
                          _currentUserProfile?.name ?? '';
                      _recipientPhoneController.text =
                          _currentUserProfile?.phone ?? '';
                      _logger.info(
                          'Recipient set to other. Prefilled with user profile.'); // Log info
                      Sentry.addBreadcrumb(Breadcrumb(
                          category: 'recipient_details',
                          message:
                              'Recipient set to other, prefilling from profile',
                          level: SentryLevel.info));
                    }
                  });
                },
                activeColor: themeProvider.gas2doorTeal,
                contentPadding: EdgeInsets.zero,
              ),
              if (!_isSelfRecipient) ...[
                const SizedBox(height: 12),
                CustomInput(
                    controller: _recipientNameController,
                    labelText: "Recipient's Full Name*",
                    hintText: "Enter full name",
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (val) => (!_isSelfRecipient &&
                            (val == null || val.trim().isEmpty))
                        ? 'Recipient name is required'
                        : null),
                const SizedBox(height: 16),
                CustomInput(
                    controller: _recipientPhoneController,
                    labelText: "Recipient's Phone Number*",
                    hintText: "Enter contact number",
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (val) => (!_isSelfRecipient &&
                            (val == null || val.trim().isEmpty))
                        ? 'Recipient phone is required'
                        : (!_isSelfRecipient &&
                                val != null &&
                                !RegExp(r'^\+?\d{10,15}$').hasMatch(val.trim()))
                            ? 'Enter a valid phone number'
                            : null),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryOptionsCard(ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('4. Delivery Speed',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            SwitchListTile.adaptive(
              title: Text('Express Delivery',
                  style: GoogleFonts.inter(
                      color: themeProvider.primaryText,
                      fontWeight: FontWeight.w500,
                      fontSize: 15)),
              subtitle: Text(
                  '+ ${NumberFormat.currency(locale: 'en_NG', symbol: '₦').format((_feeSettings?.expressDeliverySurcharge ?? 0) / 100.0)} (Get it faster!)', // FIX: Divide by 100.0
                  style: GoogleFonts.inter(
                      fontSize: 13, color: themeProvider.secondaryText)),
              value: _isExpressDelivery,
              onChanged: (value) {
                setState(() => _isExpressDelivery = value);
                _logger.info('Express Delivery toggled to: $value'); // Log info
                Sentry.addBreadcrumb(Breadcrumb(
                    category: 'delivery_options',
                    message: 'Express Delivery toggled',
                    data: {'is_express_delivery': value},
                    level: SentryLevel.info));
              },
              activeColor: themeProvider.gas2doorTeal,
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.bolt_rounded,
                  color: _isExpressDelivery
                      ? themeProvider.gas2doorTeal
                      : themeProvider.secondaryText.withOpacity(0.7),
                  size: 26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCodeCard(ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('5. Apply Promotion',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: CustomInput(
                        controller: _promoCodeController,
                        hintText: 'Enter Promo Code',
                        labelText: 'Promo Code (Optional)',
                        textInputAction: TextInputAction.done,
                        prefixIcon: Icons.local_offer_outlined,
                        onFieldSubmitted: (_) => _handleApplyPromoCode())),
                const SizedBox(width: 10),
                CustomButton(
                    text: 'Apply',
                    onPressed: _handleApplyPromoCode,
                    color: themeProvider.gas2doorTeal,
                    height: 50,
                    textStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
            if (_appliedUIPromotion != null) ...[
              const SizedBox(height: 10),
              Text(_appliedUIPromotion!.description,
                  style: GoogleFonts.inter(
                      color: themeProvider.successColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWalletUsageCard(ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: SwitchListTile.adaptive(
          title: Text('Use Wallet Balance',
              style: GoogleFonts.inter(
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w600)),
          subtitle: Text(
              'Available: ${NumberFormat.currency(locale: 'en_NG', symbol: '₦').format(_walletBalance / 100)}', // No /100 if naira
              style: GoogleFonts.inter(
                  color: themeProvider.secondaryText, fontSize: 13)),
          value: _useWalletBalance,
          onChanged: _walletBalance <= 0
              ? null
              : (bool value) {
                  setState(() => _useWalletBalance = value);
                  _logger.info('Wallet usage toggled to: $value'); // Log info
                  Sentry.addBreadcrumb(Breadcrumb(
                      category: 'payment_options',
                      message: 'Wallet usage toggled',
                      data: {'use_wallet_balance': value},
                      level: SentryLevel.info));
                },
          activeColor: themeProvider.gas2doorTeal,
          secondary: Icon(Icons.account_balance_wallet_outlined,
              color: _useWalletBalance && _walletBalance > 0
                  ? themeProvider.gas2doorTeal
                  : themeProvider.secondaryText.withOpacity(0.7)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        ),
      ),
    );
  }

  // << NEW: Widget for Pay on Arrival feature >>
  Widget _buildPaymentMethodCard(ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('6. Payment Method',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: Text('Pay Online Now',
                  style: GoogleFonts.inter(
                      color: themeProvider.primaryText, fontSize: 15)),
              subtitle: Text('Secure payment with Card or Bank Transfer.',
                  style: GoogleFonts.inter(
                      color: themeProvider.secondaryText, fontSize: 13)),
              value: 'online',
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                setState(() => _selectedPaymentMethod = value!);
                _logger.info('Payment method selected: online');
                Sentry.addBreadcrumb(Breadcrumb(
                    category: 'payment_options',
                    message: 'Payment method selected: online',
                    level: SentryLevel.info));
              },
              activeColor: themeProvider.gas2doorTeal,
            ),
            RadioListTile<String>(
              title: Text('Pay on Driver Arrival',
                  style: GoogleFonts.inter(
                      color: themeProvider.primaryText, fontSize: 15)),
              subtitle: Text(
                  'Pay securely in the app when the driver arrives. (First order only)',
                  style: GoogleFonts.inter(
                      color: themeProvider.secondaryText, fontSize: 13)),
              value: 'on_pickup',
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                setState(() => _selectedPaymentMethod = value!);
                _logger.info('Payment method selected: on_pickup');
                Sentry.addBreadcrumb(Breadcrumb(
                    category: 'payment_options',
                    message: 'Payment method selected: on_pickup',
                    level: SentryLevel.info));
              },
              activeColor: themeProvider.gas2doorTeal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard(ThemeProvider themeProvider) {
    final itemsSubtotal = _calculateItemsSubtotal(); // kobo
    final deliveryFee = _calculateDeliveryFee(); // kobo
    final serviceFee = _calculateServiceFee(itemsSubtotal);
    final vat = _calculateVat(itemsSubtotal);
    double uiDiscount = 0.0;
    if (_appliedUIPromotion != null) {
      uiDiscount = _appliedUIPromotion!.fixedDiscountAmount > 0
          ? _appliedUIPromotion!.fixedDiscountAmount * 100 // naira to kobo
          : itemsSubtotal * _appliedUIPromotion!.discountPercentage;
    }
    final walletUsed = _getWalletAmountToUse();
    final grandTotal = _calculateGrandTotal();
    final currencyFormat = NumberFormat.currency(
        locale: 'en_NG', symbol: '₦'); // Changed symbol to '₦'

    return CustomCard(
      color: themeProvider.cardBackground.withOpacity(0.7),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Summary',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            _buildSummaryRow(
                'Items Subtotal:',
                currencyFormat.format(itemsSubtotal / 100),
                themeProvider), // Divide by 100 for display
            if (vat > 0)
              _buildSummaryRow(
                  'VAT:',
                  '+ ${currencyFormat.format(vat / 100)}', // Divide by 100 for display
                  themeProvider),
            if (serviceFee > 0)
              _buildSummaryRow(
                  'Service Fee:',
                  '+ ${currencyFormat.format(serviceFee / 100)}', // Divide by 100 for display
                  themeProvider),
            _buildSummaryRow(
                'Delivery Fee:',
                '+ ${currencyFormat.format(deliveryFee / 100)}', // Divide by 100 for display
                themeProvider),
            if (uiDiscount > 0)
              _buildSummaryRow(
                  'Discount:',
                  '- ${currencyFormat.format(uiDiscount / 100)}',
                  themeProvider, // Divide by 100 for display
                  isDiscount: true),
            if (walletUsed > 0)
              _buildSummaryRow(
                  'Wallet Deduction:',
                  '- ${currencyFormat.format(walletUsed / 100)}',
                  themeProvider, // Divide by 100 for display
                  isDiscount: true),
            Divider(
                height: 24,
                thickness: 0.5,
                color: themeProvider.tertiaryText.withOpacity(0.4)),
            _buildSummaryRow(
                'Total Payable:',
                currencyFormat.format(grandTotal / 100),
                themeProvider, // Divide by 100 for display
                isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
      String label, String value, ThemeProvider themeProvider,
      {bool isTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: isTotal ? 16 : 14,
                  color: isDiscount
                      ? themeProvider.successColor
                      : (isTotal
                          ? themeProvider.primaryText
                          : themeProvider.secondaryText),
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w500)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: isTotal ? 17 : 15,
                  color: isDiscount
                      ? themeProvider.successColor
                      : themeProvider.primaryText,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w600)),
        ],
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
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Error Loading Data',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                style: GoogleFonts.inter(
                    color: themeProvider.secondaryText, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            CustomButton(
                text: "Retry",
                onPressed: () {
                  _logger
                      .info('Retry button pressed on error state.'); // Log info
                  Sentry.addBreadcrumb(Breadcrumb(
                      category: 'error_recovery',
                      message: 'Retry button pressed on error state',
                      level: SentryLevel.info));
                  _initializeScreenData();
                },
                color: themeProvider.gas2doorPrimaryBlue,
                icon: Icon(Icons.refresh_rounded, color: Colors.white))
          ],
        ),
      ),
    );
  }
}
