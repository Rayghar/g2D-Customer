// File: lib/screens/auth/forgot_password_screen.dart
// ADVISORY: Updated with the new glassy, light theme.

import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../services/auth_service.dart';
import './reset_password_screen.dart';
import '../../widgets/curve_painter.dart'; // ADDED: Import the new CurvePainter file

enum ForgotPasswordStage {
  enterEmail,
  enterToken,
}

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
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;

  ForgotPasswordStage _currentStage = ForgotPasswordStage.enterEmail;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestCode() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final String email = _emailController.text.trim();
      final result = await _authService.requestPasswordReset(email);
      if (mounted) {
        _showFeedbackSnackbar(result ?? 'A reset code has been sent.',
            isSuccess: true);
        setState(() {
          _currentStage = ForgotPasswordStage.enterToken;
          _animationController.forward(from: 0.0);
        });
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyToken() async {
    if (_tokenController.text.length < 6) {
      _showFeedbackSnackbar('Please enter the 6-digit code.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final String email = _emailController.text.trim();
      final String token = _tokenController.text.trim();
      final result = await _authService.verifyPasswordResetToken(
        email: email,
        token: token,
      );
      print('Verify Token Result: $result'); // Debug log
      if (mounted) {
        _showFeedbackSnackbar(
            result['message'] ?? 'Code verified successfully.',
            isSuccess: true);
        if (result['resetToken'] == null) {
          _showFeedbackSnackbar(
              'Reset token missing from response. Please try again or request a new code.',
              isError: true);
          return;
        }
        Navigator.of(context).pushReplacementNamed(
          ResetPasswordScreen.routeName,
          arguments: {'resetToken': result['resetToken']},
        );
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        borderSide: BorderSide(
            color: Colors.black.withOpacity(0.8), width: 2), // MODIFIED
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: themeProvider.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: themeProvider.errorColor, width: 2),
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
          onPressed: () {
            if (_currentStage == ForgotPasswordStage.enterToken) {
              setState(() {
                _currentStage = ForgotPasswordStage.enterEmail;
                _tokenController.clear();
                _animationController.forward(from: 0.0);
              });
            } else {
              Navigator.of(context).pop();
            }
          },
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
                  painter: CurvePainter(),
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25), // MODIFIED
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.6)),
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
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                              opacity: animation, child: child);
                        },
                        child: _currentStage == ForgotPasswordStage.enterEmail
                            ? _buildEmailEntry(themeProvider,
                                inputDecorationThemeForScreen) // MODIFIED
                            : _buildTokenEntry(themeProvider),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailEntry(ThemeProvider themeProvider,
      InputDecorationTheme inputDecorationThemeForScreen) {
    return Column(
      key: const ValueKey('email_stage'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Forgot Password?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87)), // MODIFIED: Text color
        const SizedBox(height: 12),
        Text('Enter your email to receive a 6-digit verification code.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 15, color: Colors.black54)), // MODIFIED: Text color
        const SizedBox(height: 30),
        Theme(
          data: Theme.of(context)
              .copyWith(inputDecorationTheme: inputDecorationThemeForScreen),
          child: TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined)),
            style: GoogleFonts.inter(
                color: Colors.black87), // MODIFIED: Text color
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: _isLoading ? null : (_) => _handleRequestCode(),
            validator: (value) {
              if (value == null || value.trim().isEmpty)
                return 'Please enter your email';
              if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                  .hasMatch(value.trim())) return 'Enter a valid email address';
              return null;
            },
          ),
        ),
        const SizedBox(height: 32),
        CustomButton(
          text: _isLoading ? 'Sending...' : 'Send Code',
          onPressed: _isLoading ? null : _handleRequestCode,
          color: themeProvider.primaryActionColor,
          height: 52,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Icon(Icons.send_to_mobile_rounded,
                  color: Colors.white, size: 20),
        ),
      ],
    );
  }

  Widget _buildTokenEntry(ThemeProvider themeProvider) {
    // MODIFIED: Pinput theme for light background
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: GoogleFonts.inter(
          fontSize: 22,
          color: Colors.black87, // MODIFIED
          fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4), // MODIFIED
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.2)), // MODIFIED
      ),
    );

    return Column(
      key: const ValueKey('token_stage'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Check Your Email',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87)), // MODIFIED
        const SizedBox(height: 12),
        Text('We sent a 6-digit code to\n${_emailController.text}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.black54, // MODIFIED
                height: 1.5)),
        const SizedBox(height: 30),
        Pinput(
          length: 6,
          controller: _tokenController,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: defaultPinTheme.copyWith(
              decoration: defaultPinTheme.decoration!.copyWith(
                  border: Border.all(
                      color: Colors.black.withOpacity(0.8), // MODIFIED
                      width: 2))),
          submittedPinTheme: defaultPinTheme.copyWith(
              decoration: defaultPinTheme.decoration!.copyWith(
                  border: Border.all(color: themeProvider.successColor))),
          onCompleted: (pin) => _handleVerifyToken(),
          hapticFeedbackType: HapticFeedbackType.lightImpact,
        ),
        const SizedBox(height: 32),
        CustomButton(
          text: _isLoading ? 'Verifying...' : 'Verify Code',
          onPressed: _isLoading ? null : _handleVerifyToken,
          color: themeProvider.primaryActionColor,
          height: 52,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 22),
        ),
      ],
    );
  }
}
