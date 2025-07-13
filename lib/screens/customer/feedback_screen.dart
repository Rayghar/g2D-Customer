// File: lib/screens/customer/feedback_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../widgets/card.dart'; // For overall structure if needed

// Mock Feedback Service
class MockFeedbackService {
  Future<bool> submitFeedback(
      {required String orderId,
      required int rating,
      String? comment,
      required String customerId}) async {
    print(
        "MockFeedbackService: Submitting feedback for Order $orderId by $customerId - Rating: $rating, Comment: $comment");
    await Future.delayed(const Duration(seconds: 1));
    return true; // Simulate success
  }
}

class FeedbackScreen extends StatefulWidget {
  static const String routeName = '/feedback';
  final String orderId;
  // final String customerId; // Should be fetched from AuthProvider or passed if necessary

  const FeedbackScreen({
    super.key,
    required this.orderId,
    // required this.customerId,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with TickerProviderStateMixin {
  final _formKey =
      GlobalKey<FormState>(); // Can be used if more fields are added
  final TextEditingController _commentController = TextEditingController();
  double _selectedRating = 0;
  bool _isLoading = false;

  late AnimationController _entryAnimController;
  late Animation<double> _fadeAnimation;
  late List<Animation<Offset>> _slideAnimations;

  final MockFeedbackService _feedbackService = MockFeedbackService();
  final String _mockCustomerId = "cust_abc_123"; // Placeholder

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
          Navigator.pop(
              context, true); // Pop with true if feedback was submitted
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
    /* ... same as before ... */
  }

  Widget _buildStarRating(ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final ratingValue = index + 1;
        final bool isSelected = ratingValue <= _selectedRating;
        return Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 6.0), // Adjusted spacing
          child: IconButton(
            icon: Icon(
              isSelected ? Icons.star_rounded : Icons.star_border_rounded,
              color: isSelected
                  ? themeProvider.warningColor
                  : themeProvider.tertiaryText.withOpacity(0.7),
              size: 44, // Larger stars
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
            // Form can be useful if more validated fields are added
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // Center content
              children: [
                SlideTransition(
                    position: _slideAnimations[0],
                    child: Column(children: [
                      Text('How was your experience?',
                          style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: themeProvider
                                  .primaryText)), // More engaging title
                      const SizedBox(height: 10),
                      Text(
                          'Your feedback helps us improve our service for everyone.',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              color: themeProvider.secondaryText,
                              height: 1.4),
                          textAlign: TextAlign.center),
                    ])),
                const SizedBox(height: 32),
                SlideTransition(
                    position: _slideAnimations[1],
                    child: Column(children: [
                      Text('Select Your Rating',
                          style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: themeProvider.primaryText)),
                      const SizedBox(height: 16),
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
                    ])),
                const SizedBox(height: 32),
                SlideTransition(
                    position: _slideAnimations[2],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Additional Comments (Optional)',
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: themeProvider.primaryText)),
                        const SizedBox(height: 10),
                        CustomInput(
                          controller: _commentController,
                          hintText:
                              'Share more details about what you liked or what could be improved...',
                          keyboardType: TextInputType.multiline, maxLines: 5,
                          minLines: 3,
                          textInputAction: TextInputAction.newline,
                          fillColor: themeProvider
                              .cardBackground, // Make input background match cards
                        ),
                      ],
                    )),
                const SizedBox(height: 32),
                CustomButton(
                  text: _isLoading ? 'Submitting...' : 'Submit Feedback',
                  onPressed: _isLoading ? null : _handleSubmitFeedback,
                  color: themeProvider.gas2doorPrimaryBlue,
                  height: 52,
                  borderRadius: themeProvider.cardBorderRadiusValue,
                  icon: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  themeProvider.infoColorOnDarkBgs)))
                      : Icon(Icons.send_rounded,
                          color: themeProvider.infoColorOnDarkBgs, size: 20),
                  textStyle: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.infoColorOnDarkBgs),
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
