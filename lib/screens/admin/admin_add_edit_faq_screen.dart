// File: lib/screens/admin/admin_add_edit_faq_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../models/admin/faq_item_model.dart'; // Using the defined model
// Assuming AdminFaqManagementScreen uses MockAdminFaqService which has create/update methods
import './admin_faq_management_screen.dart' show MockAdminFaqService;

class AdminAddEditFaqScreen extends StatefulWidget {
  static const String routeName = '/admin_add_edit_faq';
  final FaqItemModel? faq; // Null if adding new

  const AdminAddEditFaqScreen({super.key, this.faq});

  @override
  State<AdminAddEditFaqScreen> createState() => _AdminAddEditFaqScreenState();
}

class _AdminAddEditFaqScreenState extends State<AdminAddEditFaqScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;

  late TextEditingController _questionController;
  late TextEditingController _answerController;
  late TextEditingController _displayOrderController;
  late TextEditingController _categoryController; // Optional
  bool _isActive = true;

  // Using the mock service from AdminFaqManagementScreen for consistency in this example
  final MockAdminFaqService _faqService = MockAdminFaqService();

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.faq != null;

    _questionController =
        TextEditingController(text: widget.faq?.question ?? '');
    _answerController = TextEditingController(text: widget.faq?.answer ?? '');
    _displayOrderController =
        TextEditingController(text: widget.faq?.displayOrder.toString() ?? '0');
    _categoryController =
        TextEditingController(text: widget.faq?.category ?? '');
    _isActive = widget.faq?.isActive ?? true;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _displayOrderController.dispose();
    _categoryController.dispose();
    super.dispose();
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

    final faqData = {
      'question': _questionController.text.trim(),
      'answer': _answerController.text.trim(),
      'displayOrder': int.tryParse(_displayOrderController.text.trim()) ?? 0,
      'category': _categoryController.text.trim().isNotEmpty
          ? _categoryController.text.trim()
          : null,
      'isActive': _isActive,
    };

    try {
      if (_isEditMode && widget.faq != null) {
        await _faqService.updateFaq(widget.faq!.id, faqData);
        _showFeedbackSnackbar('FAQ updated successfully!');
      } else {
        await _faqService.createFaq(faqData);
        _showFeedbackSnackbar('FAQ created successfully!');
      }
      if (mounted)
        Navigator.pop(context, true); // Pop with result true to refresh list
    } catch (e) {
      if (mounted)
        _showFeedbackSnackbar('Failed to save FAQ: ${e.toString()}',
            isError: true);
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
    final String appBarTitle = _isEditMode ? "Edit FAQ" : "Add New FAQ";

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
                    child: Text('SAVE',
                        style: GoogleFonts.inter(
                            color: themeProvider.gas2doorPurple,
                            fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CustomInput(
                  controller: _questionController,
                  labelText: 'Question*',
                  hintText: 'Enter the FAQ question',
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Question is required' : null),
              const SizedBox(height: 16),
              CustomInput(
                  controller: _answerController,
                  labelText: 'Answer*',
                  hintText: 'Enter the FAQ answer',
                  maxLines: 5,
                  minLines: 3,
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Answer is required' : null),
              const SizedBox(height: 16),
              CustomInput(
                  controller: _displayOrderController,
                  labelText: 'Display Order (Optional)',
                  hintText: 'e.g., 1, 2, 3...',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v!.isNotEmpty && int.tryParse(v) == null)
                      return 'Must be a number';
                    return null;
                  }),
              const SizedBox(height: 16),
              CustomInput(
                  controller: _categoryController,
                  labelText: 'Category (Optional)',
                  hintText: 'e.g., Account, Payment, Delivery'),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                title: Text('Active',
                    style: GoogleFonts.inter(color: themeProvider.primaryText)),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
                activeColor: themeProvider.gas2doorTeal,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
