// File: lib/screens/auth/customer_register_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../services/auth_service.dart'; // Using the refactored AuthService
import '../../models/registration_response_model.dart'; // Assuming your RegistrationResponseModel is here
import './customer_login_screen.dart'; // For navigation
import './otp_verification_screen.dart'; // Import the new OTP screen

class CustomerRegisterScreen extends StatefulWidget {
  static const String routeName = '/customer_register';
  const CustomerRegisterScreen({super.key});

  @override
  State<CustomerRegisterScreen> createState() => _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState extends State<CustomerRegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

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
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController,
                curve: Curves.fastEaseInToSlowEaseOut));
    _slideAnimationForm =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
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
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor:
            isError ? themeProvider.errorColor : themeProvider.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      // Assuming registerCustomer returns an instance of RegistrationResponseModel
      final RegistrationResponseModel response =
          await _authService.registerCustomer(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      // Accessing the 'message' property directly from the model
      _showFeedbackSnackbar(response.message ??
          'Registration Successful! Please check your email for an OTP.');

      Navigator.of(context).pushReplacementNamed(
        OtpVerificationScreen.routeName,
        arguments: {'email': _emailController.text.trim()},
      );
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final String appLogoPath = isDark
        ? 'assets/images/gas2door_logo_dark.png'
        : 'assets/images/gas2door_logo_light.png';

    return Scaffold(
      backgroundColor: themeProvider.appPrimaryBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              appLogoPath,
              height: 28,
              errorBuilder: (ctx, err, st) => Icon(
                  Icons.local_fire_department_rounded,
                  size: 28,
                  color: themeProvider.gas2doorPrimaryBlue),
            ),
            const SizedBox(width: 8),
            Text('Create Customer Account',
                style: GoogleFonts.inter(
                    color: themeProvider.gas2doorPrimaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                SlideTransition(
                  position: _slideAnimationHeader,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text('Join Gas2Door',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.primaryText)),
                        const SizedBox(height: 10),
                        Text('Quickly set up your account to start ordering.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                color: themeProvider.secondaryText)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                SlideTransition(
                  position: _slideAnimationForm,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        CustomInput(
                          controller: _nameController,
                          labelText: 'Full Name*',
                          hintText: 'Enter your full name',
                          prefixIcon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Name is required'
                                  : (value.trim().length < 2
                                      ? 'Name too short'
                                      : null),
                        ),
                        const SizedBox(height: 18),
                        CustomInput(
                          controller: _emailController,
                          labelText: 'Email Address*',
                          hintText: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty)
                              return 'Email is required';
                            if (!RegExp(
                                    r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                                .hasMatch(value.trim()))
                              return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        CustomInput(
                          controller: _phoneController,
                          labelText: 'Phone Number*',
                          hintText: 'Enter your phone number',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty)
                              return 'Phone number is required';
                            if (!RegExp(r'^\+?[0-9]{10,15}$')
                                .hasMatch(value.trim()))
                              return 'Enter a valid phone number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        CustomInput(
                          controller: _passwordController,
                          labelText: 'Password*',
                          hintText: 'Create a secure password (min. 6 chars)',
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
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Password is required';
                            if (value.length < 6)
                              return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        CustomInput(
                          controller: _confirmPasswordController,
                          labelText: 'Confirm Password*',
                          hintText: 'Re-enter your password',
                          obscureText: _obscureConfirmPassword,
                          prefixIcon: Icons.lock_person_outlined,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted:
                              _isLoading ? null : (_) => _handleRegister(),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: themeProvider.secondaryText
                                    .withOpacity(0.7)),
                            onPressed: () => setState(() =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please confirm password';
                            if (value != _passwordController.text)
                              return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        CustomButton(
                          text: _isLoading
                              ? 'Creating Account...'
                              : 'Create Account',
                          onPressed: _isLoading ? null : _handleRegister,
                          color: themeProvider.gas2doorPrimaryBlue,
                          textStyle: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.infoColorOnDarkBgs),
                          height: 52,
                          borderRadius: themeProvider.cardBorderRadiusValue,
                          icon: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          themeProvider.infoColorOnDarkBgs ??
                                              Colors.white)))
                              : Icon(Icons.person_add_alt_1_rounded,
                                  color: themeProvider.infoColorOnDarkBgs,
                                  size: 22),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                SlideTransition(
                  position: _slideAnimationFooter,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: "Already have an account? ",
                      style: GoogleFonts.inter(
                          color: themeProvider.secondaryText, fontSize: 15),
                      children: <TextSpan>[
                        TextSpan(
                          text: 'Login',
                          style: GoogleFonts.inter(
                              color: themeProvider.gas2doorPrimaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              HapticFeedback.lightImpact();
                              Navigator.pushReplacementNamed(
                                  context, CustomerLoginScreen.routeName);
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
