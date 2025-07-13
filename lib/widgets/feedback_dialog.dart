// lib/widgets/feedback_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../widgets/button.dart';
import '../widgets/input.dart';
import '../models/feedback.dart' as app_feedback;

class FeedbackDialog extends StatefulWidget {
  final String orderId;
  final String customerId;
  final VoidCallback onFeedbackSubmitted;

  const FeedbackDialog({
    super.key,
    required this.orderId,
    required this.customerId,
    required this.onFeedbackSubmitted,
  });

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final TextEditingController _commentController = TextEditingController();
  double _selectedRating = 0;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  Future<void> _handleSubmitFeedback() async {
    HapticFeedback.mediumImpact();
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a star rating.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final feedbackData = app_feedback.Feedback(
        id: '',
        orderId: widget.orderId,
        rating: _selectedRating.toInt(),
        comment: _commentController.text.trim(),
      );

      await _apiService.submitFeedback(widget.orderId, feedbackData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Thank you for your valuable feedback!'),
          backgroundColor: Colors.green,
        ));
        widget.onFeedbackSubmitted();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error submitting feedback: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      // <<< FIX: Ensure loading state is always turned off, even on error. >>>
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStarRating(ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final ratingValue = index + 1;
        final bool isSelected = ratingValue <= _selectedRating;

        // <<< FIX: Wrap IconButton in Flexible to prevent UI overflow. >>>
        return Flexible(
          child: IconButton(
            icon: Icon(
              isSelected ? Icons.star_rounded : Icons.star_border_rounded,
              color: isSelected
                  ? themeProvider.warningColor
                  : themeProvider.tertiaryText.withOpacity(0.7),
              size: 40,
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: themeProvider.cardBackground,
      title: Text('Rate Your Delivery',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.bold, color: themeProvider.primaryText)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('How was your experience with this order?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: themeProvider.secondaryText)),
            const SizedBox(height: 20),
            _buildStarRating(themeProvider),
            const SizedBox(height: 24),
            CustomInput(
              controller: _commentController,
              labelText: "Additional Comments (Optional)",
              hintText: 'What did you like or dislike?',
              minLines: 3,
              maxLines: 5,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Maybe Later',
              style: GoogleFonts.inter(color: themeProvider.secondaryText)),
        ),
        CustomButton(
          text: _isLoading ? 'Submitting...' : 'Submit',
          onPressed: _isLoading ? null : _handleSubmitFeedback,
          color: themeProvider.gas2doorPrimaryBlue,
          height: 40,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : null,
        )
      ],
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }
}
