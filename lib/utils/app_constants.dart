// lib/utils/app_constants.dart
import 'package:flutter/material.dart';

/// Contains durations used for animations throughout the app.
class AppDurations {
  static const screenEntryAnimation = Duration(milliseconds: 700);
  static const carouselAnimation = Duration(milliseconds: 700);
  static const animationSmall =
      Duration(milliseconds: 200); // For item quantity
}

/// Stores constants related to the API, such as fixed query parameters.
class ApiConstants {
  static const activeOrderStatuses =
      'Pending Payment,Order Placed,Processing,Driver Assigned,Out for delivery,Driver enroute to pickup,Driver enroute to gas station,Cylinder Refilling';
}

/// A centralized place for string constants related to business logic.
class LogicStrings {
  static const statusDelivered = 'delivered';
  static const paymentStatusPending = 'pending payment';
}

/// Constants specific to order related calculations and logic.
class OrderConstants {
  static const double perAdditionalCylinderSurcharge =
      1500.0; // Assuming it's in actual currency (Naira) now, not kobo as in prev thought.
  static const int maxCylinderQuantity = 5;
  static const String defaultCurrencyLocale = 'en_NG';
  static const String defaultCurrencySymbol = '₦';

  // Promo codes (for UI estimation logic)
  static const String promoCodeGas2Door20 = 'GAS2DOOR20';
  static const String promoCodeFreeDel = 'FREEDEL';
}

/// Holds user-facing strings for the UI.
class AppStrings {
  // General
  static const appName = 'PrimeJet Mobile';
  static const retry = 'Retry';
  static const viewAll = 'View All';
  static const change = 'Change';
  static const select = 'Select';
  static const apply = 'Apply';
  static const proceedToCheckout = 'Proceed to Checkout';
  static const placingOrder = 'Placing Order...';
  static const errorLoadingData = 'Error Loading Data';
  static const noAvailableCylinders =
      'No gas cylinders available at the moment.';

  // Home Screen
  static const greeting = 'Hi,';
  static const newOrder = 'New Order';
  static const myOrders = 'My Orders';
  static const trackActiveOrder = 'Track Active Order';
  static const dontMissThese = 'Don\'t Miss These!';
  static const orderHistory = 'Order History';
  static const reorder = 'Reorder';
  static const totalOrders = 'Total Orders';
  static const noRecentOrders = 'No recent orders to show here.';
  static const failedToLoadData = 'Failed to load data. Please try again.';

  // Address Bar
  static const deliveringTo = 'Delivering to:';
  static const tapToSelectAddress = 'Tap to select address';

  // Order Placement Screen
  static const refillYourGas = 'Refill Your Gas';
  static const placeNewOrder = 'Place New Order';
  static const deliveryAddressTitle = '1. Delivery Address';
  static const selectAddressPlaceholder = 'Please select an address';
  static const chooseGasTitle = '2. Choose Your Gas';
  static const itemRemoved = ' removed from order.';
  static const itemAdded = ' added to order.';
  static const recipientInfoTitle = '3. Recipient Information';
  static const selfReceiveOrder = 'I will receive this order myself';
  static const recipientFullName = 'Recipient\'s Full Name*';
  static const enterFullName = 'Enter full name';
  static const recipientPhoneNumber = 'Recipient\'s Phone Number*';
  static const enterContactNumber = 'Enter contact number';
  static const recipientNameRequired = 'Recipient name is required';
  static const validPhoneNumberRequired = 'Enter a valid phone number';
  static const deliverySpeedTitle = '4. Delivery Speed';
  static const expressDelivery = 'Express Delivery';
  static const expressDeliverySurchargeHint =
      '(Get it faster!)'; // '+ {amount} (Get it faster!)'
  static const applyPromotionTitle = '5. Apply Promotion';
  static const enterPromoCode = 'Enter Promo Code';
  static const promoCodeOptional = 'Promo Code (Optional)';
  static const enterPromoCodeSnackbar = 'Please enter a promo code.';
  static const promoCodeAppliedSnackbar =
      'Promo code "%s" applied for estimation!'; // Use %s for placeholder
  static const promoCodeServerAttemptSnackbar =
      '"%s" will be attempted. Actual discount applied by server.'; // Use %s for placeholder
  static const useWalletBalance = 'Use Wallet Balance';
  static const walletAvailable = 'Available:'; // 'Available: {amount}'
  static const orderSummaryTitle = 'Order Summary';
  static const itemsSubtotal = 'Items Subtotal:';
  static const vat = 'VAT:';
  static const serviceFee = 'Service Fee:';
  static const deliveryFee = 'Delivery Fee:';
  static const discount = 'Discount:';
  static const walletDeduction = 'Wallet Deduction:';
  static const totalPayable = 'Total Payable:';

