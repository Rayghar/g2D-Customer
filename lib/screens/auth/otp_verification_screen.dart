// File: lib/screens/auth/otp_verification_screen.dart
// ADVISORY: This is the complete, reimagined version with the "Depth & Clarity" theme.

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../services/auth_service.dart';
import './customer_login_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  static const String routeName = '/verify_otp';
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

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

  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.length < 4) {
      _showFeedbackSnackbar('Please enter the 4-digit code.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await _authService.verifyOtp(
          email: widget.email, otp: _otpController.text);
      if (!mounted) return;
      _showFeedbackSnackbar(response['message'] ?? 'Verification successful!');
      Navigator.of(context).pushNamedAndRemoveUntil(
          CustomerLoginScreen.routeName, (route) => false,
          arguments: {'email': widget.email});
    } catch (e) {
      if (mounted)
        _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // NEW: Pinput theme designed for our "Depth & Clarity" UI
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 64,
      textStyle: GoogleFonts.inter(
          fontSize: 24,
          color: themeProvider.textOnDarkGradient,
          fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: themeProvider.inputFieldFillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.inputFieldBorderColor),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(Icons.mark_email_read_outlined,
                              size: 60, color: themeProvider.gas2doorTeal),
                          const SizedBox(height: 24),
                          Text(
                            'Enter Verification Code',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.textOnDarkGradient,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'A 4-digit code was sent to\n${widget.email}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: themeProvider.textOnDarkGradient
                                  .withOpacity(0.8),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Pinput(
                            length: 4,
                            controller: _otpController,
                            defaultPinTheme: defaultPinTheme,
                            focusedPinTheme: defaultPinTheme.copyWith(
                                decoration: defaultPinTheme.decoration!
                                    .copyWith(
                                        border: Border.all(
                                            color: themeProvider
                                                .inputFieldFocusedBorderColor,
                                            width: 2))),
                            submittedPinTheme: defaultPinTheme.copyWith(
                                decoration: defaultPinTheme.decoration!
                                    .copyWith(
                                        border: Border.all(
                                            color:
                                                themeProvider.successColor))),
                            onCompleted: (pin) => _handleVerifyOtp(),
                            hapticFeedbackType: HapticFeedbackType.lightImpact,
                          ),
                          const SizedBox(height: 32),
                          CustomButton(
                            text: _isLoading
                                ? 'Verifying...'
                                : 'Verify & Continue',
                            onPressed: _isLoading ? null : _handleVerifyOtp,
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
                                : const Icon(Icons.check_circle_outline_rounded,
                                    color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
