// File: lib/screens/driver/driver_register_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../services/auth_service.dart';
import './driver_login_screen.dart';
import '../../models/registration_response_model.dart'; // For typed response

class DriverRegisterScreen extends StatefulWidget {
  static const String routeName = '/driver_register';
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final TextEditingController _bankCodeController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();

  final TextEditingController _vehicleTypeController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimationHeader;
  late Animation<Offset> _slideAnimationForm;
  late Animation<Offset> _slideAnimationFooter;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnimationHeader =
        Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController,
                curve: Curves.fastEaseInToSlowEaseOut));
    _slideAnimationForm =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController,
                curve: Curves.fastEaseInToSlowEaseOut));
    _slideAnimationFooter = _slideAnimationForm;
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleTypeController.dispose();
    _licensePlateController.dispose();
    _bankCodeController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleDriverRegister() async {
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) {
      _showFeedbackSnackbar('Please correct all errors in the form.',
          isError: true);
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final bankDetails = {
        "bankCode": _bankCodeController.text.trim(),
        "accountNumber": _accountNumberController.text.trim(),
        "accountName": _accountNameController.text.trim(),
      };

      final RegistrationResponseModel response =
          await _authService.registerDriver(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        bankDetails: bankDetails,
        // Vehicle type and license plate are optional for UI but not sent in this core registration API call
      );

      if (!mounted) return;
      _showFeedbackSnackbar(response.message.isNotEmpty
          ? response.message
          : 'Driver registration application submitted! You will be notified upon approval.');
      Navigator.of(context).pushNamedAndRemoveUntil(
          DriverLoginScreen.routeName, (route) => false);
    } catch (e) {
      if (!mounted) return;
      _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    final String appLogoPath = themeProvider.isDarkMode
        ? 'assets/images/gas2door_logo.png'
        : 'assets/images/gas2door_logo.png';
    final Color driverAccentColor = themeProvider.gas2doorTeal;

    return Scaffold(
      backgroundColor: themeProvider.appPrimaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.appPrimaryBackground,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              appLogoPath,
              height: 28,
              color: driverAccentColor,
              errorBuilder: (ctx, err, st) => Icon(Icons.local_shipping_rounded,
                  size: 28, color: driverAccentColor),
            ),
            const SizedBox(width: 8),
            Text('Become a Driver',
                style: GoogleFonts.inter(
                    color: driverAccentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ],
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: themeProvider.primaryText),
                onPressed: () => Navigator.of(context).pop())
            : null,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                SlideTransition(
                  position: _slideAnimationHeader,
                  child: Column(
                    children: [
                      Icon(Icons.drive_eta_outlined,
                          size: 50, color: driverAccentColor),
                      const SizedBox(height: 12),
                      Text('Join Our Delivery Team',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.primaryText)),
                      const SizedBox(height: 8),
                      Text(
                          'Fill in your details to start delivering with Gas2Door.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              color: themeProvider.secondaryText)),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                SlideTransition(
                  position: _slideAnimationForm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomInput(
                          controller: _nameController,
                          labelText: 'Full Name*',
                          hintText: 'Enter your full name',
                          prefixIcon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (val) =>
                              (val == null || val.trim().isEmpty)
                                  ? 'Full name is required'
                                  : null),
                      const SizedBox(height: 18),
                      CustomInput(
                          controller: _emailController,
                          labelText: 'Email Address*',
                          hintText: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (val) => (val == null ||
                                  val.trim().isEmpty)
                              ? 'Email is required'
                              : (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                                      .hasMatch(val.trim())
                                  ? 'Enter a valid email'
                                  : null)),
                      const SizedBox(height: 18),
                      CustomInput(
                          controller: _phoneController,
                          labelText: 'Phone Number*',
                          hintText: 'Enter your phone number',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (val) =>
                              (val == null || val.trim().isEmpty)
                                  ? 'Phone number is required'
                                  : (!RegExp(r'^\+?[0-9]{10,15}$')
                                          .hasMatch(val.trim())
                                      ? 'Enter a valid phone number'
                                      : null)),
                      const SizedBox(height: 18),
                      CustomInput(
                          controller: _passwordController,
                          labelText: 'Create Password*',
                          hintText: 'Minimum 6 characters',
                          obscureText: _obscurePassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          textInputAction: TextInputAction.next,
                          suffixIcon: IconButton(
                              icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: themeProvider.secondaryText
                                      .withOpacity(0.7)),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword)),
                          validator: (val) => (val == null || val.isEmpty)
                              ? 'Password is required'
                              : (val.length < 6 ? 'Password too short' : null)),
                      const SizedBox(height: 18),
                      CustomInput(
                          controller: _confirmPasswordController,
                          labelText: 'Confirm Password*',
                          hintText: 'Re-enter your password',
                          obscureText: _obscureConfirmPassword,
                          prefixIcon: Icons.lock_person_outlined,
                          textInputAction: TextInputAction.next,
                          suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: themeProvider.secondaryText
                                      .withOpacity(0.7)),
                              onPressed: () => setState(() =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword)),
                          validator: (val) => (val == null || val.isEmpty)
                              ? 'Please confirm password'
                              : (val != _passwordController.text
                                  ? 'Passwords do not match'
                                  : null)),
                      Padding(
                        padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                        child: Text(
                            "Bank Account Details (Required for Payouts)",
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: themeProvider.primaryText)),
                      ),
                      CustomInput(
                          controller: _accountNameController,
                          labelText: 'Account Holder Name*',
                          hintText: 'As registered with bank',
                          prefixIcon: Icons.badge_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (val) =>
                              (val == null || val.trim().isEmpty)
                                  ? 'Account name is required'
                                  : null),
                      const SizedBox(height: 18),
                      CustomInput(
                          controller: _accountNumberController,
                          labelText: 'Account Number*',
                          hintText: 'NUBAN account number',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.confirmation_number_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (val) => (val == null ||
                                  val.trim().isEmpty)
                              ? 'Account number is required'
                              : (!RegExp(r'^[0-9]{10}$').hasMatch(val.trim())
                                  ? 'Enter a valid 10-digit NUBAN'
                                  : null)),
                      const SizedBox(height: 18),
                      CustomInput(
                          controller: _bankCodeController,
                          labelText: 'Bank Code*',
                          hintText: 'E.g., 044 for Access, 058 for GTB',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.account_balance_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (val) =>
                              (val == null || val.trim().isEmpty)
                                  ? 'Bank code is required'
                                  : null),
                      const SizedBox(height: 24),
                      Text("Optional Vehicle Information",
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: themeProvider.secondaryText)),
                      const SizedBox(height: 12),
                      CustomInput(
                          controller: _vehicleTypeController,
                          labelText: 'Vehicle Type',
                          hintText: 'e.g., Motorcycle, Van',
                          prefixIcon: Icons.two_wheeler_outlined,
                          textInputAction: TextInputAction.next),
                      const SizedBox(height: 18),
                      CustomInput(
                          controller: _licensePlateController,
                          labelText: 'License Plate',
                          hintText: 'e.g., ABC-123XY',
                          prefixIcon: Icons.pin_outlined,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: _isLoading
                              ? null
                              : (_) => _handleDriverRegister()),
                      const SizedBox(height: 32),
                      CustomButton(
                        text: _isLoading
                            ? 'Submitting Application...'
                            : 'Register as Driver',
                        onPressed: _isLoading ? null : _handleDriverRegister,
                        color: driverAccentColor,
                        textStyle: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        height: 52,
                        borderRadius: themeProvider.cardBorderRadiusValue,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white)))
                            : const Icon(Icons.app_registration_rounded,
                                color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                SlideTransition(
                  position: _slideAnimationFooter,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: "Already a registered driver? ",
                      style: GoogleFonts.inter(
                          color: themeProvider.secondaryText, fontSize: 15),
                      children: <TextSpan>[
                        TextSpan(
                          text: 'Login Here',
                          style: GoogleFonts.inter(
                              color: driverAccentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              HapticFeedback.lightImpact();
                              Navigator.pushReplacementNamed(
                                  context, DriverLoginScreen.routeName);
                            },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
