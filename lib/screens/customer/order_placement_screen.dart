// File: lib/screens/customer/order_placement_screen.dart

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
import './order_details_screen.dart';
import '../customer/customer_dashboard_screen.dart';

class GasCylinder {
  final String id;
  final String sizeLabel;
  final double price;
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

  double get itemSubtotal => cylinder.price * quantity;

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
  final double fixedDiscountAmount;
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
  final List<Map<String, dynamic>>? lastOrderItems;
  final AddressModel? initialAddress;
  final String? customerId;
  //final String? promoCodeToApply;
  final String? preselectedCylinderIdFromDeal;

  const OrderPlacementScreen({
    super.key,
    this.isRefill = false,
    this.lastOrderItems,
    this.initialAddress,
    this.customerId,
    //this.promoCodeToApply,
    this.preselectedCylinderIdFromDeal,
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

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _selectedDeliveryAddress = widget.initialAddress;
      _isLoadingAddress = false;
    }
    /*
    if (widget.promoCodeToApply != null &&
        widget.promoCodeToApply!.isNotEmpty) {
      _promoCodeController.text = widget.promoCodeToApply!;
      _appliedUIPromotion = Promotion(
          code: widget.promoCodeToApply!,
          description: "Promo code will be attempted");
    }*/

    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _sectionSlideAnimations = List.generate(
      8, // Increased for new referral card
      (index) => Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
          .animate(CurvedAnimation(
              parent: _entryAnimController,
              curve: Interval(0.1 * index, (0.1 * index) + 0.5,
                  curve: Curves.easeOutCubic))),
    );

    _initializeScreenData();
  }

