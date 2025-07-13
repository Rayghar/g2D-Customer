// File: lib/screens/auth/complete_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../services/api_service.dart';
import '../customer/customer_dashboard_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  static const String routeName = '/complete_profile';
  final String userName;

  const CompleteProfileScreen({super.key, required this.userName});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _apiService = ApiService();
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

  Future<void> _handleCompleteProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      // ========================== FIX IS HERE ==========================
      // The method call has been corrected to use the new `updateProfile` method.
      await _apiService.updateProfile({
        'phone': _phoneController.text.trim(),
      });
      // ===============================================================

      if (!mounted) return;
      _showFeedbackSnackbar('Profile completed successfully!');
      Navigator.of(context).pushNamedAndRemoveUntil(
          CustomerDashboardScreen.routeName, (route) => false);
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Complete Your Profile',
            style: GoogleFonts.inter(color: themeProvider.primaryText)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // User cannot go back
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Icon(Icons.person_add_alt_1_rounded,
                    size: 80, color: themeProvider.gas2doorPrimaryBlue),
                const SizedBox(height: 30),
                Text('Welcome, ${widget.userName}!',
                    style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.primaryText)),
                const SizedBox(height: 12),
                Text(
                    'Just one more step. Please provide your phone number to complete your registration.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        color: themeProvider.secondaryText,
                        height: 1.5)),
                const SizedBox(height: 40),
                CustomInput(
                  controller: _phoneController,
                  labelText: 'Phone Number*',
                  hintText: 'Enter your phone number',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Phone number is required';
                    if (!RegExp(r'^\+?\d{10,15}$').hasMatch(value.trim()))
                      return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                CustomButton(
                  text: _isLoading ? 'Saving...' : 'Complete Registration',
                  onPressed: _isLoading ? null : _handleCompleteProfile,
                  color: themeProvider.gas2doorPrimaryBlue,
                  height: 52,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
