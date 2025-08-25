// File: lib/screens/auth/customer_register_screen.dart
// ADVISORY: Updated with the new glassy, light theme.

import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../services/auth_service.dart';
import '../../models/registration_response_model.dart';
import './customer_login_screen.dart';
import './otp_verification_screen.dart';
import '../../services/agent_referral_handler.dart';
import '../../widgets/curve_painter.dart'; // ADDED: Import the new CurvePainter file
import '../../widgets/curve_painter.dart'; // ADDED: Import the new CurvePainter file

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
  final TextEditingController _referralCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();

    final String? capturedAgentCode = AgentReferralHandler.getAgentCode();
    if (capturedAgentCode != null) {
      _referralCodeController.text = capturedAgentCode;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _fadeController.dispose();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
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
      final RegistrationResponseModel response =
          await _authService.registerCustomer(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        referralCode: _referralCodeController.text.trim(),
      );

      AgentReferralHandler.clearAgentCode();

      if (!mounted) return;
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

    // MODIFIED: Updated input decoration for light theme
    final inputDecorationThemeForScreen = InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.4),
      hintStyle: GoogleFonts.inter(color: Colors.black.withOpacity(0.5)),
      labelStyle: GoogleFonts.inter(color: Colors.black87),
      prefixIconColor: Colors.black54,
      suffixIconColor: Colors.black54,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.8), width: 2),
      ),
    );

    // MODIFIED: Replaced Container with Stack for the new background
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black54), // MODIFIED: Icon color
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.grey.shade200, // Light gray background
          ),
          Positioned(
            top: -MediaQuery.of(context).size.height * 0.3,
            left: -MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.2,
              height: MediaQuery.of(context).size.height * 0.8,
              child: Transform.rotate(
                angle: -0.2,
                child: CustomPaint(
                  size: Size(MediaQuery.of(context).size.width * 1.2,
                      MediaQuery.of(context).size.height * 0.8),
                  //painter: CurvePainter(),
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25), // MODIFIED
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.6)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Create Account',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87, // MODIFIED
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Quickly set up your account to start ordering.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: Colors.black54, // MODIFIED
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Theme(
                                  data: Theme.of(context).copyWith(
                                      inputDecorationTheme:
                                          inputDecorationThemeForScreen),
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _nameController,
                                        decoration: const InputDecoration(
                                            labelText: 'Full Name*',
                                            prefixIcon: Icon(
                                                Icons.person_outline_rounded)),
                                        style: GoogleFonts.inter(
                                            color: Colors.black87), // MODIFIED
                                        textInputAction: TextInputAction.next,
                                        validator: (value) => (value == null ||
                                                value.trim().isEmpty)
                                            ? 'Name is required'
                                            : (value.trim().length < 2
                                                ? 'Name too short'
                                                : null),
                                      ),
                                      const SizedBox(height: 18),
                                      TextFormField(
                                        controller: _emailController,
                                        decoration: const InputDecoration(
                                            labelText: 'Email Address*',
                                            prefixIcon:
                                                Icon(Icons.email_outlined)),
                                        style: GoogleFonts.inter(
                                            color: Colors.black87), // MODIFIED
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty)
                                            return 'Email is required';
                                          if (!RegExp(
                                                  r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                                              .hasMatch(value.trim()))
                                            return 'Enter a valid email';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                      TextFormField(
                                        controller: _phoneController,
                                        decoration: const InputDecoration(
                                            labelText: 'Phone Number*',
                                            prefixIcon:
                                                Icon(Icons.phone_outlined)),
                                        style: GoogleFonts.inter(
                                            color: Colors.black87), // MODIFIED
                                        keyboardType: TextInputType.phone,
                                        textInputAction: TextInputAction.next,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty)
                                            return 'Phone number is required';
                                          if (!RegExp(r'^\+?[0-9]{10,15}$')
                                              .hasMatch(value.trim()))
                                            return 'Enter a valid phone number';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          labelText: 'Password*',
                                          prefixIcon: const Icon(
                                              Icons.lock_outline_rounded),
                                          suffixIcon: IconButton(
                                            icon: Icon(_obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined),
                                            onPressed: () => setState(() =>
                                                _obscurePassword =
                                                    !_obscurePassword),
                                          ),
                                        ),
                                        style: GoogleFonts.inter(
                                            color: Colors.black87), // MODIFIED
                                        textInputAction: TextInputAction.next,
                                        validator: (value) {
                                          if (value == null || value.isEmpty)
                                            return 'Password is required';
                                          if (value.length < 6)
                                            return 'Password must be at least 6 characters';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        obscureText: _obscureConfirmPassword,
                                        decoration: InputDecoration(
                                          labelText: 'Confirm Password*',
                                          prefixIcon: const Icon(
                                              Icons.lock_person_outlined),
                                          suffixIcon: IconButton(
                                            icon: Icon(_obscureConfirmPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined),
                                            onPressed: () => setState(() =>
                                                _obscureConfirmPassword =
                                                    !_obscureConfirmPassword),
                                          ),
                                        ),
                                        style: GoogleFonts.inter(
                                            color: Colors.black87), // MODIFIED
                                        textInputAction: TextInputAction.next,
                                        validator: (value) {
                                          if (value == null || value.isEmpty)
                                            return 'Please confirm password';
                                          if (value != _passwordController.text)
                                            return 'Passwords do not match';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                      TextFormField(
                                        controller: _referralCodeController,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Referral Code (Optional)',
                                            prefixIcon: Icon(
                                                Icons.card_giftcard_outlined)),
                                        style: GoogleFonts.inter(
                                            color: Colors.black87), // MODIFIED
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: _isLoading
                                            ? null
                                            : (_) => _handleRegister(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                CustomButton(
                                  text: _isLoading
                                      ? 'Creating Account...'
                                      : 'Create Account',
                                  onPressed:
                                      _isLoading ? null : _handleRegister,
                                  color: themeProvider.primaryActionColor,
                                  height: 52,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white)))
                                      : const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          color: Colors.white,
                                          size: 22),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: "Already have an account? ",
                        style: GoogleFonts.inter(
                            color: Colors.black87.withOpacity(0.8),
                            fontSize: 15), // MODIFIED
                        children: <TextSpan>[
                          TextSpan(
                            text: 'Login',
                            style: GoogleFonts.inter(
                                color: themeProvider.linkColor,
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