  Future<void> _initializeScreenData() async {
    if (!mounted) return;
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

      final results = await Future.wait([
        _apiService.getSystemConfig(),
        _apiService.getMyProfile(),
      ]);

      final systemConfig = results[0] as SystemConfigModel;
      final userProfile = results[1] as app_user.User;

      if (mounted) {
        setState(() {
          _feeSettings = systemConfig.feeSettings;
          _currentUserProfile = userProfile;
          _walletBalance = userProfile.walletBalance;

          _availableCylindersFromConfig = systemConfig.cylinderSettings
              .where((cs) => cs.isActive == true)
              .map((cs) => GasCylinder(
                    id: cs.id,
                    sizeLabel: cs.name,
                    price: cs.price,
                  ))
              .toList();

          if (_selectedDeliveryAddress == null &&
              userProfile.defaultAddressId != null &&
              userProfile.defaultAddressId!.isNotEmpty) {
            _fetchAndSetDefaultAddress(userProfile.defaultAddressId!);
          } else {
            _isLoadingAddress = false;
          }

          _prepopulateItemsIfNeeded();

          _isLoadingInitialData = false;
        });
        _entryAnimController.forward();
      }
    } catch (e) {
      if (mounted) {
        print("Error initializing OrderPlacementScreen data: $e");
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
    setState(() => _isLoadingAddress = true);
    try {
      final allAddresses = await _apiService.getMyAddresses();
      if (allAddresses.isNotEmpty && mounted) {
        final foundDefault = allAddresses
            .firstWhereOrNull((addr) => addr.id == defaultAddressId);
        if (foundDefault != null) {
          setState(() {
            _selectedDeliveryAddress = foundDefault;
            _isLoadingAddress = false;
          });
        } else {
          setState(() => _isLoadingAddress = false);
        }
      } else if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    } catch (e) {
      if (mounted) {
        print("Error fetching default address in OrderPlacement: $e");
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  void _prepopulateItemsIfNeeded() {
    if (_availableCylindersFromConfig.isEmpty) return;

    if (widget.isRefill && widget.lastOrderItems != null) {
      for (var itemData in widget.lastOrderItems!) {
        final cylinderId = itemData['cylinderId'] as String?;
        final quantity = itemData['quantity'] as int?;
        if (cylinderId != null && quantity != null && quantity > 0) {
          final matchingCylinder = _availableCylindersFromConfig
              .firstWhereOrNull((cyl) => cyl.id == cylinderId);
          if (matchingCylinder != null) {
            _updateOrderItemQuantity(matchingCylinder, quantity,
                fromInit: true);
          }
        }
      }
    } else if (widget.preselectedCylinderIdFromDeal != null) {
      final matchingCylinder = _availableCylindersFromConfig.firstWhereOrNull(
          (cyl) => cyl.id == widget.preselectedCylinderIdFromDeal);
      if (matchingCylinder != null) {
        _updateOrderItemQuantity(matchingCylinder, 1, fromInit: true);
      }
    }
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    _promoCodeController.dispose();
    _referralCodeController.dispose(); // <<< DISPOSE
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleChangeAddress() async {
    HapticFeedback.lightImpact();
    if (widget.customerId == null || widget.customerId!.isEmpty) {
      _showFeedbackSnackbar("User information missing.",
          isError: true, context: context);
      return;
    }
    final result = await Navigator.of(context, rootNavigator: true).pushNamed(
      AddressListScreen.routeName,
      arguments: {
        'isSelectingAddress': true,
        'currentAddressId': _selectedDeliveryAddress?.id,
        'customerId': widget.customerId,
      },
    );

    if (result != null && result is AddressModel && mounted) {
      setState(() {
        _selectedDeliveryAddress = result;
      });
      _showFeedbackSnackbar('Delivery address updated.',
          isSuccess: true, context: context);
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
          _orderItems.removeAt(existingIndex);
          if (!fromInit) {
            _showFeedbackSnackbar('${cylinder.sizeLabel} removed from order.',
                context: context);
          }
        }
      } else if (change > 0) {
        _orderItems.add(OrderItem(cylinder: cylinder, quantity: change));
        if (!fromInit) {
          _showFeedbackSnackbar('${cylinder.sizeLabel} added to order.',
              isSuccess: true, context: context);
        }
      }
    });
  }

  double _calculateItemsSubtotal() =>
      _orderItems.fold(0.0, (sum, item) => sum + item.itemSubtotal);

  double _calculateDeliveryFee() {
    if (_feeSettings == null) return 0.0;
    if (_appliedUIPromotion?.freeDelivery == true &&
        _appliedUIPromotion?.code.isNotEmpty == true) return 0.0;

    double totalDeliveryFee = _isExpressDelivery
        ? _feeSettings!.baseDeliveryFee + _feeSettings!.expressDeliverySurcharge
        : _feeSettings!.baseDeliveryFee;

    final int totalQuantity =
        _orderItems.fold(0, (sum, item) => sum + item.quantity);

    const double perAdditionalCylinderSurcharge = 200000;

    if (totalQuantity > 1) {
      totalDeliveryFee += (totalQuantity - 1) * perAdditionalCylinderSurcharge;
    }

    return totalDeliveryFee;
  }

  double _calculateVat(double amountSubjectToVat) {
    if (_feeSettings == null) return 0.0;
    return amountSubjectToVat * (_feeSettings!.vatPercentage / 100);
  }

  double _calculateServiceFee(double subtotal) {
    if (_feeSettings == null) return 0.0;
    return subtotal * (_feeSettings!.serviceFeePercentage / 100);
  }

  double _calculateTotalBeforeWallet() {
    final itemsSubtotal = _calculateItemsSubtotal();
    if (itemsSubtotal == 0 && _orderItems.isEmpty) return 0.0;

    double currentDiscountForDisplay = 0.0;
    if (_appliedUIPromotion != null) {
      if (_appliedUIPromotion!.fixedDiscountAmount > 0) {
        currentDiscountForDisplay =
            _appliedUIPromotion!.fixedDiscountAmount * 100;
      } else if (_appliedUIPromotion!.discountPercentage > 0) {
        currentDiscountForDisplay =
            itemsSubtotal * _appliedUIPromotion!.discountPercentage;
      }
    }
    final subtotalAfterDisplayDiscount =
        itemsSubtotal - currentDiscountForDisplay;

    final serviceFee = _calculateServiceFee(subtotalAfterDisplayDiscount > 0
        ? subtotalAfterDisplayDiscount
        : itemsSubtotal);
    final vat = _calculateVat(subtotalAfterDisplayDiscount > 0
        ? subtotalAfterDisplayDiscount
        : itemsSubtotal);
    final deliveryFee = _calculateDeliveryFee();

    return (subtotalAfterDisplayDiscount > 0
            ? subtotalAfterDisplayDiscount
            : itemsSubtotal) +
        deliveryFee +
        vat +
        serviceFee;
  }

  double _getWalletAmountToUseForOrder() {
    final totalBeforeWallet = _calculateTotalBeforeWallet();
    if (!_useWalletBalance ||
        _walletBalance <= 0 ||
        _currentUserProfile == null) return 0.0;
    double amountToUse = min(totalBeforeWallet, _walletBalance);
    return amountToUse > 0 ? amountToUse : 0.0;
  }

  double _calculateGrandTotalForDisplay() {
    final totalBeforeWallet = _calculateTotalBeforeWallet();
    final walletDeduction = _getWalletAmountToUseForOrder();
    final finalAmount = totalBeforeWallet - walletDeduction;
    return finalAmount > 0 ? finalAmount : 0.0;
  }

  void _handleApplyPromoCodeButton() {
    HapticFeedback.lightImpact();
    final code = _promoCodeController.text.trim().toUpperCase();
    FocusScope.of(context).unfocus();

    if (code.isEmpty) {
      _showFeedbackSnackbar('Please enter a promo code.',
          isError: true, context: context);
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
      setState(() {
        _appliedUIPromotion = validPromotionsForUI[code];
      });
      _showFeedbackSnackbar(
          'Promo code "$code" applied for estimation! Final validation by server.',
          isSuccess: true,
          context: context);
    } else {
      setState(() {
        _appliedUIPromotion = null;
      });
      _showFeedbackSnackbar(
          '"$code" will be attempted. Actual discount applied by server.',
          isError: false,
          context: context);
    }
  }

  Future<void> _handlePlaceOrder() async {
    if (_selectedDeliveryAddress == null) {
      _showFeedbackSnackbar("Please select a delivery address.",
          isError: true, context: context);
      return;
    }
    if (_orderItems.isEmpty) {
      _showFeedbackSnackbar("Please add at least one item to your order.",
          isError: true, context: context);
      return;
    }
    if (!_isSelfRecipient &&
        !(_recipientFormKey.currentState?.validate() ?? false)) {
      _showFeedbackSnackbar(
          'Please provide valid recipient details if not for self.',
          isError: true,
          context: context);
      return;
    }
    final String? currentActiveCustomerId =
        widget.customerId ?? _currentUserProfile?.id;
    if (currentActiveCustomerId == null || currentActiveCustomerId.isEmpty) {
      _showFeedbackSnackbar("User not identified. Please re-login.",
          isError: true, context: context);
      return;
    }

    setState(() => _isPlacingOrder = true);

    final List<Map<String, dynamic>> orderItemsPayload =
        _orderItems.map((item) {
      return {
        'cylinderId': item.cylinder.id,
        'productName': item.cylinder.sizeLabel,
        'quantity': item.quantity,
        'unitPrice': item.cylinder.price,
      };
    }).toList();

    String recipientNameValue;
    String recipientPhoneValue;

    if (_isSelfRecipient) {
      recipientNameValue = _currentUserProfile?.name ?? 'Self User';
      recipientPhoneValue = _currentUserProfile?.phone ?? '';
      if (recipientPhoneValue.isEmpty && mounted) {
        _showFeedbackSnackbar(
            "Your phone number is missing. Please update your profile.",
            isError: true,
            context: context);
        setState(() => _isPlacingOrder = false);
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
      /*if (_promoCodeController.text.trim().isNotEmpty)
        'promoCodeApplied': _promoCodeController.text.trim().toUpperCase(),
      if (_referralCodeController.text.trim().isNotEmpty)
        'referralCode': _referralCodeController.text.trim().toUpperCase(),*/
    };

    try {
      final PlaceOrderResponseModel response =
          await _apiService.placeOrder(orderPayloadForApi);

      if (!mounted) return;

      if (response.paymentNeeded) {
        _showFeedbackSnackbar("Order confirmed. Proceeding to payment...",
            isError: false);

        // This now correctly navigates to your Monnify PaymentScreen
        Navigator.of(context).pushReplacementNamed(
          PaymentScreen.routeName,
          arguments: {
            'orderId': response.order.id,
            'amount': response.grandTotalToPay,
            'customer': _currentUserProfile!, // Pass the full customer object
            'itemDescription':
                '${_orderItems.length} cylinder(s) - Order #${response.order.id.substring(response.order.id.length - 6)}',
          },
        );
      } else {
        _showFeedbackSnackbar(
            response.message.isNotEmpty
                ? response.message
                : "Order placed successfully!",
            isError: false,
            context: context);
        Navigator.of(context).pushNamedAndRemoveUntil(
          OrderSummaryScreen.routeName,
          ModalRoute.withName(CustomerDashboardScreen.routeName),
          arguments: {
            'orderId': response.order.id,
            'showConfirmation': true,
            'orderPayload': response.order,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(
            "Order placement failed: ${e.toString().replaceFirst("Exception: ", "")}",
            isError: true,
            context: context);
      }
    } finally {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appBarTitle = widget.isRefill ? 'Refill Your Gas' : 'Place New Order';
    final double currentGrandTotalDisplay = _calculateGrandTotalForDisplay();

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
          onPressed: () => Navigator.of(context).pop(),
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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            // ### ADDED NEW WIDGET ###
                            SlideTransition(
                                position: _sectionSlideAnimations[5],
                                child: _buildReferralCodeCard(themeProvider)),
                            const SizedBox(height: 24),
                            if (_currentUserProfile != null &&
                                _walletBalance > 0 &&
                                _orderItems.isNotEmpty)
                              SlideTransition(
                                  position: _sectionSlideAnimations[6],
                                  child: _buildWalletUsageCard(themeProvider)),
                            if (_currentUserProfile != null &&
                                _walletBalance > 0 &&
                                _orderItems.isNotEmpty)
                              const SizedBox(height: 24),
                            if (_orderItems.isNotEmpty && _feeSettings != null)
                              SlideTransition(
                                  position: _sectionSlideAnimations[7],
                                  child: _buildOrderSummaryCard(themeProvider)),
                            const SizedBox(height: 32),
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
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: CustomButton(
                text: _isPlacingOrder
                    ? 'Placing Order...'
                    : 'Proceed to Checkout (₦${NumberFormat("#,##0.00").format(currentGrandTotalDisplay / 100)})',
                onPressed: (_isPlacingOrder ||
                        _isLoadingAddress ||
                        _orderItems.isEmpty ||
                        _selectedDeliveryAddress == null)
                    ? null
                    : _handlePlaceOrder,
                color: themeProvider.gas2doorPrimaryBlue,
                height: 52,
                borderRadius: themeProvider.cardBorderRadiusValue,
                elevation: 2,
                icon: _isPlacingOrder
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                themeProvider.infoColorOnDarkBgs ??
                                    Colors.white)))
                    : Icon(Icons.payment_rounded,
                        color: themeProvider.infoColorOnDarkBgs ?? Colors.white,
                        size: 22),
                textStyle: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.infoColorOnDarkBgs ?? Colors.white),
              ),
            ),
    );
  }

