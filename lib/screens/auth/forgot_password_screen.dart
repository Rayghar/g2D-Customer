// File: lib/screens/auth/forgot_password_screen.dart
// ADVISORY: This is the complete, reimagined version with the "Depth & Clarity" theme.

import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const String routeName = '/forgot_password';
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _feedbackMessage;
  bool _isError = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fadeController.dispose();
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
      final String email = _emailController.text.trim();
      final String message = await _authService.requestPasswordReset(email);

      if (!mounted) return;
      setState(() {
        _feedbackMessage = message;
        _isError = false;
      });
      _showFeedbackSnackbar(message, isSuccess: true);
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

  void _showFeedbackSnackbar(String message,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError
            ? themeProvider.errorColor
            : (isSuccess
                ? themeProvider.successColor
                : themeProvider.gas2doorPrimaryBlue),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final inputDecorationThemeForScreen = InputDecorationTheme(
      filled: true,
      fillColor: themeProvider.inputFieldFillColor,
      hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.5)),
      labelStyle: GoogleFonts.inter(
          color: themeProvider.textOnDarkGradient.withOpacity(0.8)),
      prefixIconColor: themeProvider.textOnDarkGradient.withOpacity(0.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: themeProvider.inputFieldBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: themeProvider.inputFieldBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: themeProvider.inputFieldFocusedBorderColor, width: 2),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.textOnDarkGradient),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              themeProvider.loginScreenGradientStart,
              themeProvider.loginScreenGradientEnd,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
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
                          color: themeProvider.formCardBackground,
                          borderRadius: BorderRadius.circular(24),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Forgot Password?',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.textOnDarkGradient,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Enter your email and we will send instructions to reset your password.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: themeProvider.textOnDarkGradient
                                      .withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 30),
                              Theme(
                                data: Theme.of(context).copyWith(
                                    inputDecorationTheme:
                                        inputDecorationThemeForScreen),
                                child: TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  style: GoogleFonts.inter(
                                      color: themeProvider.textOnDarkGradient),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: _isLoading
                                      ? null
                                      : (_) => _handleForgotPassword(),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty)
                                      return 'Please enter your email';
                                    if (!RegExp(
                                            r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                                        .hasMatch(value.trim()))
                                      return 'Enter a valid email address';
                                    return null;
                                  },
                                ),
                              ),
                              if (_feedbackMessage != null &&
                                  _feedbackMessage!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
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
                              const SizedBox(height: 32),
                              CustomButton(
                                text: _isLoading
                                    ? 'Sending...'
                                    : 'Send Reset Instructions',
                                onPressed:
                                    _isLoading ? null : _handleForgotPassword,
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
                                    : const Icon(Icons.send_to_mobile_rounded,
                                        color: Colors.white, size: 20),
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
                      text: "Remembered your password? ",
                      style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.8), fontSize: 15),
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
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
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
      ),
    );
  }
}
