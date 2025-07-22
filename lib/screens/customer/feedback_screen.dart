// File: lib/screens/customer/feedback_screen.dart
// ADVISORY: This file has been updated to align with the new theme strategy.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../widgets/card.dart';

// Mock Feedback Service
class MockFeedbackService {
  Future<bool> submitFeedback(
      {required String orderId,
      required int rating,
      String? comment,
      required String customerId}) async {
    await Future.delayed(const Duration(seconds: 1));
    return true; // Simulate success
  }
}

class FeedbackScreen extends StatefulWidget {
  static const String routeName = '/feedback';
  final String orderId;

  const FeedbackScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _commentController = TextEditingController();
  double _selectedRating = 0;
  bool _isLoading = false;

  late AnimationController _entryAnimController;
  late Animation<double> _fadeAnimation;
  late List<Animation<Offset>> _slideAnimations;

  final MockFeedbackService _feedbackService = MockFeedbackService();
  final String _mockCustomerId = "cust_abc_123";

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entryAnimController, curve: Curves.easeIn));
    _slideAnimations = List.generate(
        3,
        (index) => Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _entryAnimController,
                curve:
                    Interval(0.2 * index, 1.0, curve: Curves.easeOutCubic))));
    _entryAnimController.forward();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitFeedback() async {
    HapticFeedback.mediumImpact();
    if (_selectedRating == 0) {
      _showFeedbackSnackbar('Please select a star rating.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final success = await _feedbackService.submitFeedback(
        orderId: widget.orderId,
        rating: _selectedRating.toInt(),
        comment: _commentController.text.trim().isNotEmpty
            ? _commentController.text.trim()
            : null,
        customerId: _mockCustomerId,
      );
      if (mounted) {
        if (success) {
          _showFeedbackSnackbar('Thank you for your valuable feedback!');
          Navigator.pop(context, true);
        } else {
          _showFeedbackSnackbar('Failed to submit feedback. Please try again.',
              isError: true);
        }
      }
    } catch (e) {
      if (mounted)
        _showFeedbackSnackbar('Error submitting feedback: ${e.toString()}',
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
        backgroundColor:
            isError ? themeProvider.errorColor : themeProvider.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildStarRating(ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final ratingValue = index + 1;
        final bool isSelected = ratingValue <= _selectedRating;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: IconButton(
            icon: Icon(
              isSelected ? Icons.star_rounded : Icons.star_border_rounded,
              color: isSelected
                  ? themeProvider.warningColor
                  : themeProvider.tertiaryText.withOpacity(0.7),
              size: 44,
            ),
            onPressed: _isLoading
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedRating = ratingValue.toDouble());
                  },
            splashRadius: 30,
            tooltip: "$ratingValue Star${ratingValue == 1 ? '' : 's'}",
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final shortOrderId = widget.orderId.length > 6
        ? widget.orderId.substring(widget.orderId.length - 6)
        : widget.orderId;

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text('Rate Order #$shortOrderId',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: themeProvider.primaryText),
            onPressed: () => Navigator.of(context).pop()),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch button
              children: [
                SlideTransition(
                  position: _slideAnimations[0],
                  child: CustomCard(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text('How was your experience?',
                              style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.primaryText)),
                          const SizedBox(height: 10),
                          Text(
                              'Your feedback helps us improve our service for everyone.',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: themeProvider.secondaryText,
                                  height: 1.4),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          _buildStarRating(themeProvider),
                          if (_selectedRating > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Text(
                                  "${_selectedRating.toInt()} out of 5 Stars",
                                  style: GoogleFonts.inter(
                                      color: themeProvider.warningColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SlideTransition(
                    position: _slideAnimations[1],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text('Additional Comments (Optional)',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: themeProvider.primaryText)),
                        ),
                        const SizedBox(height: 10),
                        CustomInput(
                          controller: _commentController,
                          hintText: 'Share more details about your delivery...',
                          keyboardType: TextInputType.multiline,
                          maxLines: 5,
                          minLines: 3,
                          textInputAction: TextInputAction.newline,
                          fillColor: themeProvider.cardBackground,
                        ),
                      ],
                    )),
                const SizedBox(height: 32),
                SlideTransition(
                  position: _slideAnimations[2],
                  child: CustomButton(
                    text: _isLoading ? 'Submitting...' : 'Submit Feedback',
                    onPressed: _isLoading ? null : _handleSubmitFeedback,
                    // MODIFIED: Use primary brand blue for consistent CTA
                    color: themeProvider.gas2doorPrimaryBlue,
                    height: 52,
                    borderRadius: themeProvider.cardBorderRadiusValue,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white)))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
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
