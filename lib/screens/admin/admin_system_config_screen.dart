// File: lib/screens/admin/admin_system_config_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../services/api_service.dart';
// Import BOTH model types, using a prefix for the plain data model to avoid conflicts
import '../../models/admin/admin_config_model.dart';
import '../../models/system_config_model.dart' as data_model;
import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/input.dart';

class AdminSystemConfigScreen extends StatefulWidget {
  static const String routeName = '/admin_system_config';
  const AdminSystemConfigScreen({super.key});

  @override
  State<AdminSystemConfigScreen> createState() =>
      _AdminSystemConfigScreenState();
}

class _AdminSystemConfigScreenState extends State<AdminSystemConfigScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  bool _hasUnsavedChanges = false;

  // This variable remains of the admin-specific type for the UI
  SystemConfigModel? _systemConfig;

  late AnimationController _entryAnimController;
  late List<Animation<Offset>> _sectionSlideAnimations;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _sectionSlideAnimations = List.generate(
      3,
      (index) =>
          Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryAnimController,
          curve: Interval(
              0.1 + (index * 0.15), 0.8 + (index * 0.1).clamp(0.0, 0.2),
              curve: Curves.easeOutCubic),
        ),
      ),
    );
    _loadSystemConfigs();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    if (_systemConfig != null) {
      for (var cylConfig in _systemConfig!.cylinderConfigs) {
        cylConfig.priceController.dispose();
        cylConfig.weightController.dispose();
      }
      _systemConfig!.feeConfig.baseDeliveryFeeController.dispose();
      _systemConfig!.feeConfig.expressDeliverySurchargeController.dispose();
      _systemConfig!.feeConfig.vatPercentageController.dispose();
      _systemConfig!.feeConfig.serviceFeePercentageController.dispose();
      _systemConfig!.routingConfig.maxPickupWindowMinutesController.dispose();
      _systemConfig!.routingConfig.maxBatchWeightKgController.dispose();
    }
    super.dispose();
  }

  /// CORRECTED: Fetches plain data and maps it to the UI state model.
  Future<void> _loadSystemConfigs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Fetch the plain data model from the service
      final data_model.SystemConfigModel data =
          await _apiService.getSystemConfig();

      // 2. Map the plain data to our stateful admin model
      if (mounted) {
        setState(() {
          // Creates the model with TextEditingControllers from the fetched data
          _systemConfig = SystemConfigModel.fromDataModel(data);
          _addListenersToControllers();
          _isLoading = false;
          _errorMessage = null;
          _hasUnsavedChanges = false;
        });
        _entryAnimController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Failed to load configurations: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  void _addListenersToControllers() {
    if (_systemConfig == null) return;
    void setUnsavedChanges() {
      if (!_hasUnsavedChanges && mounted) {
        setState(() => _hasUnsavedChanges = true);
      }
    }

    for (var cylConfig in _systemConfig!.cylinderConfigs) {
      cylConfig.priceController.addListener(setUnsavedChanges);
      cylConfig.weightController.addListener(setUnsavedChanges);
    }
    _systemConfig!.feeConfig.baseDeliveryFeeController
        .addListener(setUnsavedChanges);
    _systemConfig!.feeConfig.expressDeliverySurchargeController
        .addListener(setUnsavedChanges);
    _systemConfig!.feeConfig.vatPercentageController
        .addListener(setUnsavedChanges);
    _systemConfig!.feeConfig.serviceFeePercentageController
        .addListener(setUnsavedChanges);
    _systemConfig!.routingConfig.maxPickupWindowMinutesController
        .addListener(setUnsavedChanges);
    _systemConfig!.routingConfig.maxBatchWeightKgController
        .addListener(setUnsavedChanges);
  }

  Future<void> _handleSaveChanges() async {
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) {
      _showFeedbackSnackbar('Please correct the errors in the form.',
          isError: true);
      return;
    }
    if (_systemConfig == null) return;
    setState(() => _isSaving = true);

    try {
      // **FIXED**: Pass the non-nullable _systemConfig! to the updated ApiService method
      await _apiService.updateSystemConfig(_systemConfig!);
      if (mounted) {
        _showFeedbackSnackbar('System configurations updated successfully!');
        setState(() => _hasUnsavedChanges = false);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(
            'Error: ${e.toString().replaceFirst("Exception: ", "")}',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addNewCylinderDialog() async {
    final newCylinderLabelController = TextEditingController();
    final newCylinderPriceController = TextEditingController();
    final newCylinderWeightController = TextEditingController();
    final newCylinderIdController =
        TextEditingController(); // e.g. gc_custom_size
    final formKey = GlobalKey<FormState>();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    CylinderConfigItem? newCylinder = await showDialog<CylinderConfigItem>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: themeProvider.cardBackground,
            title: Text("Add New Cylinder Type",
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600)),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomInput(
                      controller: newCylinderIdController,
                      labelText: "ID*",
                      hintText: "e.g., gc_10kg (unique)",
                      validator: (v) =>
                          v!.trim().isEmpty ? "ID is required" : null),
                  SizedBox(height: 8),
                  CustomInput(
                      controller: newCylinderLabelController,
                      labelText: "Size Label*",
                      hintText: "e.g., 10 KG",
                      validator: (v) =>
                          v!.trim().isEmpty ? "Label is required" : null),
                  SizedBox(height: 8),
                  CustomInput(
                      controller: newCylinderPriceController,
                      labelText: "Price (₦)*",
                      keyboardType: TextInputType.number,
                      prefixText: "₦",
                      validator: (v) => (v!.isEmpty ||
                              double.tryParse(v) == null ||
                              double.parse(v) <= 0)
                          ? "Valid price"
                          : null),
                  SizedBox(height: 8),
                  CustomInput(
                      controller: newCylinderWeightController,
                      labelText: "Weight (kg)*",
                      keyboardType: TextInputType.number,
                      suffixText: "kg",
                      validator: (v) => (v!.isEmpty ||
                              double.tryParse(v) == null ||
                              double.parse(v) <= 0)
                          ? "Valid kg"
                          : null),
                ],
              )),
            ),
            actions: [
              TextButton(
                  child: Text("Cancel",
                      style: GoogleFonts.inter(
                          color: themeProvider.secondaryText)),
                  onPressed: () => Navigator.of(dialogContext).pop()),
              CustomButton(
                  text: "Add Cylinder",
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(dialogContext).pop(CylinderConfigItem(
                          id: newCylinderIdController.text.trim(),
                          sizeLabel: newCylinderLabelController.text.trim(),
                          initialPrice:
                              double.parse(newCylinderPriceController.text),
                          initialWeight:
                              double.parse(newCylinderWeightController.text),
                          isActive: true // Default to active
                          ));
                    }
                  },
                  color: themeProvider.gas2doorTeal)
            ],
          );
        });

    if (newCylinder != null && mounted) {
      // In a real app, you would likely call a specific backend endpoint to add a new cylinder type
      // For now, we add to local list and expect full config save to handle it
      setState(() {
        _systemConfig!.cylinderConfigs.add(newCylinder);
        newCylinder.priceController.addListener(() {
          if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
        });
        newCylinder.weightController.addListener(() {
          if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
        });
        _hasUnsavedChanges = true;
      });
      _showFeedbackSnackbar(
          "${newCylinder.sizeLabel} added. Save changes to persist.");
    }
    newCylinderLabelController.dispose();
    newCylinderPriceController.dispose();
    newCylinderWeightController.dispose();
    newCylinderIdController.dispose();
  }

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
              color: isError
                  ? themeProvider.infoColorOnDarkBgs
                  : themeProvider.infoColorOnDarkBgs),
        ),
        backgroundColor:
            isError ? themeProvider.errorColor : themeProvider.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          final themeProvider = Provider.of<ThemeProvider>(context);
          return AlertDialog(
            backgroundColor: themeProvider.cardBackground,
            title: Text('Discard Changes?',
                style: GoogleFonts.inter(color: themeProvider.primaryText)),
            content: Text(
                'You have unsaved changes. Are you sure you want to leave?',
                style: GoogleFonts.inter(color: themeProvider.secondaryText)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('No',
                    style: GoogleFonts.inter(color: themeProvider.errorColor)),
              ),
              CustomButton(
                text: "Yes",
                onPressed: () => Navigator.of(context).pop(true),
                color: themeProvider.gas2doorTeal,
              ),
            ],
          );
        },
      );
      return confirm ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color adminAccentColor = themeProvider.gas2doorPurple;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: themeProvider.appSecondaryBackground,
        appBar: AppBar(
          backgroundColor: themeProvider.cardBackground,
          elevation: 1.0,
          title: Text('System Configuration',
              style: GoogleFonts.inter(
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 18)),
          leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: themeProvider.primaryText),
              onPressed: () async {
                if (await _onWillPop()) {
                  Navigator.of(context).pop();
                }
              }),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _isSaving
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5)))
                  : TextButton(
                      onPressed: _hasUnsavedChanges ? _handleSaveChanges : null,
                      style: TextButton.styleFrom(
                          foregroundColor: _hasUnsavedChanges
                              ? adminAccentColor
                              : themeProvider.tertiaryText.withOpacity(0.5)),
                      child: Text('SAVE',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
            ),
          ],
        ),
        body: _isLoading || _systemConfig == null
            ? Center(child: CircularProgressIndicator(color: adminAccentColor))
            : _errorMessage != null
                ? _buildErrorState(themeProvider)
                : FadeTransition(
                    opacity: _entryAnimController,
                    child: Form(
                      key: _formKey,
                      onChanged: () {
                        if (!_hasUnsavedChanges && mounted)
                          setState(() => _hasUnsavedChanges = true);
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: <Widget>[
                          SlideTransition(
                              position: _sectionSlideAnimations[0],
                              child: _buildCylinderPricingSection(themeProvider,
                                  _systemConfig!.cylinderConfigs)),
                          const SizedBox(height: 20),
                          SlideTransition(
                              position: _sectionSlideAnimations[1],
                              child: _buildFeesSection(
                                  themeProvider, _systemConfig!.feeConfig)),
                          const SizedBox(height: 20),
                          SlideTransition(
                              position: _sectionSlideAnimations[2],
                              child: _buildRoutingConfigSection(
                                  themeProvider, _systemConfig!.routingConfig)),
                          const SizedBox(height: 80), // For FAB
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildCylinderPricingSection(
      ThemeProvider themeProvider, List<CylinderConfigItem> cylinderConfigs) {
    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Cylinder Pricing & Availability",
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.primaryText)),
                  IconButton(
                      icon: Icon(Icons.add_circle_outline,
                          color: themeProvider.gas2doorTeal),
                      onPressed: _addNewCylinderDialog,
                      tooltip: "Add New Cylinder Type")
                ],
              ),
              const SizedBox(height: 12),
              if (cylinderConfigs.isEmpty)
                Text("No cylinder types configured. Click '+' to add.",
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
              ...cylinderConfigs
                  .map((cylConfig) => Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                                flex: 3,
                                child: Text(cylConfig.sizeLabel,
                                    style: GoogleFonts.inter(
                                        color: themeProvider.primaryText,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15))),
                            const SizedBox(width: 10),
                            Expanded(
                                flex: 3,
                                child: CustomInput(
                                    controller: cylConfig.priceController,
                                    labelText: "Price (₦)",
                                    keyboardType: TextInputType.number,
                                    prefixText: "₦",
                                    validator: (v) => (v == null ||
                                            v.isEmpty ||
                                            double.tryParse(v) == null ||
                                            double.parse(v) <= 0)
                                        ? "Valid price"
                                        : null)),
                            const SizedBox(width: 10),
                            Expanded(
                                flex: 3,
                                child: CustomInput(
                                    controller: cylConfig.weightController,
                                    labelText: "Weight (kg)",
                                    keyboardType: TextInputType.number,
                                    suffixText: "kg",
                                    validator: (v) => (v == null ||
                                            v.isEmpty ||
                                            double.tryParse(v) == null ||
                                            double.parse(v) <= 0)
                                        ? "Valid kg"
                                        : null)),
                            const SizedBox(width: 10),
                            Column(children: [
                              Text("Active",
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: themeProvider.tertiaryText)),
                              Switch.adaptive(
                                  value: cylConfig.isActive,
                                  onChanged: (val) => setState(() {
                                        cylConfig.isActive = val;
                                        _hasUnsavedChanges = true;
                                      }),
                                  activeColor: themeProvider.gas2doorTeal)
                            ])
                          ],
                        ),
                      ))
                  .toList(),
            ],
          ),
        ));
  }

  Widget _buildFeesSection(ThemeProvider themeProvider, FeeConfig feeConfig) {
    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Fees & Charges",
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryText)),
              const SizedBox(height: 16),
              CustomInput(
                  controller: feeConfig.baseDeliveryFeeController,
                  labelText: "Base Delivery Fee (₦)",
                  keyboardType: TextInputType.number,
                  prefixText: "₦",
                  validator: (v) => (v == null ||
                          v.isEmpty ||
                          double.tryParse(v) == null ||
                          double.parse(v) < 0)
                      ? "Valid fee"
                      : null),
              const SizedBox(height: 12),
              CustomInput(
                  controller: feeConfig.expressDeliverySurchargeController,
                  labelText: "Express Delivery Surcharge (₦)",
                  keyboardType: TextInputType.number,
                  prefixText: "₦",
                  validator: (v) => (v == null ||
                          v.isEmpty ||
                          double.tryParse(v) == null ||
                          double.parse(v) < 0)
                      ? "Valid fee"
                      : null),
              const SizedBox(height: 12),
              CustomInput(
                  controller: feeConfig.vatPercentageController,
                  labelText: "VAT (%)",
                  keyboardType: TextInputType.number,
                  suffixText: "%",
                  validator: (v) => (v == null ||
                          v.isEmpty ||
                          double.tryParse(v) == null ||
                          double.parse(v) < 0 ||
                          double.parse(v) > 100)
                      ? "0-100"
                      : null),
              const SizedBox(height: 12),
              CustomInput(
                  controller: feeConfig.serviceFeePercentageController,
                  labelText: "Service Fee (%)",
                  keyboardType: TextInputType.number,
                  suffixText: "%",
                  validator: (v) => (v == null ||
                          v.isEmpty ||
                          double.tryParse(v) == null ||
                          double.parse(v) < 0 ||
                          double.parse(v) > 100)
                      ? "0-100"
                      : null),
            ],
          ),
        ));
  }

  Widget _buildRoutingConfigSection(
      ThemeProvider themeProvider, RoutingConfig routingConfig) {
    return CustomCard(
        color: themeProvider.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Pickup Run Configuration",
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryText)),
              const SizedBox(height: 16),
              CustomInput(
                  controller: routingConfig.maxPickupWindowMinutesController,
                  labelText: "Max Pickup Window (minutes)*",
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.timelapse_rounded,
                  validator: (v) => (v == null ||
                          v.isEmpty ||
                          int.tryParse(v) == null ||
                          int.parse(v) <= 0)
                      ? "Valid minutes"
                      : null),
              const SizedBox(height: 12),
              CustomInput(
                  controller: routingConfig.maxBatchWeightKgController,
                  labelText: "Max Batch Weight (kg)*",
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.scale_outlined,
                  suffixText: "kg",
                  validator: (v) => (v == null ||
                          v.isEmpty ||
                          double.tryParse(v) == null ||
                          double.parse(v) <= 0)
                      ? "Valid kg"
                      : null),
              const SizedBox(height: 12),
              Text(
                  "Note: Average driver speed and service times are now determined automatically by the routing system using real-world data and mapping services.",
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: themeProvider.tertiaryText,
                      fontStyle: FontStyle.italic))
            ],
          ),
        ));
  }

  Widget _buildErrorState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_applications_outlined,
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Could Not Load Configurations',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Please check your connection and try again.',
                style: GoogleFonts.inter(
                    color: themeProvider.secondaryText, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            CustomButton(
                text: "Retry",
                onPressed: _loadSystemConfigs,
                color: themeProvider.gas2doorPrimaryBlue,
                icon: Icon(Icons.refresh_rounded,
                    color: themeProvider.infoColorOnDarkBgs)),
          ],
        ),
      ),
    );
  }
}
