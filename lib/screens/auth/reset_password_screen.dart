// File: lib/screens/auth/reset_password_screen.dart
// ADVISORY: Updated to retrieve resetToken in didChangeDependencies and fix debug log.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import './customer_login_screen.dart';
import '../../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  static const String routeName = '/reset_password';

  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _resetToken; // Managed as state variable

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final AuthService _authService = AuthService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Retrieve resetToken from navigation arguments after context is ready
    final arguments =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    _resetToken = arguments?['resetToken'] as String?;
    print(
        'ResetPasswordScreen initialized with resetToken: $_resetToken'); // Fixed debug log
    if (_resetToken == null || _resetToken!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showFeedbackSnackbar(
              'Invalid or missing reset token. Please try again or request a new one.',
              isError: true);
        }
      });
    }
  }

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
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    HapticFeedback.mediumImpact();
    if (_formKey.currentState!.validate()) {
      if (_resetToken == null || _resetToken!.isEmpty) {
        _showFeedbackSnackbar(
            'Invalid or missing reset token. Please try again or request a new one.',
            isError: true);
        return;
      }
      setState(() => _isLoading = true);

      try {
        print('Sending reset request with token: $_resetToken'); // Debug log
        await _authService.resetPassword(
            _resetToken!, _newPasswordController.text);
        if (mounted) {
          _showFeedbackSnackbar('Password updated successfully! Please log in.',
              isError: false, isSuccess: true);
          Navigator.pushNamedAndRemoveUntil(
              context, CustomerLoginScreen.routeName, (route) => false);
        }
      } catch (e) {
        if (mounted) {
          _showFeedbackSnackbar(e.toString().replaceFirst('Exception: ', ''),
              isError: true);
          print('Reset Password Error: $e'); // Debug log
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      HapticFeedback.heavyImpact();
      _showFeedbackSnackbar('Please correct the errors in the form.',
          isError: true);
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
      suffixIconColor: themeProvider.textOnDarkGradient.withOpacity(0.6),
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
                                'Create New Password',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.textOnDarkGradient,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Your new password must be different from previous ones.',
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
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _newPasswordController,
                                      obscureText: _obscureNewPassword,
                                      decoration: InputDecoration(
                                        labelText: 'New Password',
                                        prefixIcon: const Icon(
                                            Icons.lock_outline_rounded),
                                        suffixIcon: IconButton(
                                          icon: Icon(_obscureNewPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined),
                                          onPressed: () => setState(() =>
                                              _obscureNewPassword =
                                                  !_obscureNewPassword),
                                        ),
                                      ),
                                      style: GoogleFonts.inter(
                                          color:
                                              themeProvider.textOnDarkGradient),
                                      textInputAction: TextInputAction.next,
                                      validator: (value) {
                                        if (value == null || value.isEmpty)
                                          return 'Please enter a new password';
                                        if (value.length < 6)
                                          return 'Password must be at least 6 characters';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      decoration: InputDecoration(
                                        labelText: 'Confirm New Password',
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
                                          color:
                                              themeProvider.textOnDarkGradient),
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) =>
                                          _handleResetPassword(),
                                      validator: (value) {
                                        if (value == null || value.isEmpty)
                                          return 'Please confirm your new password';
                                        if (value !=
                                            _newPasswordController.text)
                                          return 'Passwords do not match';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              CustomButton(
                                text: _isLoading
                                    ? 'Updating...'
                                    : 'Update Password',
                                onPressed:
                                    _isLoading ? null : _handleResetPassword,
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
                                        Icons.check_circle_outline_rounded,
                                        color: Colors.white,
                                        size: 22),
                              ),
                            ],
                          ),
                        ),
                      ),
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
