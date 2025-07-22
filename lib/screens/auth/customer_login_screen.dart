// File: lib/screens/auth/customer_login_screen.dart
// ADVISORY: This version includes the requested layout refinements.

import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'complete_profile_screen.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../customer/customer_dashboard_screen.dart';
import './forgot_password_screen.dart';
import './customer_register_screen.dart';
import '../../models/auth_response_model.dart';
import '../../widgets/button.dart';

class CustomerLoginScreen extends StatefulWidget {
  static const String routeName = '/customer_login';
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
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
    setState(() => _isLoading = true);
    try {
      final LoginSuccessData loginData = await _authService.loginCustomer(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (!mounted) return;
      if (loginData.isNewUser) {
        _showFeedbackSnackbar('Welcome! Please complete your profile.');
        Navigator.of(context).pushNamedAndRemoveUntil(
            CompleteProfileScreen.routeName, (route) => false,
            arguments: {'userName': loginData.name});
      } else {
        _showFeedbackSnackbar('Welcome back, ${loginData.name}!');
        Navigator.of(context).pushNamedAndRemoveUntil(
            CustomerDashboardScreen.routeName, (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception("Could not retrieve Google ID token.");
      }
      final LoginSuccessData loginData =
          await _authService.signInWithGoogle(idToken);
      if (!mounted) return;
      _showFeedbackSnackbar(
          'Google Sign-In successful! Welcome, ${loginData.name}.');
      Navigator.of(context).pushNamedAndRemoveUntil(
          CustomerDashboardScreen.routeName, (route) => false);
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: themeProvider.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: themeProvider.errorColor, width: 2),
      ),
    );

    return Scaffold(
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
                Image.asset(
                  'assets/images/gas2door_logo.png',
                  // MODIFIED: Logo height increased
                  height: 100,
                ),
                // MODIFIED: Spacing increased
                const SizedBox(height: 40),
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
                              'Welcome Back',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.textOnDarkGradient,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Login to access your account.',
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
                                    controller: _emailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Email Address',
                                      prefixIcon: Icon(Icons.email_outlined),
                                    ),
                                    style: GoogleFonts.inter(
                                        color:
                                            themeProvider.textOnDarkGradient),
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                          .hasMatch(value.trim())) {
                                        return 'Enter a valid email address';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(
                                          Icons.lock_outline_rounded),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                    style: GoogleFonts.inter(
                                        color:
                                            themeProvider.textOnDarkGradient),
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _handleLogin(),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context,
                                        ForgotPasswordScreen.routeName);
                                  },
                                  child: Text('Forgot Password?',
                                      style: GoogleFonts.inter(
                                          color: themeProvider.linkColor,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    themeProvider.primaryActionColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                textStyle: GoogleFonts.inter(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              icon: _isLoading
                                  ? Container()
                                  : const Icon(Icons.login_rounded, size: 22),
                              label: Text(
                                  _isLoading ? 'Signing In...' : 'Sign In'),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(
                                        color: Colors.white.withOpacity(0.2))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text("OR",
                                      style: GoogleFonts.inter(
                                          color:
                                              Colors.white.withOpacity(0.6))),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: Colors.white.withOpacity(0.2))),
                              ],
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed:
                                  _isLoading ? null : _handleGoogleSignIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                textStyle: GoogleFonts.inter(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              icon: Image.asset('assets/images/google_logo.png',
                                  height: 24),
                              label: const Text('Sign In with Google'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                RichText(
                  text: TextSpan(
                    text: "Don't have an account? ",
                    style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.8), fontSize: 15),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Register',
                        style: GoogleFonts.inter(
                          color: themeProvider.linkColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.pushNamed(
                                context, CustomerRegisterScreen.routeName);
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
    );
  }
}
