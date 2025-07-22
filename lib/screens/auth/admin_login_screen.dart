// File: lib/screens/auth/admin_login_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../services/auth_service.dart'; // Using the refactored AuthService
import '../admin/admin_dashboard_screen.dart'; // For navigation
import './forgot_password_screen.dart'; // Assuming shared forgot password

class AdminLoginScreen extends StatefulWidget {
  static const String routeName = '/admin_login';
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimationHeader;
  late Animation<Offset> _slideAnimationForm;

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
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) {
      _showFeedbackSnackbar('Please correct the errors in the form.',
          isError: true);
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      // **INTEGRATION POINT**: Call the refactored AuthService for admin login
      final loginData = await _authService.loginAdmin(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        // AuthService's loginAdmin method now handles role verification and token storage.
        _showFeedbackSnackbar(
            'Admin Login Successful! Welcome, ${loginData.name}.');
        Navigator.pushNamedAndRemoveUntil(
            context, AdminDashboardScreen.routeName, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
            isError: true);
      }
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
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String appLogoPath = themeProvider.isDarkMode
        ? 'assets/images/gas2door_logo.png'
        : 'assets/images/gas2door_logo.png'; // Assuming you have these assets
    final Color adminAccentColor = themeProvider.gas2doorPurple;

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
              color: adminAccentColor,
              errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.admin_panel_settings_rounded,
                  color: adminAccentColor,
                  size: 28),
            ),
            const SizedBox(width: 8),
            Text('Admin Portal',
                style: GoogleFonts.inter(
                    color: adminAccentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
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
                      Icon(Icons.admin_panel_settings_outlined,
                          size: 60, color: adminAccentColor),
                      const SizedBox(height: 16),
                      Text('Administrator Access',
                          style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.primaryText)),
                      const SizedBox(height: 8),
                      Text('Log in to manage platform operations.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              color: themeProvider.secondaryText)),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.06),
                SlideTransition(
                  position: _slideAnimationForm,
                  child: Column(
                    children: [
                      CustomInput(
                        controller: _emailController,
                        labelText: 'Admin Email or ID',
                        hintText: 'Enter your administrator email or ID',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.shield_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Please enter your email or Admin ID';
                          if (!value.trim().contains('@') &&
                              value.trim().length < 3)
                            return 'Enter a valid email or ID'; // Simple check
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      CustomInput(
                        controller: _passwordController,
                        labelText: 'Password',
                        hintText: 'Enter your admin password',
                        obscureText: _obscurePassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted:
                            _isLoading ? null : (_) => _handleLogin(),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color:
                                  themeProvider.secondaryText.withOpacity(0.7)),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Please enter your password'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pushNamed(
                                context, ForgotPasswordScreen.routeName);
                          },
                          child: Text('Forgot Password?',
                              style: GoogleFonts.inter(
                                  color: adminAccentColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 28),
                      CustomButton(
                        text: _isLoading ? 'Signing In...' : 'Admin Login',
                        onPressed: _isLoading ? null : _handleLogin,
                        color: adminAccentColor,
                        textStyle: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.infoColorOnDarkBgs ??
                                Colors.white),
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
                            : Icon(Icons.security_rounded,
                                color: themeProvider.infoColorOnDarkBgs ??
                                    Colors.white,
                                size: 22),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                // No "Register" link for admin login screen generally
              ],
            ),
          ),
        ),
      ),
    );
  }
}
