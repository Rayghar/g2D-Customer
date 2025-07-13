// File: lib/screens/customer/profile/edit_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../../providers/theme_provider.dart';
import '../../../widgets/input.dart';
import '../../../widgets/button.dart';
import '../../../services/api_service.dart';
import '../../../models/user.dart' as app_user;

class EditProfileScreen extends StatefulWidget {
  static const String routeName = '/edit_profile';
  final String customerId;

  const EditProfileScreen({super.key, required this.customerId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  String? _photoUrl;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final app_user.User user = await _apiService.getMyProfile();
      if (mounted) {
        setState(() {
          _nameController.text = user.name;
          _emailController.text = user.email;
          _phoneController.text = user.phone ?? '';
          // _photoUrl = user.photoUrl; // CORRECTED: This field does not exist on the User model
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Failed to load profile: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showFeedbackSnackbar("Please correct the errors in the form.",
          isError: true);
      return;
    }
    // No longer need to call _formKey.currentState!.save() as controllers hold the state.

    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> updateData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      await _apiService.updateProfile(updateData);

      if (mounted) {
        _showFeedbackSnackbar('Profile updated successfully!', isError: false);
        Navigator.of(context).pop(true); // Pop and indicate success
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(
            "Update failed: ${e.toString().replaceFirst("Exception: ", "")}",
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        title: Text('Edit Profile',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, color: themeProvider.primaryText)),
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: themeProvider.gas2doorPrimaryBlue,
                      ))
                  : Text('Save',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: themeProvider.gas2doorPrimaryBlue,
                          fontSize: 16)),
            ),
          )
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: themeProvider.gas2doorPrimaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor:
                                themeProvider.gas2doorTeal.withOpacity(0.15),
                            backgroundImage:
                                _photoUrl != null && _photoUrl!.isNotEmpty
                                    ? NetworkImage(_photoUrl!)
                                    : null,
                            child: _photoUrl == null || _photoUrl!.isEmpty
                                ? Icon(Icons.person_rounded,
                                    size: 70,
                                    color: themeProvider.gas2doorTeal
                                        .withOpacity(0.8))
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: themeProvider.cardBackground,
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    themeProvider.gas2doorPrimaryBlue,
                                child: IconButton(
                                  icon: Icon(Icons.camera_alt_outlined,
                                      color: themeProvider.infoColorOnDarkBgs,
                                      size: 20),
                                  onPressed: () {
                                    _showFeedbackSnackbar(
                                        "Image picker not implemented.",
                                        isError: true);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    CustomInput(
                      controller: _nameController,
                      labelText: 'Full Name',
                      hintText: 'Enter your full name',
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        if (value.trim().length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 20),
                    CustomInput(
                      controller: _emailController,
                      labelText: 'Email Address',
                      hintText: 'Enter your email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Email is required';
                        if (!RegExp(
                                r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                            .hasMatch(value.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    CustomInput(
                      controller: _phoneController,
                      labelText: 'Phone Number',
                      hintText: 'Enter your phone number',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Phone number is required';
                        if (!RegExp(r'^\+?[0-9]{10,15}$')
                            .hasMatch(value.trim())) {
                          return 'Enter a valid phone number (e.g., 08012345678 or +2348012345678)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
