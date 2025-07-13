// File: lib/screens/auth/forgot_password_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../services/auth_service.dart'; // Using the refactored AuthService
// import './customer_login_screen.dart'; // Or a generic login selector

class ForgotPasswordScreen extends StatefulWidget {
  static const String routeName = '/forgot_password';
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  // Renamed from _emailOrPhoneController to be specific as backend expects email
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _feedbackMessage;
  bool _isError = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimationHeader;
  late Animation<Offset> _slideAnimationForm;
  late Animation<Offset> _slideAnimationFooter; // Added for consistency

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnimationHeader =
        Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController, curve: Curves.easeOutCubic));
    _slideAnimationForm =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController,
                curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic)));
    _slideAnimationFooter =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController,
                curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)));
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
      _isError = false;
    });

    try {
      // **INTEGRATION POINT**
      final String email = _emailController.text.trim();
      final String message = await _authService.requestPasswordReset(email);

      if (!mounted) return;
      setState(() {
        _feedbackMessage = message; // Display success message from backend
        _isError = false;
      });
      _showFeedbackSnackbar(message, isError: false);
      // UI can choose to navigate or just show the message.
      // For now, we just show the message.
      // User will check their email for further instructions (once backend TODOs are done).
    } catch (e) {
      if (!mounted) return;
      final String errorMessage = e.toString().replaceFirst("Exception: ", "");
      setState(() {
        _feedbackMessage = errorMessage;
        _isError = true;
      });
      _showFeedbackSnackbar(errorMessage, isError: true);
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
        ? 'assets/images/gas2door_logo_dark.png'
        : 'assets/images/gas2door_logo_light.png';

    return Scaffold(
      backgroundColor: themeProvider.appPrimaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.appPrimaryBackground,
        elevation: 0,
        title: Text('Reset Password',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                SlideTransition(
                  position: _slideAnimationHeader,
                  child: Column(
                    children: [
                      Image.asset(
                        appLogoPath,
                        height: 60,
                        errorBuilder: (ctx, err, st) => Icon(
                            Icons.lock_reset_rounded,
                            size: 60,
                            color: themeProvider.primaryText.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 20),
                      Text('Forgot Your Password?',
                          style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.primaryText)),
                      const SizedBox(height: 12),
                      Text(
                        'Enter your email address below and we will send you instructions to reset your password.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            color: themeProvider.secondaryText,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                SlideTransition(
                  position: _slideAnimationForm,
                  child: Column(
                    children: [
                      CustomInput(
                        controller:
                            _emailController, // Changed from _emailOrPhoneController
                        labelText: 'Email Address',
                        hintText: 'Enter your registered email',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted:
                            _isLoading ? null : (_) => _handleForgotPassword(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Please enter your email';
                          if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                              .hasMatch(value.trim()))
                            return 'Enter a valid email address';
                          return null;
                        },
                      ),
                      if (_feedbackMessage != null &&
                          _feedbackMessage!.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 16.0, bottom: 0.0),
                          child: Text(
                            _feedbackMessage!,
                            style: GoogleFonts.inter(
                                color: _isError
                                    ? themeProvider.errorColor
                                    : themeProvider.successColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 28),
                      CustomButton(
                        text: _isLoading
                            ? 'Sending...'
                            : 'Send Reset Instructions',
                        onPressed: _isLoading ? null : _handleForgotPassword,
                        color: themeProvider.gas2doorPrimaryBlue,
                        textStyle: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white), // Explicitly white
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
                            : const Icon(Icons.send_to_mobile_rounded,
                                color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                SlideTransition(
                  // Added slide animation for consistency
                  position: _slideAnimationFooter,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: "Remembered your password? ",
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
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                // Fallback if cannot pop, e.g., go to a generic login or customer login
                                Navigator.pushReplacementNamed(context,
                                    '/customer_login'); // Update if needed
                              }
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
