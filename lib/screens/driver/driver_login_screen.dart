// File: lib/screens/driver/driver_login_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart'; // Your CustomButton
import '../../widgets/input.dart'; // Your CustomInput
// import './driver_dashboard_screen.dart'; // For DriverDashboardScreen.routeName
// import '../auth/forgot_password_screen.dart'; // For ForgotPasswordScreen.routeName
// import './driver_register_screen.dart'; // For DriverRegisterScreen.routeName (if exists)

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
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // String emailOrPhone = _emailController.text.trim();
      // String password = _passwordController.text;

      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      // TODO: Implement actual login logic using your userService
      // try {
      //   final response = await yourAuthService.login(
      //     emailOrPhone: emailOrPhone,
      //     password: password,
      //     role: 'driver'
      //   );
      //   // Store token, user data (specifically for driver role), navigate to driver dashboard
      //   if (mounted) {
      //     _showFeedbackSnackbar('Login Successful! Welcome Driver.', context, isError: false);
      //     Navigator.pushNamedAndRemoveUntil(context, '/driver_dashboard', (route) => false);
      //   }
      // } catch (e) {
      //   if (mounted) {
      //     _showFeedbackSnackbar('Login Failed: ${e.toString()}', context, isError: true);
      //   }
      // }

      // Placeholder logic:
      if (_emailController.text == "driver@example.com" &&
          _passwordController.text == "password") {
        if (mounted) {
          _showFeedbackSnackbar('Login Successful! Welcome Driver.', context,
              isError: false);
          Navigator.pushNamedAndRemoveUntil(
              context, '/driver_dashboard', (route) => false);
        }
      } else {
        if (mounted) {
          _showFeedbackSnackbar(
              'Login Failed: Invalid driver credentials.', context,
              isError: true);
        }
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } else {
      HapticFeedback.heavyImpact();
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
                  Icons.local_shipping_rounded,
                  color: themeProvider.gas2doorTeal,
                  size: 28),
            ),
            const SizedBox(width: 8),
            Text(
              'Driver Portal',
              style: GoogleFonts.inter(
                color: themeProvider
                    .gas2doorTeal, // Using Teal for Driver theme accent
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
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                SlideTransition(
                  position: _slideAnimationHeader,
                  child: Column(
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 60, color: themeProvider.gas2doorTeal),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome Back, Driver!',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Log in to manage your deliveries.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: themeProvider.secondaryText,
                        ),
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
                        controller: _emailController,
                        labelText: 'Email or Phone',
                        hintText: 'Enter your driver email or phone',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email or phone';
                          }
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
                            color: themeProvider.secondaryText.withOpacity(0.7),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pushNamed(context, '/forgot_password');
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 0),
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.inter(
                              color: themeProvider
                                  .gas2doorTeal, // Driver theme accent
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      CustomButton(
                        text: _isLoading ? 'Logging In...' : 'Login',
                        onPressed: _isLoading ? null : _handleLogin,
                        color:
                            themeProvider.gas2doorTeal, // Driver theme accent
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
                            : Icon(Icons.login_rounded,
                                color: themeProvider.infoColorOnDarkBgs,
                                size: 22),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                SlideTransition(
                  position: _slideAnimationFooter,
                  child: RichText(
                    // Placeholder if driver self-registration is an option
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: "Not a registered driver? ",
                      style: GoogleFonts.inter(
                        color: themeProvider.secondaryText,
                        fontSize: 15,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: 'Apply Here', // Or "Register"
                          style: GoogleFonts.inter(
                            color: themeProvider.gas2doorTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              HapticFeedback.lightImpact();
                              // TODO: Navigate to Driver Registration Screen if it exists
                              Navigator.pushNamed(context,
                                  '/driver_register'); // Placeholder for now
                              _showFeedbackSnackbar(
                                  "Driver registration coming soon!", context);
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
