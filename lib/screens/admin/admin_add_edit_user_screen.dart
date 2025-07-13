// File: lib/screens/admin/admin_add_edit_user_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart'; // Assuming CustomCard is used for SwitchListTile wrapper
import '../../widgets/input.dart';
import '../../services/api_service.dart'; // Changed from AuthService to ApiService for direct call
// Import your frontend User model if you want to use the response type
import '../../models/user.dart' as app_user_model;

class AdminAddEditUserScreen extends StatefulWidget {
  static const String routeName = '/admin_add_user';
  final String?
      initialRole; // To pre-select if navigating from "Add Driver" vs "Add Admin"
  // final app_user_model.User? userToEdit; // TODO: Add this when implementing edit mode

  const AdminAddEditUserScreen({
    super.key,
    this.initialRole,
    // this.userToEdit,
  });

  @override
  State<AdminAddEditUserScreen> createState() => _AdminAddEditUserScreenState();
}

class _AdminAddEditUserScreenState extends State<AdminAddEditUserScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  // Driver specific fields
  late TextEditingController _vehicleTypeController;
  late TextEditingController _licensePlateController;
  // --- ADDED: Bank Detail Controllers for Driver Role ---
  late TextEditingController _bankCodeController;
  late TextEditingController _accountNumberController;
  late TextEditingController _accountNameController;
  // --- END ADDED ---
  bool _isDriverInitiallyAvailable = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _selectedRole;
  final List<String> _roleOptions = [
    "Driver",
    "Admin"
  ]; // Removed "Customer" as admin usually doesn't create them this way

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _fieldSlideAnimations;

  final ApiService _apiService = ApiService(); // Using ApiService directly

  @override
  void initState() {
    super.initState();
    // _isEditMode = widget.userToEdit != null; // TODO for Edit Mode

    _selectedRole = widget.initialRole?.capitalizeFirst() ?? _roleOptions.first;
    // if (_isEditMode) {
    //   _selectedRole = widget.userToEdit!.role.capitalizeFirst();
    // }

    _nameController = TextEditingController(
        /*text: _isEditMode ? widget.userToEdit!.name : ''*/);
    _emailController = TextEditingController(
        /*text: _isEditMode ? widget.userToEdit!.email : ''*/);
    _phoneController = TextEditingController(
        /*text: _isEditMode ? widget.userToEdit!.phone : ''*/);
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _vehicleTypeController = TextEditingController(
        /*text: _isEditMode && widget.userToEdit!.role == 'driver' ? (widget.userToEdit as dynamic).vehicleType : ''*/);
    _licensePlateController = TextEditingController(
        /*text: _isEditMode && widget.userToEdit!.role == 'driver' ? (widget.userToEdit as dynamic).licensePlate : ''*/);
    _bankCodeController = TextEditingController(
        /*text: _isEditMode && widget.userToEdit!.role == 'driver' ? (widget.userToEdit as dynamic).bankDetails?.bankCode : ''*/);
    _accountNumberController = TextEditingController(
        /*text: _isEditMode && widget.userToEdit!.role == 'driver' ? (widget.userToEdit as dynamic).bankDetails?.accountNumber : ''*/);
    _accountNameController = TextEditingController(
        /*text: _isEditMode && widget.userToEdit!.role == 'driver' ? (widget.userToEdit as dynamic).bankDetails?.accountName : ''*/);
    // if(_isEditMode && widget.userToEdit!.role == 'driver') {
    //   _isDriverInitiallyAvailable = (widget.userToEdit as dynamic).isAvailableOnline ?? true;
    // }

    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fieldSlideAnimations = List.generate(
      10, // Increased for more fields
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(
              0.1 + (index * 0.07), (0.7 + (index * 0.07)).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic),
        ),
      ),
    );
    _entryAnimController.forward();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleTypeController.dispose();
    _licensePlateController.dispose();
    _bankCodeController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveUser() async {
    // Renamed from _handleCreateUser
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) {
      _showFeedbackSnackbar('Please correct the errors in the form.',
          isError: true);
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      if (_selectedRole == null) {
        throw Exception("A user role must be selected.");
      }

      if (_isEditMode) {
        // TODO: Implement _apiService.adminUpdateUser(...)
        // This will require a new method in ApiService and corresponding backend PUT /api/v1/users/admin/:userId
        // The payload will be different (only send updated fields).
        // For now, focusing on create.
        _showFeedbackSnackbar(
            'Edit functionality not yet implemented in this example.',
            isError: true);
        return;
      } else {
        // Create new user
        // Backend's adminCreateUser expects: name, email, phone, password, role.
        // It does NOT take bankDetails, vehicleType, licensePlate, isAvailableOnline directly at creation.
        // These extra details would be updated via an "edit" call after creation.

        await _apiService.adminCreateUser(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole!.toLowerCase(),
        );
        // Note: If creating a driver, bank details and other driver-specific info
        // need to be added via an update call after the user is created.
        // For this example, we are only sending core fields for user creation.
      }

      if (mounted) {
        _showFeedbackSnackbar(
          _isEditMode
              ? 'User updated successfully!'
              : '${_selectedRole ?? "User"} account created successfully!',
        );
        Navigator.pop(
            context, true); // Pop with result true to refresh previous screen
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(
            'Operation failed: ${e.toString().replaceFirst("Exception: ", "")}',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    final Color adminAccentColor = themeProvider.gas2doorPurple;
    final String appBarTitle = _isEditMode ? "Edit User" : "Create New User";

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        title: Text(appBarTitle,
            style: GoogleFonts.inter(
                color: themeProvider.primaryText, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5)))
                : TextButton(
                    onPressed: _handleSaveUser, // Changed to _handleSaveUser
                    style:
                        TextButton.styleFrom(foregroundColor: adminAccentColor),
                    child: Text(_isEditMode ? 'SAVE CHANGES' : 'CREATE USER',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _entryAnimController,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SlideTransition(
                  position: _fieldSlideAnimations[0],
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'User Role*',
                      border: OutlineInputBorder(
                          borderRadius: themeProvider.cardBorderRadius),
                      filled: true,
                      fillColor: themeProvider.cardBackground.withOpacity(0.5),
                      prefixIcon: Icon(Icons.supervised_user_circle_outlined,
                          color: themeProvider.secondaryText),
                    ),
                    dropdownColor: themeProvider.cardBackground,
                    style: GoogleFonts.inter(color: themeProvider.primaryText),
                    value: _selectedRole,
                    items: _roleOptions
                        .map((String value) => DropdownMenuItem<String>(
                            value: value, child: Text(value)))
                        .toList(),
                    onChanged: _isEditMode
                        ? null
                        : (String? newValue) => setState(() => _selectedRole =
                            newValue), // Role not editable in edit mode for simplicity
                    validator: (value) =>
                        value == null ? 'Please select a role' : null,
                  ),
                ),
                const SizedBox(height: 18),
                SlideTransition(
                    position: _fieldSlideAnimations[1],
                    child: CustomInput(
                        controller: _nameController,
                        labelText: 'Full Name*',
                        hintText: 'Enter full name',
                        prefixIcon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Name is required'
                            : null)),
                const SizedBox(height: 18),
                SlideTransition(
                    position: _fieldSlideAnimations[2],
                    child: CustomInput(
                        controller: _emailController,
                        labelText: 'Email Address*',
                        hintText: 'Enter email',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Email is required'
                            : (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                                    .hasMatch(val.trim())
                                ? 'Enter a valid email'
                                : null))),
                const SizedBox(height: 18),
                SlideTransition(
                    position: _fieldSlideAnimations[3],
                    child: CustomInput(
                        controller: _phoneController,
                        labelText: 'Phone Number*',
                        hintText: 'Enter phone number',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Phone is required'
                            : (!RegExp(r'^\+?[0-9]{10,15}$')
                                    .hasMatch(val.trim())
                                ? 'Enter a valid phone'
                                : null))),
                const SizedBox(height: 18),
                SlideTransition(
                    position: _fieldSlideAnimations[4],
                    child: CustomInput(
                        controller: _passwordController,
                        labelText: _isEditMode
                            ? 'New Password (Optional)'
                            : 'Create Password*',
                        hintText: _isEditMode
                            ? 'Leave blank to keep current'
                            : 'Min. 6 characters',
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
                        validator: (val) => (!_isEditMode &&
                                (val == null || val.isEmpty))
                            ? 'Password is required'
                            : ((val != null && val.isNotEmpty && val.length < 6)
                                ? 'Password too short'
                                : null))),
                if (!_isEditMode) ...[
                  // Confirm password only for create mode
                  const SizedBox(height: 18),
                  SlideTransition(
                      position: _fieldSlideAnimations[5],
                      child: CustomInput(
                          controller: _confirmPasswordController,
                          labelText: 'Confirm Password*',
                          hintText: 'Re-enter password',
                          obscureText: _obscureConfirmPassword,
                          prefixIcon: Icons.lock_person_outlined,
                          textInputAction: (_selectedRole == "Driver")
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onFieldSubmitted:
                              (_selectedRole != "Driver" && !_isLoading)
                                  ? (_) => _handleSaveUser()
                                  : null,
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
                          validator: (val) {
                            if (!_isEditMode && (val == null || val.isEmpty))
                              return 'Confirm password';
                            if (!_isEditMode && val != _passwordController.text)
                              return 'Passwords do not match';
                            return null;
                          })),
                ],
                // Conditionally show Driver specific fields ONLY if role is "Driver"
                // These are NOT sent during adminCreateUser, but would be part of adminUpdateUser
                if (_selectedRole == "Driver" && _isEditMode) ...[
                  // Example: show only in edit mode for driver
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                    child: Text("Driver Specific Information (Editable)",
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.secondaryText)),
                  ),
                  CustomInput(
                      controller: _bankCodeController,
                      labelText: 'Bank Code',
                      prefixIcon: Icons.account_balance_outlined,
                      textInputAction: TextInputAction.next),
                  const SizedBox(height: 18),
                  CustomInput(
                      controller: _accountNumberController,
                      labelText: 'Account Number',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.confirmation_number_outlined,
                      textInputAction: TextInputAction.next),
                  const SizedBox(height: 18),
                  CustomInput(
                      controller: _accountNameController,
                      labelText: 'Account Holder Name',
                      prefixIcon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next),
                  const SizedBox(height: 18),
                  CustomInput(
                      controller: _vehicleTypeController,
                      labelText: 'Vehicle Type',
                      prefixIcon: Icons.two_wheeler_outlined,
                      textInputAction: TextInputAction.next),
                  const SizedBox(height: 18),
                  CustomInput(
                      controller: _licensePlateController,
                      labelText: 'License Plate',
                      prefixIcon: Icons.pin_outlined,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted:
                          _isLoading ? null : (_) => _handleSaveUser()),
                  const SizedBox(height: 18),
                  CustomCard(
                    child: SwitchListTile.adaptive(
                      title: Text('Driver Available Online',
                          style: GoogleFonts.inter(
                              color: themeProvider.primaryText)),
                      value: _isDriverInitiallyAvailable,
                      onChanged: (bool value) =>
                          setState(() => _isDriverInitiallyAvailable = value),
                      activeColor: themeProvider.gas2doorTeal,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper extension for string capitalization
extension StringCapitalizeExtensionAdminAddUserScreen on String {
  String capitalizeFirst() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
