// File: lib/screens/auth/driver_login_screen.dart
// (Or lib/screens/driver/driver_login_screen.dart based on your project structure)

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../services/auth_service.dart'; // Using the refactored AuthService
import '../driver/driver_dashboard_screen.dart'; // For navigation
import './forgot_password_screen.dart';
import './driver_register_screen.dart';
import '../../models/auth_response_model.dart'; // For LoginSuccessData

class DriverLoginScreen extends StatefulWidget {
  static const String routeName = '/driver_login';
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen>
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
  late Animation<Offset> _slideAnimationFooter;

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
      // **INTEGRATION POINT**: Call the AuthService for driver login
      final LoginSuccessData loginData = await _authService.loginDriver(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        // AuthService's loginDriver method handles role verification ("driver") and token storage.
        _showFeedbackSnackbar(
            'Driver Login Successful! Welcome, ${loginData.name}.');
        Navigator.pushNamedAndRemoveUntil(
            context, DriverDashboardScreen.routeName, (route) => false);
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
        ? 'assets/images/gas2door_logo_dark.png'
        : 'assets/images/gas2door_logo_light.png';
    final Color driverAccentColor = themeProvider.gas2doorTeal;

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
              color: driverAccentColor,
              errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.local_shipping_rounded,
                  color: driverAccentColor,
                  size: 28),
            ),
            const SizedBox(width: 8),
            Text('Driver Portal',
                style: GoogleFonts.inter(
                    color: driverAccentColor,
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
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                SlideTransition(
                  position: _slideAnimationHeader,
                  child: Column(
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 60, color: driverAccentColor),
                      const SizedBox(height: 16),
                      Text('Welcome Back, Driver!',
                          style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.primaryText)),
                      const SizedBox(height: 8),
                      Text('Log in to manage your deliveries and availability.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              color: themeProvider.secondaryText)),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                SlideTransition(
                  position: _slideAnimationForm,
                  child: Column(
                    children: [
                      CustomInput(
                        controller: _emailController,
                        labelText: 'Email or Driver ID',
                        hintText: 'Enter your registered email or ID',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.person_pin_circle_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Please enter your email or Driver ID';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      CustomInput(
                        controller: _passwordController,
                        labelText: 'Password',
                        hintText: 'Enter your password',
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
                                  color: driverAccentColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 28),
                      CustomButton(
                        text: _isLoading ? 'Logging In...' : 'Login',
                        onPressed: _isLoading ? null : _handleLogin,
                        color: driverAccentColor,
                        textStyle: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors
                                .white), // Assuming white text for teal button
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
                            : const Icon(Icons.login_rounded,
                                color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                SlideTransition(
                  position: _slideAnimationFooter,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: "Not a registered driver? ",
                      style: GoogleFonts.inter(
                          color: themeProvider.secondaryText, fontSize: 15),
                      children: <TextSpan>[
                        TextSpan(
                          text: 'Apply Here',
                          style: GoogleFonts.inter(
                              color: driverAccentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              HapticFeedback.lightImpact();
                              Navigator.pushNamed(
                                  context, DriverRegisterScreen.routeName);
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
