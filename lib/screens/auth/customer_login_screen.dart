// File: lib/screens/auth/customer_login_screen.dart
// ADVISORY: This version includes the requested layout refinements.
// NOTE: Surgical update—existing flows preserved. Unused imports trimmed.

import 'dart:io'; // For Platform.isIOS
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'complete_profile_screen.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../customer/customer_dashboard_screen.dart';
import './forgot_password_screen.dart';
import './customer_register_screen.dart';
import '../../models/auth_response_model.dart';

import '../../widgets/button.dart';
import '../../widgets/curve_painter.dart';
import '../../services/socket_service.dart';

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
  bool _isAppleSignInAvailable = false;

  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _checkAppleSignInAvailability();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('email')) {
        _emailController.text = (args['email'] ?? '').toString();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAppleSignInAvailability() async {
    if (Platform.isIOS) {
      final isAvailable = await SignInWithApple.isAvailable();
      if (!mounted) return;
      setState(() => _isAppleSignInAvailable = isAvailable);
    }
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
      // 1) Backend auth (saves JWT)
      final LoginSuccessData loginData = await _authService.loginCustomer(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // 2) Real-time socket connect
      _socketService.connect();

      // 3) FCM token registration (best effort; simulators may fail)
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _apiService.registerFcmToken(fcmToken);
        }
      } catch (e) {
        // Simulators often don't have APNS; don't block login.
        // ignore: avoid_print
        print('FCM token registration skipped/failure: $e');
      }

      if (!mounted) return;

      // 4) Navigate
      if (loginData.isNewUser) {
        Navigator.of(context).pushNamed(
          CompleteProfileScreen.routeName,
          arguments: {'email': _emailController.text.trim()},
        );
      } else {
        _showFeedbackSnackbar('Welcome back, ${loginData.name}!');
        Navigator.of(context).pushNamedAndRemoveUntil(
          CustomerDashboardScreen.routeName,
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showFeedbackSnackbar(
        e.toString().replaceFirst("Exception: ", ""),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // ensure clean session
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return; // user cancelled
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

      // Best-effort FCM registration
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _apiService.registerFcmToken(fcmToken);
        }
      } catch (e) {
        // ignore: avoid_print
        print('FCM token registration skipped/failure: $e');
      }

      _showFeedbackSnackbar(
          'Google Sign-In successful! Welcome, ${loginData.name}.');
      Navigator.of(context).pushNamedAndRemoveUntil(
        CustomerDashboardScreen.routeName,
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(
          e.toString().replaceFirst("Exception: ", ""),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (!Platform.isIOS) return; // guard—Apple Sign-In is iOS only
    setState(() => _isLoading = true);
    try {
      // 1) Request Apple credential (first use may return email/fullName)
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // 2) Extract ID token for backend verification
      final String? idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception("Could not retrieve Apple ID token.");
      }

      // 3) Backend auth with Apple ID token (preserves your existing flow)
      final LoginSuccessData loginData =
          await _authService.signInWithApple(idToken);
      if (!mounted) return;

      // 4) Best-effort FCM registration
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _apiService.registerFcmToken(fcmToken);
        }
      } catch (e) {
        // ignore: avoid_print
        print('FCM token registration skipped/failure: $e');
      }

      // 5) Success → navigate
      _showFeedbackSnackbar(
          'Apple Sign-In successful! Welcome, ${loginData.name}.');
      Navigator.of(context).pushNamedAndRemoveUntil(
        CustomerDashboardScreen.routeName,
        (route) => false,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      if (e.code == AuthorizationErrorCode.canceled) {
        // User canceled—no error UI
        return;
      }
      _showFeedbackSnackbar('Apple Sign-In failed.', isError: true);
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(
          e.toString().replaceFirst("Exception: ", ""),
          isError: true,
        );
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
      body: Stack(
        children: [
          Container(color: Colors.grey.shade200),
          Positioned(
            top: -MediaQuery.of(context).size.height * 0.3,
            left: -MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.2,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade300.withOpacity(0.7),
                    Colors.red.shade300.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.3, 0.7],
                ),
              ),
              child: Transform.rotate(
                angle: -0.2,
                child: CustomPaint(
                  size: Size(
                    MediaQuery.of(context).size.width * 1.2,
                    MediaQuery.of(context).size.height * 0.8,
                  ),
                  painter: CurvePainter(),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -MediaQuery.of(context).size.height * 0.3,
            right: -MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.2,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade800.withOpacity(0.5),
                    Colors.blue.shade300.withOpacity(0.5),
                  ],
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                  stops: const [0.3, 0.7],
                ),
              ),
              child: Transform.rotate(
                angle: 0.2,
                child: CustomPaint(
                  size: Size(
                    MediaQuery.of(context).size.width * 1.2,
                    MediaQuery.of(context).size.height * 0.8,
                  ),
                  painter: CurvePainter(),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: MediaQuery.of(context).size.width * 0.15,
            child: Opacity(
              opacity: 0.8,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: const Icon(Icons.local_gas_station_outlined,
                    size: 30, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: MediaQuery.of(context).size.width * 0.4,
            child: Opacity(
              opacity: 0.8,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    size: 30, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.65,
            left: MediaQuery.of(context).size.width * 0.7,
            child: Opacity(
              opacity: 0.8,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: const Icon(Icons.location_on_outlined,
                    size: 30, color: Colors.white),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/gas2door_logo.png', height: 100),
                  const SizedBox(height: 40),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(24),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.6)),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Welcome Back',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Login to access your account.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 30),
                              Theme(
                                data: Theme.of(context).copyWith(
                                  inputDecorationTheme:
                                      inputDecorationThemeForScreen,
                                ),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      decoration: const InputDecoration(
                                        labelText: 'Email Address',
                                        prefixIcon: Icon(Icons.email_outlined),
                                      ),
                                      style: GoogleFonts.inter(
                                          color: Colors.black87),
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator: (value) {
                                        final v = value?.trim() ?? '';
                                        if (v.isEmpty)
                                          return 'Please enter your email';
                                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                            .hasMatch(v)) {
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
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                      ),
                                      style: GoogleFonts.inter(
                                          color: Colors.black87),
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _handleLogin(),
                                      validator: (value) {
                                        final v = value ?? '';
                                        if (v.isEmpty) {
                                          return 'Please enter your password';
                                        }
                                        if (v.length < 6) {
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
                                      Navigator.pushNamed(
                                        context,
                                        ForgotPasswordScreen.routeName,
                                      );
                                    },
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.inter(
                                        color: themeProvider.linkColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                icon: _isLoading
                                    ? const SizedBox.shrink()
                                    : const Icon(Icons.login_rounded, size: 22),
                                label: Text(
                                    _isLoading ? 'Signing In...' : 'Sign In'),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: Colors.black.withOpacity(0.2),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      "OR",
                                      style: GoogleFonts.inter(
                                        color: Colors.black.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: Colors.black.withOpacity(0.2),
                                    ),
                                  ),
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                icon: Image.asset(
                                  'assets/images/google_logo.png',
                                  height: 24,
                                ),
                                label: const Text('Sign In with Google'),
                              ),
                              if (_isAppleSignInAvailable)
                                const SizedBox(height: 16),
                              if (_isAppleSignInAvailable)
                                ElevatedButton.icon(
                                  onPressed:
                                      _isLoading ? null : _handleAppleSignIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.black, // Apple guideline
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  icon: const Icon(Icons.apple,
                                      color: Colors.white, size: 24),
                                  label: const Text('Sign In with Apple'),
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
                        color: Colors.black87.withOpacity(0.8),
                        fontSize: 15,
                      ),
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
                                context,
                                CustomerRegisterScreen.routeName,
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
