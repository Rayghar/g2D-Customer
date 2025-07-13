// File: lib/screens/auth/otp_verification_screen.dart

import 'dart:async';
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
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 64,
      textStyle: GoogleFonts.inter(
          fontSize: 24,
          color: themeProvider.primaryText,
          fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: themeProvider.appSecondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.tertiaryText.withOpacity(0.5)),
      ),
    );

    return Scaffold(
      backgroundColor: themeProvider.appPrimaryBackground,
      appBar: AppBar(
        title: Text('Verify Your Email',
            style: GoogleFonts.inter(color: themeProvider.primaryText)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Icon(Icons.mark_email_read_outlined,
                  size: 80, color: themeProvider.gas2doorPrimaryBlue),
              const SizedBox(height: 30),
              Text('Enter Verification Code',
                  style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.primaryText)),
              const SizedBox(height: 12),
              Text('A 4-digit code was sent to\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      color: themeProvider.secondaryText,
                      height: 1.5)),
              const SizedBox(height: 40),
              Pinput(
                length: 4,
                controller: _otpController,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                        border: Border.all(
                            color: themeProvider.gas2doorPrimaryBlue,
                            width: 2))),
                submittedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                        color: themeProvider.successColor.withOpacity(0.1),
                        border: Border.all(color: themeProvider.successColor))),
                onCompleted: (pin) => _handleVerifyOtp(),
                hapticFeedbackType: HapticFeedbackType.lightImpact,
              ),
              const SizedBox(height: 40),
              CustomButton(
                text: _isLoading ? 'Verifying...' : 'Verify & Continue',
                onPressed: _isLoading ? null : _handleVerifyOtp,
                color: themeProvider.gas2doorPrimaryBlue,
                height: 52,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