  // ### ADD THIS NEW WIDGET METHOD ###
  Widget _buildReferralCodeCard(ThemeProvider themeProvider) {
    return CustomCard(
      color: themeProvider.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Have a Referral Code?',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            CustomInput(
              controller: _referralCodeController,
              hintText: 'Enter friend\'s code',
              labelText: 'Referral Code (Optional)',
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.group_add_outlined,
            ),
          ],
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
                                color: themeProvider.gas2doorPrimaryBlue,
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
            if (_isLoadingInitialData && _availableCylindersFromConfig.isEmpty)
              _buildSkeletonLine(
                  height: 100,
                  width: double.infinity,
                  themeProvider: themeProvider)
            else if (_availableCylindersFromConfig.isEmpty &&
                !_isLoadingInitialData)
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
                  final currentOrderItem = _orderItems.firstWhere(
                      (item) => item.cylinder.id == cylinder.id,
                      orElse: () => OrderItem(cylinder: cylinder, quantity: 0));
                  final int currentQuantityInOrder = currentOrderItem.quantity;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(cylinder.icon,
                            color: themeProvider.gas2doorPrimaryBlue, size: 32),
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
                                  '₦${NumberFormat("#,##0.00").format(cylinder.price / 100)}',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: themeProvider.secondaryText)),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                              color: themeProvider.appSecondaryBackground
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: Icon(
                                      Icons.remove_circle_outline_rounded,
                                      size: 20,
                                      color: currentQuantityInOrder > 0
                                          ? themeProvider.errorColor
                                              .withOpacity(0.8)
                                          : themeProvider.secondaryText
                                              .withOpacity(0.5)),
                                  onPressed: currentQuantityInOrder > 0
                                      ? () =>
                                          _updateOrderItemQuantity(cylinder, -1)
                                      : null,
                                  splashRadius: 18,
                                  visualDensity: VisualDensity.compact),
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: Text('$currentQuantityInOrder',
                                      style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: themeProvider.primaryText))),
                              IconButton(
                                  icon: Icon(Icons.add_circle_outline_rounded,
                                      size: 20,
                                      color: themeProvider.gas2doorPrimaryBlue),
                                  onPressed: (currentQuantityInOrder < 5)
                                      ? () =>
                                          _updateOrderItemQuantity(cylinder, 1)
                                      : null,
                                  splashRadius: 18,
                                  visualDensity: VisualDensity.compact),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
                separatorBuilder: (context, index) => Divider(
                    color: themeProvider.tertiaryText.withOpacity(0.1),
                    height: 1),
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
                onChanged: (bool value) => setState(() {
                  _isSelfRecipient = value;
                  if (value) {
                    _recipientNameController.clear();
                    _recipientPhoneController.clear();
                  } else {
                    _recipientNameController.text =
                        _currentUserProfile?.name ?? '';
                    _recipientPhoneController.text =
                        _currentUserProfile?.phone ?? '';
                  }
                }),
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
                                !RegExp(r'^\+?[0-9]{10,15}$')
                                    .hasMatch(val.trim()))
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
                  '+ ₦${NumberFormat("#,##0.00").format((_feeSettings?.expressDeliverySurcharge ?? 0) / 100)} (Get it faster!)',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: themeProvider.secondaryText)),
              value: _isExpressDelivery,
              onChanged: (value) => setState(() => _isExpressDelivery = value),
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
                        onFieldSubmitted: (_) =>
                            _handleApplyPromoCodeButton())),
                const SizedBox(width: 10),
                CustomButton(
                    text: 'Apply',
                    onPressed: _handleApplyPromoCodeButton,
                    color: themeProvider.gas2doorTeal,
                    height: 50,
                    textStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
            if (_appliedUIPromotion != null &&
                _appliedUIPromotion!.code.isNotEmpty) ...[
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
    if (_isLoadingInitialData || _currentUserProfile == null) {
      return _buildSkeletonLine(
          height: 60, width: double.infinity, themeProvider: themeProvider);
    }

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
              'Available: ₦${NumberFormat("#,##0.00").format(_walletBalance / 100)}',
              style: GoogleFonts.inter(
                  color: themeProvider.secondaryText, fontSize: 13)),
          value: _useWalletBalance,
          onChanged: _walletBalance <= 0
              ? null
              : (bool value) => setState(() => _useWalletBalance = value),
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

  Widget _buildOrderSummaryCard(ThemeProvider themeProvider) {
    final itemsSubtotal = _calculateItemsSubtotal();
    final deliveryFee = _calculateDeliveryFee();
    final serviceFee = _calculateServiceFee(itemsSubtotal);
    final vat = _calculateVat(itemsSubtotal);
    final uiDiscount =
        (_appliedUIPromotion != null && _appliedUIPromotion!.code.isNotEmpty)
            ? (_appliedUIPromotion!.fixedDiscountAmount > 0
                ? _appliedUIPromotion!.fixedDiscountAmount * 100
                : itemsSubtotal * _appliedUIPromotion!.discountPercentage)
            : 0.0;

    final walletUsed = _getWalletAmountToUseForOrder();
    final grandTotal = _calculateGrandTotalForDisplay();
    final currencyFormat =
        NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

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
            _buildSummaryRow('Items Subtotal:',
                currencyFormat.format(itemsSubtotal / 100), themeProvider),
            if (_feeSettings != null && _feeSettings!.vatPercentage > 0)
              _buildSummaryRow(
                  'VAT (${_feeSettings!.vatPercentage.toStringAsFixed(1)}%):',
                  '+ ${currencyFormat.format(vat / 100)}',
                  themeProvider),
            if (_feeSettings != null && _feeSettings!.serviceFeePercentage > 0)
              _buildSummaryRow(
                  'Service Fee (${_feeSettings!.serviceFeePercentage.toStringAsFixed(0)}%):',
                  '+ ${currencyFormat.format(serviceFee / 100)}',
                  themeProvider),
            _buildSummaryRow('Delivery Fee:',
                '+ ${currencyFormat.format(deliveryFee / 100)}', themeProvider),
            if (_appliedUIPromotion != null &&
                _appliedUIPromotion!.code.isNotEmpty)
              _buildSummaryRow(
                  'Est. Discount ("${_appliedUIPromotion!.code}"):',
                  '- ${currencyFormat.format(uiDiscount / 100)}',
                  themeProvider,
                  isDiscount: true),
            if (_useWalletBalance && walletUsed > 0)
              _buildSummaryRow('Wallet Deduction:',
                  '- ${currencyFormat.format(walletUsed / 100)}', themeProvider,
                  isDiscount: true),
            Divider(
                height: 24,
                thickness: 0.5,
                color: themeProvider.tertiaryText.withOpacity(0.4)),
            _buildSummaryRow('Total Payable:',
                currencyFormat.format(grandTotal / 100), themeProvider,
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
                  fontSize: isTotal ? 16.5 : 14.5,
                  color: isDiscount
                      ? themeProvider.successColor
                      : themeProvider.primaryText,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSkeletonLine(
      {required double height,
      required double width,
      required ThemeProvider themeProvider,
      double borderRadius = 4.0}) {
    return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? Colors.grey[700]!.withOpacity(0.6)
                : Colors.grey[300]!,
            borderRadius: BorderRadius.circular(borderRadius)));
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
                onPressed: _initializeScreenData,
                color: themeProvider.gas2doorPrimaryBlue,
                icon: Icon(Icons.refresh_rounded, color: Colors.white))
          ],
        ),
      ),
    );
  }

  void _showFeedbackSnackbar(String message,
      {required BuildContext context,
      bool isError = false,
      bool isSuccess = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    Color backgroundColor = themeProvider.successColor.withOpacity(0.95);
    if (isError) {
      backgroundColor = themeProvider.errorColor;
    } else if (!isSuccess) {
      backgroundColor = themeProvider.gas2doorPrimaryBlue.withOpacity(0.9);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 6,
      ),
    );
  }
}
