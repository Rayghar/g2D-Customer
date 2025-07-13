// File: lib/screens/admin/admin_add_edit_promotion_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/input.dart';
import '../../models/admin/admin_promotion_model.dart';
import '../../services/api_service.dart'; // Import the ApiService

class AdminAddEditPromotionScreen extends StatefulWidget {
  static const String routeName = '/admin_add_edit_promotion';
  final AdminPromotionModel? promotion;

  const AdminAddEditPromotionScreen({super.key, this.promotion});

  @override
  State<AdminAddEditPromotionScreen> createState() =>
      _AdminAddEditPromotionScreenState();
}

class _AdminAddEditPromotionScreenState
    extends State<AdminAddEditPromotionScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService(); // Use the actual ApiService
  bool _isLoading = false;
  bool _isEditMode = false;
  String? _editingPromotionId;

  late TextEditingController _titleController;
  late TextEditingController _shortDescController;
  late TextEditingController _longDescController;
  late TextEditingController _promoCodeController;
  late TextEditingController _discountValueController;
  late TextEditingController _termsController;
  late TextEditingController _imageUrlController;

  String _selectedPromotionType = "Fixed Amount Discount"; // Default
  DateTime _validFrom = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  bool _isActive = true;

  final List<String> _promotionTypeOptions = [
    "Percentage Discount",
    "Fixed Amount Discount",
    "Free Delivery"
  ];

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _fieldSlideAnimations;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.promotion != null;
    _editingPromotionId = widget.promotion?.id;

    _titleController =
        TextEditingController(text: widget.promotion?.title ?? '');
    _shortDescController =
        TextEditingController(text: widget.promotion?.shortDescription ?? '');
    _longDescController =
        TextEditingController(text: widget.promotion?.longDescription ?? '');
    _promoCodeController =
        TextEditingController(text: widget.promotion?.promoCode ?? '');

    _selectedPromotionType = _isEditMode
        ? widget.promotion!.type
        : _promotionTypeOptions.firstWhere(
            (opt) => opt == "Fixed Amount Discount",
            orElse: () => _promotionTypeOptions.first);

    String initialDiscountValue = "0.0";
    if (_isEditMode && widget.promotion != null) {
      if (widget.promotion!.type == "Percentage Discount") {
        initialDiscountValue = (widget.promotion!.value).toStringAsFixed(0);
      } else if (widget.promotion!.type == "Fixed Amount Discount") {
        initialDiscountValue = widget.promotion!.value.toStringAsFixed(0);
      }
      // For "Free Delivery", value is often 0, so default "0.0" is fine.
    }
    _discountValueController =
        TextEditingController(text: initialDiscountValue);

    _validFrom = widget.promotion?.validFrom ?? DateTime.now();
    _validUntil = widget.promotion?.validUntil ??
        DateTime.now().add(const Duration(days: 30));
    _termsController =
        TextEditingController(text: widget.promotion?.termsAndConditions ?? '');
    _isActive = widget.promotion?.isActive ?? true;
    _imageUrlController =
        TextEditingController(text: widget.promotion?.imageUrl ?? '');

    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fieldSlideAnimations = List.generate(
      10, // Number of animated fields/groups
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(
            parent: _entryAnimController,
            curve: Interval(
                0.1 + (index * 0.07), 0.7 + (index * 0.07).clamp(0.0, 0.3),
                curve: Curves.easeOutCubic)),
      ),
    );
    _entryAnimController.forward();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    _titleController.dispose();
    _shortDescController.dispose();
    _longDescController.dispose();
    _promoCodeController.dispose();
    _discountValueController.dispose();
    _termsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    HapticFeedback.lightImpact();
    final DateTime initial = isStartDate ? _validFrom : _validUntil;
    final DateTime firstValidDate =
        isStartDate ? DateTime(2020) : _validFrom.add(const Duration(days: 1));

    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initial.isBefore(firstValidDate)
            ? firstValidDate
            : initial, // Ensure initial is not before first
        firstDate: firstValidDate,
        lastDate: DateTime(2101),
        builder: (context, child) {
          final themeProvider =
              Provider.of<ThemeProvider>(context, listen: false);
          return Theme(
              data: themeProvider.isDarkMode
                  ? themeProvider.darkTheme
                  : themeProvider.lightTheme,
              child: child!);
        });
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _validFrom = picked;
          if (_validUntil.isBefore(_validFrom) ||
              _validUntil.isAtSameMomentAs(_validFrom)) {
            _validUntil = _validFrom.add(const Duration(days: 1));
          }
        } else {
          _validUntil = picked;
        }
      });
    }
  }

  Future<void> _handleSaveChanges() async {
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) {
      _showFeedbackSnackbar('Please correct the errors in the form.',
          isError: true);
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    double promotionValue =
        double.tryParse(_discountValueController.text) ?? 0.0;
    if (_selectedPromotionType == "Free Delivery") {
      promotionValue = 0.0;
    }

    final Map<String, dynamic> promotionData = {
      'title': _titleController.text.trim(),
      'shortDescription': _shortDescController.text.trim(),
      'longDescription': _longDescController.text.trim(),
      'promoCode': _promoCodeController.text.trim().isNotEmpty
          ? _promoCodeController.text.trim().toUpperCase()
          : null,
      'type': _selectedPromotionType,
      'value': promotionValue,
      'validFrom': _validFrom.toIso8601String(), // Send as ISO 8601 string
      'validUntil': _validUntil.toIso8601String(), // Send as ISO 8601 string
      'termsAndConditions': _termsController.text.trim().isNotEmpty
          ? _termsController.text.trim()
          : null,
      'isActive': _isActive,
      'imageUrl': _imageUrlController.text.trim().isNotEmpty
          ? _imageUrlController.text.trim()
          : null,
    };

    try {
      if (_isEditMode && _editingPromotionId != null) {
        await _apiService.adminUpdatePromotion(
            _editingPromotionId!, promotionData);
        _showFeedbackSnackbar('Promotion updated successfully!');
      } else {
        await _apiService.adminCreatePromotion(promotionData);
        _showFeedbackSnackbar('Promotion created successfully!');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        _showFeedbackSnackbar(
            'Failed to save promotion: ${e.toString().replaceFirst("Exception: ", "")}', // Strip "Exception: "
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // CORRECTED _showFeedbackSnackbar
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
    final Color adminAccentColor = themeProvider.gas2doorPurple;
    final String appBarTitle =
        _isEditMode ? "Edit Promotion" : "Add New Promotion";

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text(appBarTitle,
            style: GoogleFonts.inter(
                color: themeProvider.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: themeProvider.primaryText),
            onPressed: () => Navigator.of(context).pop()),
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
                    onPressed: _handleSaveChanges,
                    style:
                        TextButton.styleFrom(foregroundColor: adminAccentColor),
                    child: Text('SAVE',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _entryAnimController,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              SlideTransition(
                  position: _fieldSlideAnimations[0],
                  child: CustomInput(
                      controller: _titleController,
                      labelText: 'Promotion Title*',
                      hintText: 'e.g., Summer Splash Sale',
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Title is required' : null)),
              const SizedBox(height: 16),
              SlideTransition(
                  position: _fieldSlideAnimations[1],
                  child: CustomInput(
                      controller: _shortDescController,
                      labelText: 'Short Description (for cards)*',
                      hintText: 'e.g., 20% off all 12.5KG cylinders!',
                      maxLines: 2,
                      validator: (v) => v!.trim().isEmpty
                          ? 'Short description is required'
                          : null)),
              const SizedBox(height: 16),
              SlideTransition(
                  position: _fieldSlideAnimations[2],
                  child: CustomInput(
                      controller: _longDescController,
                      labelText: 'Full Description/Details (Optional)',
                      hintText: 'Detailed explanation of the offer...',
                      maxLines: 4)),
              const SizedBox(height: 16),
              SlideTransition(
                  position: _fieldSlideAnimations[3],
                  child: Row(children: [
                    Expanded(
                        child: CustomInput(
                            controller: _promoCodeController,
                            labelText: 'Promo Code (Optional)',
                            hintText: 'e.g., SUMMER20 (auto-uppercased)')),
                  ])),
              const SizedBox(height: 16),
              SlideTransition(
                position: _fieldSlideAnimations[4],
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                      labelText: 'Promotion Type*',
                      border: OutlineInputBorder(
                          borderRadius: themeProvider.cardBorderRadius),
                      filled: true,
                      fillColor: themeProvider.cardBackground.withOpacity(0.5),
                      prefixIcon: Icon(Icons.category_outlined,
                          color: themeProvider.secondaryText)),
                  dropdownColor: themeProvider.cardBackground,
                  style: GoogleFonts.inter(color: themeProvider.primaryText),
                  value: _selectedPromotionType,
                  items: _promotionTypeOptions
                      .map((String value) => DropdownMenuItem<String>(
                          value: value, child: Text(value)))
                      .toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedPromotionType = newValue);
                    }
                  },
                  validator: (value) =>
                      value == null ? 'Please select a type' : null,
                ),
              ),
              if (_selectedPromotionType == "Percentage Discount" ||
                  _selectedPromotionType == "Fixed Amount Discount") ...[
                const SizedBox(height: 16),
                SlideTransition(
                  position: _fieldSlideAnimations[5],
                  child: CustomInput(
                    controller: _discountValueController,
                    labelText: _selectedPromotionType == "Percentage Discount"
                        ? 'Discount Percentage*'
                        : 'Discount Amount (₦)*',
                    hintText: _selectedPromotionType == "Percentage Discount"
                        ? 'e.g., 20 (for 20%)'
                        : 'e.g., 500',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal:
                            false), // No decimal for percentage or fixed amount
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ], // Allow only digits
                    prefixIcon: _selectedPromotionType == "Percentage Discount"
                        ? Icons.percent_rounded
                        : Icons.attach_money_rounded,
                    validator: (v) => (v == null ||
                            v.isEmpty ||
                            double.tryParse(v) == null ||
                            double.parse(v) <= 0)
                        ? 'Valid positive value required'
                        : (_selectedPromotionType == "Percentage Discount" &&
                                double.parse(v) > 100
                            ? 'Cannot exceed 100%'
                            : null),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SlideTransition(
                position: _fieldSlideAnimations[6],
                child: Row(children: [
                  Expanded(
                      child: _buildDateField(
                          "Valid From*",
                          _validFrom,
                          themeProvider,
                          (date) => setState(() {
                                _validFrom = date;
                                if (_validUntil.isBefore(_validFrom) ||
                                    _validUntil.isAtSameMomentAs(_validFrom))
                                  _validUntil =
                                      _validFrom.add(const Duration(days: 1));
                              }))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildDateField(
                          "Valid Until*",
                          _validUntil,
                          themeProvider,
                          (date) => setState(() => _validUntil = date),
                          firstDate: _validFrom.add(const Duration(
                              days:
                                  1)))), // Ensure end date is after start date
                ]),
              ),
              const SizedBox(height: 16),
              SlideTransition(
                  position: _fieldSlideAnimations[7],
                  child: CustomInput(
                      controller: _termsController,
                      labelText: 'Terms & Conditions (Optional)',
                      hintText: 'Enter detailed T&Cs...',
                      maxLines: 5)),
              const SizedBox(height: 16),
              SlideTransition(
                  position: _fieldSlideAnimations[8],
                  child: CustomInput(
                    controller: _imageUrlController,
                    labelText: 'Image URL (Optional)',
                    hintText: 'https://example.com/image.png',
                    keyboardType: TextInputType.url,
                  )),
              const SizedBox(height: 16),
              SlideTransition(
                position: _fieldSlideAnimations[9],
                child: CustomCard(
                  color: themeProvider.cardBackground,
                  child: SwitchListTile.adaptive(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    title: Text('Activate Promotion',
                        style: GoogleFonts.inter(
                            color: themeProvider.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    value: _isActive,
                    onChanged: (bool value) =>
                        setState(() => _isActive = value),
                    activeColor: themeProvider.gas2doorTeal,
                    secondary: Icon(
                        _isActive
                            ? Icons.toggle_on_rounded
                            : Icons.toggle_off_outlined,
                        color: _isActive
                            ? themeProvider.gas2doorTeal
                            : themeProvider.secondaryText,
                        size: 30),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime currentDate,
      ThemeProvider themeProvider, Function(DateTime) onDateSelected,
      {DateTime? firstDate}) {
    return InkWell(
      onTap: () => _selectDate(context, label.contains("From")),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: themeProvider.secondaryText),
          prefixIcon: Icon(Icons.calendar_month_outlined,
              color: themeProvider.secondaryText.withOpacity(0.7)),
          border: OutlineInputBorder(
              borderRadius: themeProvider.cardBorderRadius,
              borderSide: BorderSide(
                  color: themeProvider.tertiaryText.withOpacity(0.5))),
          enabledBorder: OutlineInputBorder(
              borderRadius: themeProvider.cardBorderRadius,
              borderSide: BorderSide(
                  color: themeProvider.tertiaryText.withOpacity(0.5))),
          focusedBorder: OutlineInputBorder(
              borderRadius: themeProvider.cardBorderRadius,
              borderSide: BorderSide(
                  color: themeProvider.gas2doorPrimaryBlue, width: 1.5)),
          filled: true,
          fillColor: themeProvider.cardBackground.withOpacity(0.5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        ),
        child: Text(
            DateFormat('MMM dd, yyyy')
                .format(currentDate), // Corrected DateFormat
            style: GoogleFonts.inter(
                color: themeProvider.primaryText, fontSize: 15)),
      ),
    );
  }
}
