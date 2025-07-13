// File: lib/screens/auth/reset_password_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart'; // Your CustomButton
import '../../widgets/input.dart'; // Your CustomInput
// import './customer_login_screen.dart'; // For CustomerLoginScreen.routeName

class ResetPasswordScreen extends StatefulWidget {
  static const String routeName = '/reset_password';
  final String?
      resetToken; // Optionally passed if deep linking or OTP screen precedes this

  const ResetPasswordScreen({
    super.key,
    this.resetToken, // Token might come from previous screen or deep link
  });

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

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimationHeader;
  late Animation<Offset> _slideAnimationForm;
  // late Animation<Offset> _slideAnimationFooter; // No footer link in this version

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

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _slideController.forward();
    });

    // If a token is passed, you might want to validate it here or assume it's valid
    // For example: if (widget.resetToken == null) { /* Navigate back or show error */ }
    print("Received reset token (if any): ${widget.resetToken}");
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    HapticFeedback.mediumImpact();
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // String newPassword = _newPasswordController.text;
      // String? token = widget.resetToken; // Use the token passed to the screen

      // if (token == null) {
      //   _showFeedbackSnackbar('Error: Reset token is missing.', context, isError: true);
      //   setState(() => _isLoading = false);
      //   return;
      // }

      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      // TODO: Implement actual API call to your userService /api/users/reset-password
      // try {
      //   final response = await yourAuthService.resetPassword(
      //     resetToken: token,
      //     newPassword: newPassword,
      //   );
      //   if (mounted) {
      //    _showFeedbackSnackbar('Password updated successfully! Please login.', context, isError: false);
      //     Navigator.pushNamedAndRemoveUntil(context, '/customer_login', (route) => false);
      //   }
      // } catch (e) {
      //   if (mounted) {
      //     _showFeedbackSnackbar('Failed to update password: ${e.toString()}', context, isError: true);
      //   }
      // }

      // Placeholder logic:
      if (mounted) {
        _showFeedbackSnackbar(
            'Password updated successfully! Please login.', context,
            isError: false);
        Navigator.pushNamedAndRemoveUntil(
            context, '/customer_login', (route) => false);
      }

      // No need to set _isLoading to false if navigating away, but good practice if staying on screen
      // if (mounted) {
      //   setState(() => _isLoading = false);
      // }
    } else {
      HapticFeedback.heavyImpact();
      _showFeedbackSnackbar('Please correct the errors in the form.', context,
          isError: true);
    }
  }

  void _showFeedbackSnackbar(String message, BuildContext ctx,
      {bool isError = false}) {
    final themeProvider = Provider.of<ThemeProvider>(ctx, listen: false);
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError
            ? themeProvider.errorColor
            : themeProvider.successColor.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String appLogoPath = 'assets/images/gas2door_logo.png';

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
              errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.local_fire_department_rounded,
                  color: themeProvider.gas2doorPrimaryBlue,
                  size: 28),
            ),
            const SizedBox(width: 8),
            Text(
              'Set New Password',
              style: GoogleFonts.inter(
                color: themeProvider.gas2doorPrimaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: themeProvider.primaryText),
                onPressed: () => Navigator.of(context).pop(),
              )
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
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                SlideTransition(
                  position: _slideAnimationHeader,
                  child: Column(
                    children: [
                      Text(
                        'Create Your New Password',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.primaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Please enter a new password for your account. Make sure it\'s strong and memorable.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: themeProvider.secondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.06),
                SlideTransition(
                  position: _slideAnimationForm,
                  child: Column(
                    children: [
                      // Optional: OTP/Token field if needed
                      // CustomInput(
                      //   labelText: 'Verification Code',
                      //   hintText: 'Enter the code from your email/SMS',
                      //   keyboardType: TextInputType.number,
                      //   prefixIcon: Icons.shield_check_outlined,
                      //   validator: (value) { /* ... */ },
                      // ),
                      // const SizedBox(height: 18),
                      CustomInput(
                        controller: _newPasswordController,
                        labelText: 'New Password',
                        hintText: 'Enter your new password',
                        obscureText: _obscureNewPassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        textInputAction: TextInputAction.next,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: themeProvider.secondaryText.withOpacity(0.7),
                          ),
                          onPressed: () => setState(
                              () => _obscureNewPassword = !_obscureNewPassword),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a new password';
                          }
                          if (value.length < 8) {
                            // Example: Enforce minimum length
                            return 'Password must be at least 8 characters';
                          }
                          // TODO: Add more password strength validation (e.g., uppercase, number, special char)
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      CustomInput(
                        controller: _confirmPasswordController,
                        labelText: 'Confirm New Password',
                        hintText: 'Re-enter your new password',
                        obscureText: _obscureConfirmPassword,
                        prefixIcon: Icons.lock_person_outlined,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted:
                            _isLoading ? null : (_) => _handleResetPassword(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: themeProvider.secondaryText.withOpacity(0.7),
                          ),
                          onPressed: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your new password';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      CustomButton(
                        text: _isLoading
                            ? 'Updating Password...'
                            : 'Update Password',
                        onPressed: _isLoading ? null : _handleResetPassword,
                        color: themeProvider.gas2doorPrimaryBlue,
                        textStyle: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.infoColorOnDarkBgs),
                        height: 52,
                        borderRadius: themeProvider.cardBorderRadiusValue,
                        elevation: 3,
                        icon: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        themeProvider.infoColorOnDarkBgs)))
                            : Icon(Icons.check_circle_outline_rounded,
                                color: themeProvider.infoColorOnDarkBgs,
                                size: 22),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                    height: MediaQuery.of(context).size.height *
                        0.05), // Bottom spacing
                // No "Remembered Password? Login" link here, as user is already in reset flow.
                // They will be navigated to login on success.
              ],
            ),
          ),
        ),
      ),
    );
  }
}
