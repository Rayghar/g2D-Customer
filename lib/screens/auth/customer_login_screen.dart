// File: lib/screens/auth/customer_login_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'complete_profile_screen.dart'; // Import the new screen
import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../services/auth_service.dart'; // Using the refactored AuthService
import '../customer/customer_dashboard_screen.dart';
import './forgot_password_screen.dart';
import './customer_register_screen.dart';
import '../../models/auth_response_model.dart';
// For LoginSuccessData

class CustomerLoginScreen extends StatefulWidget {
  static const String routeName = '/customer_login';
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen>
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
        vsync: this, duration: const Duration(milliseconds: 700));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnimationHeader =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController,
                curve: Curves.fastEaseInToSlowEaseOut));
    _slideAnimationForm =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController,
                curve: Curves.fastEaseInToSlowEaseOut));
    _slideAnimationFooter = _slideAnimationForm;
    _fadeController.forward();
    _slideController.forward();

    // Check if email was passed from OTP screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (arguments != null && arguments.containsKey('email')) {
        _emailController.text = arguments['email'];
      }
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final LoginSuccessData loginData = await _authService.loginCustomer(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      // ========================== FIX IS HERE ==========================
      // Check the flag from the backend response.
      if (loginData.isNewUser) {
        // If it's a new user, navigate to the complete profile screen.
        _showFeedbackSnackbar('Welcome! Please complete your profile.');
        Navigator.of(context).pushNamedAndRemoveUntil(
            CompleteProfileScreen.routeName, (route) => false,
            arguments: {'userName': loginData.name});
      } else {
        // If it's an existing user, go directly to the dashboard.
        _showFeedbackSnackbar(
            'Google Sign-In successful! Welcome back, ${loginData.name}.');
        Navigator.of(context).pushNamedAndRemoveUntil(
            CustomerDashboardScreen.routeName, (route) => false);
      }
      // ===============================================================
    } catch (e) {
      if (!mounted) return;
      _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
          isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      // Ensure user is signed out from any previous session to allow account picking
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // The user canceled the sign-in
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception("Could not retrieve Google ID token.");
      }

      // Send the token to your backend via the AuthService
      final LoginSuccessData loginData =
          await _authService.signInWithGoogle(idToken);

      if (!mounted) return;
      _showFeedbackSnackbar(
          'Google Sign-In successful! Welcome, ${loginData.name}.');
      Navigator.of(context).pushNamedAndRemoveUntil(
          CustomerDashboardScreen.routeName, (route) => false);
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
    final isDark = themeProvider.isDarkMode;
    final String appLogoPath = isDark
        ? 'assets/images/gas2door_logo_dark.png'
        : 'assets/images/gas2door_logo_light.png';

    return Scaffold(
      backgroundColor: themeProvider.appPrimaryBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: themeProvider.primaryText),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
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
              'Customer Login',
              style: GoogleFonts.inter(
                color: themeProvider.gas2doorPrimaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                SlideTransition(
                  position: _slideAnimationHeader,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'Welcome Back!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Login to continue your seamless gas delivery.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: themeProvider.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.06),
                SlideTransition(
                  position: _slideAnimationForm,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        CustomInput(
                          controller: _emailController,
                          labelText: 'Email Address',
                          hintText: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty)
                              return 'Please enter your email';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                .hasMatch(value.trim()))
                              return 'Enter a valid email address';
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
                                color: themeProvider.secondaryText
                                    .withOpacity(0.7)),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please enter your password';
                            if (value.length < 6)
                              return 'Password must be at least 6 characters';
                            return null;
                          },
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
                                    color: themeProvider.gas2doorPrimaryBlue,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        CustomButton(
                          text: _isLoading ? 'Logging In...' : 'Login Securely',
                          onPressed: _isLoading ? null : _handleLogin,
                          color: themeProvider.gas2doorPrimaryBlue,
                          textStyle: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.infoColorOnDarkBgs),
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
                              : Icon(Icons.login_rounded,
                                  color: themeProvider.infoColorOnDarkBgs,
                                  size: 22),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildSocialLoginDivider(themeProvider),
                const SizedBox(height: 24),
                _buildSocialLoginButtons(themeProvider),
                const SizedBox(height: 24),
                SlideTransition(
                  position: _slideAnimationFooter,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: GoogleFonts.inter(
                          color: themeProvider.secondaryText, fontSize: 15),
                      children: <TextSpan>[
                        TextSpan(
                          text: 'Register',
                          style: GoogleFonts.inter(
                              color: themeProvider.gas2doorPrimaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              HapticFeedback.lightImpact();
                              Navigator.pushNamed(
                                  context, CustomerRegisterScreen.routeName);
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

  Widget _buildSocialLoginDivider(ThemeProvider themeProvider) {
    return Row(children: [
      Expanded(
          child: Divider(color: themeProvider.tertiaryText.withOpacity(0.3))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text("OR LOGIN WITH",
            style: GoogleFonts.inter(
                fontSize: 12,
                color: themeProvider.secondaryText,
                fontWeight: FontWeight.w500)),
      ),
      Expanded(
          child: Divider(color: themeProvider.tertiaryText.withOpacity(0.3))),
    ]);
  }

  Widget _buildSocialLoginButtons(ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
            icon: Image.asset('assets/images/google_logo.png', height: 32),
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            tooltip: "Sign in with Google"),
        const SizedBox(width: 20),
        // IconButton(
        //   icon: Image.asset('assets/images/facebook_logo.png', height: 32),
        //   onPressed: () => _showFeedbackSnackbar(
        //      "Facebook Sign-In not implemented",
        //     isError: true),
        // tooltip: "Sign in with Facebook"),
        // const SizedBox(width: 20),
        //IconButton(
        //    icon: Image.asset('assets/images/x_logo.png',
        //       height: 32,
        //      //color: themeProvider.isDarkMode ? Colors.white : Colors.black),
        //   onPressed: () => _showFeedbackSnackbar("X Sign-In not implemented",
        //       isError: true),
        //  tooltip: "Sign in with X"),
      ],
    );
  }
}
