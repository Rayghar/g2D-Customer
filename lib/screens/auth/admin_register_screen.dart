// File: lib/screens/auth/admin_register_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart'; // Using ApiService directly
import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import './admin_login_screen.dart';
// Import RegistrationResponseModel if needed for typed response
import '../../models/registration_response_model.dart';

class AdminRegisterScreen extends StatefulWidget {
  static const String routeName = '/admin_register';
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(); // Added for phone
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimationHeader;
  late Animation<Offset> _slideAnimationForm;

  final ApiService _apiService = ApiService();

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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose(); // Added
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _registerAdmin() async {
    // Renamed from _register
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) {
      _showFeedbackSnackbar('Please correct the errors in the form.',
          isError: true);
      return;
    }
    setState(() => _isLoading = true);

    try {
      // **INTEGRATION POINT**
      // Using the new ApiService.selfRegisterAdmin method
      final responseData = await _apiService.selfRegisterAdmin(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(), // Sending phone
        password: _passwordController.text,
        // If your backend self-register admin requires a special key:
        // adminRegistrationKey: 'YOUR_SPECIAL_KEY_IF_ANY'
      );

      // Convert to typed model if desired, or use map directly
      final registrationResponse =
          RegistrationResponseModel.fromJson(responseData);

      if (mounted) {
        _showFeedbackSnackbar(
            registrationResponse.message.isNotEmpty
                ? registrationResponse.message
                : 'Admin registration successful! Please login.',
            isError: false);
        Navigator.pushNamedAndRemoveUntil(
            context, AdminLoginScreen.routeName, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(
            'Registration Failed: ${e.toString().replaceFirst("Exception: ", "")}',
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String appLogoPath = themeProvider.isDarkMode
        ? 'assets/images/gas2door_logo.png'
        : 'assets/images/gas2door_logo.png';
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
            Text('New Admin Registration',
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
                onPressed: () => Navigator.of(context).pop())
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
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                SlideTransition(
                  position: _slideAnimationHeader,
                  child: Column(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded,
                          size: 50, color: adminAccentColor), // Custom icon
                      const SizedBox(height: 12),
                      Text('Create Administrator Account',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.primaryText)),
                      const SizedBox(height: 8),
                      Text('Fill in the details to create a new admin profile.',
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
                          controller: _nameController,
                          labelText: 'Full Name*',
                          hintText: 'Enter admin\'s full name',
                          prefixIcon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Name is required'
                                  : null),
                      const SizedBox(height: 18),
                      CustomInput(
                          controller: _emailController,
                          labelText: 'Email Address*',
                          hintText: 'Enter admin\'s email',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty)
                              return 'Email is required';
                            if (!RegExp(
                                    r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                                .hasMatch(value.trim()))
                              return 'Enter a valid email';
                            return null;
                          }),
                      const SizedBox(height: 18),
                      // --- ADDED Phone Input Field ---
                      CustomInput(
                        controller: _phoneController,
                        labelText: 'Phone Number*',
                        hintText: 'Enter admin\'s phone number',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Phone number is required';
                          if (!RegExp(r'^\+?[0-9]{10,15}$')
                              .hasMatch(value.trim()))
                            return 'Enter a valid phone number';
                          return null;
                        },
                      ),
                      // --- END ADDED ---
                      const SizedBox(height: 18),
                      CustomInput(
                          controller: _passwordController,
                          labelText: 'Password*',
                          hintText: 'Create a strong password (min. 6 chars)',
                          obscureText: _obscurePassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          textInputAction: TextInputAction.next,
                          suffixIcon: IconButton(
                              icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: themeProvider.secondaryText
                                      .withOpacity(0.7)),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword)),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Password is required';
                            if (value.length < 6)
                              return 'Password must be at least 6 characters';
                            return null;
                          }),
                      const SizedBox(height: 18),
                      CustomInput(
                          controller: _confirmPasswordController,
                          labelText: 'Confirm Password*',
                          hintText: 'Re-enter the password',
                          obscureText: _obscureConfirmPassword,
                          prefixIcon: Icons.lock_person_outlined,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted:
                              _isLoading ? null : (_) => _registerAdmin(),
                          suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: themeProvider.secondaryText
                                      .withOpacity(0.7)),
                              onPressed: () => setState(() =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword)),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please confirm password';
                            if (value != _passwordController.text)
                              return 'Passwords do not match';
                            return null;
                          }),
                      const SizedBox(height: 32),
                      CustomButton(
                        text: _isLoading ? 'Registering...' : 'Register Admin',
                        onPressed: _isLoading ? null : _registerAdmin,
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
                            : Icon(Icons.person_add_alt_1_rounded,
                                color: themeProvider.infoColorOnDarkBgs ??
                                    Colors.white,
                                size: 22),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: "Already have an admin account? ",
                    style: GoogleFonts.inter(
                        color: themeProvider.secondaryText, fontSize: 15),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Login',
                        style: GoogleFonts.inter(
                            color: adminAccentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            HapticFeedback.lightImpact();
                            Navigator.pushReplacementNamed(
                                context, AdminLoginScreen.routeName);
                          },
                      ),
                    ],
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