  // Error/Feedback Messages
  static const userNotIdentified = 'User not identified. Please login again.';
  static const userInformationMissing = 'User information missing.';
  static const deliveryAddressUpdated = 'Delivery address updated.';
  static const pleaseSelectAddress = 'Please select a delivery address.';
  static const pleaseAddOrderItem =
      'Please add at least one item to your order.';
  static const provideValidRecipientDetails =
      'Please provide valid recipient details.';
  static const userReLoginRequired = 'User not identified. Please re-login.';
  static const phoneNumberMissing =
      'Your phone number is missing. Please update your profile.';
  static const orderConfirmedProceedToPayment =
      'Order confirmed. Proceeding to payment...';
  static const orderPlacedSuccessfully = 'Order placed successfully!';
  static const orderPlacementFailed =
      'Order placement failed:'; // '%s' for error message
}

/// Defines standard dimensions like padding, spacing, and font sizes.
class AppDimens {
  static const double spacingExtraSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingExtraLarge = 32.0; // for icons like cylinder

  static const double paddingCard = 16.0;
  static const double paddingScreenBottom = 120.0;
  static const double paddingBottomBarVertical = 12.0;
  static const double paddingBottomBarHorizontal = 16.0;
  static const double paddingBottomBarBottom = 24.0;
  static const double paddingListItemVertical = 8.0;
  static const double paddingListItemHorizontal = 12.0;
  static const double paddingVerticalSection = 10.0;
  static const double paddingErrorState = 20.0;
  static const double paddingSummaryRow = 6.0;

  static const double heightButton = 52.0;
  static const double heightInput =
      50.0; // For "Apply" button height to match input
  static const double heightCircularProgress = 20.0;
  static const double widthCircularProgress = 20.0;
  static const double strokeWidthCircularProgress = 2.5;
  static const double iconSizeSmall = 18.0;
  static const double iconSizeMedium = 22.0;
  static const double iconSizeLarge = 26.0;
  static const double iconSizeExtraLarge = 32.0;
  static const double iconSizeError = 60.0;

  static const double borderRadiusSmall = 10.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 20.0;

  static const double elevationAppBar = 1.0;
  static const double snackbarElevation = 6.0;
  static const double dividerThickness = 0.5;

  static const double fontTitle = 26.0;
  static const double fontSubtitle = 18.0;
  static const double fontBody = 15.0;
  static const double fontBodySmall = 14.5;
  static const double fontCaption = 13.0;
  static const double fontSmall = 14.0;
  static const double fontTotal = 17.0; // for total payable
  static const double fontSectionTitle = 16.0; // for section titles
  static const double fontAppBarTitle = 18.0; // for appbar title
  static const double fontSummaryHeading = 18.0; // for order summary heading

  static const double opacityLow = 0.05;
  static const double opacityMedium = 0.3;
  static const double opacityHigh = 0.7;
  static const double opacityVeryHigh = 0.95;

  static const double borderWidthMedium = 1.5;
  static const double borderWidthThin = 1.0;
}

/// Regex patterns used throughout the app.
class RegexConstants {
  static final RegExp nigerianPhoneNumber = RegExp(r'^\+?\d{10,15}$');
}
