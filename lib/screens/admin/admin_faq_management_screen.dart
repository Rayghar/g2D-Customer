// File: lib/screens/admin/admin_faq_management_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
// Import the defined model
import '../../models/admin/faq_item_model.dart';
// Import the new Add/Edit screen (we'll create a basic version next)
import './admin_add_edit_faq_screen.dart';

// Mock AdminFaqService - Replace with actual service
class MockAdminFaqService {
  List<FaqItemModel> _mockFaqsDb = [
    FaqItemModel(
        id: "faq001",
        question: "How do I reset my password?",
        answer:
            "Go to the login screen and tap 'Forgot Password'. Follow the instructions sent to your email.",
        displayOrder: 1,
        isActive: true,
        category: "Account"),
    FaqItemModel(
        id: "faq002",
        question: "What payment methods are accepted?",
        answer:
            "We accept major credit/debit cards and bank transfers. Pay on delivery is available in select areas.",
        displayOrder: 2,
        isActive: true,
        category: "Payment"),
    FaqItemModel(
        id: "faq003",
        question: "How long does delivery usually take?",
        answer:
            "Standard delivery is 1-3 hours. Express delivery aims for under 60 minutes.",
        displayOrder: 3,
        isActive: false,
        category: "Delivery"),
    FaqItemModel(
        id: "faq004",
        question: "Can I change my delivery address after placing an order?",
        answer:
            "Address changes are possible if the order has not yet been dispatched. Please contact support immediately.",
        displayOrder: 4,
        isActive: true,
        category: "Orders"),
  ];

  Future<List<FaqItemModel>> getAllFaqs() async {
    print("Mock AdminFaqService: Fetching all FAQs.");
    await Future.delayed(const Duration(milliseconds: 700));
    // Return a copy to prevent direct modification of the mock DB
    return List<FaqItemModel>.from(
        _mockFaqsDb.map((faq) => FaqItemModel.fromJson(faq.toJson())));
  }

  Future<FaqItemModel> createFaq(Map<String, dynamic> faqData) async {
    print("Mock AdminFaqService: Creating FAQ: $faqData");
    await Future.delayed(const Duration(milliseconds: 500));
    final newFaq = FaqItemModel.fromJson(
        {...faqData, 'id': 'faq_new_${DateTime.now().millisecondsSinceEpoch}'});
    _mockFaqsDb.add(newFaq);
    return newFaq;
  }

  Future<FaqItemModel> updateFaq(
      String faqId, Map<String, dynamic> faqData) async {
    print("Mock AdminFaqService: Updating FAQ $faqId: $faqData");
    await Future.delayed(const Duration(milliseconds: 500));
    int index = _mockFaqsDb.indexWhere((f) => f.id == faqId);
    if (index != -1) {
      _mockFaqsDb[index] = FaqItemModel.fromJson({
        ..._mockFaqsDb[index]
            .toJson(), // Keep existing fields not being updated
        ...faqData, // Apply updates
        'id': faqId, // Ensure ID is preserved
      });
      return _mockFaqsDb[index];
    }
    throw Exception("FAQ not found for update");
  }

  Future<bool> updateFaqStatus(String faqId, bool newStatus) async {
    print("Mock AdminFaqService: Updating FAQ $faqId status to $newStatus");
    await Future.delayed(const Duration(milliseconds: 300));
    int index = _mockFaqsDb.indexWhere((f) => f.id == faqId);
    if (index != -1) {
      _mockFaqsDb[index].isActive = newStatus;
      return true;
    }
    return false;
  }

  Future<bool> deleteFaq(String faqId) async {
    print("Mock AdminFaqService: Deleting FAQ $faqId");
    await Future.delayed(const Duration(milliseconds: 500));
    _mockFaqsDb.removeWhere((f) => f.id == faqId);
    return true;
  }
}

class AdminFaqManagementScreen extends StatefulWidget {
  static const String routeName = '/admin_faq_management';
  const AdminFaqManagementScreen({super.key});

  @override
  State<AdminFaqManagementScreen> createState() =>
      _AdminFaqManagementScreenState();
}

class _AdminFaqManagementScreenState extends State<AdminFaqManagementScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<FaqItemModel> _faqs = [];
  String? _errorMessage;

  late AnimationController _listAnimationController;
  final MockAdminFaqService _faqService = MockAdminFaqService();

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fetchFaqs();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchFaqs({bool isRefresh = false}) async {
    if (!mounted) return;
    if (!isRefresh && _faqs.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (isRefresh) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final fetchedFaqs = await _faqService.getAllFaqs();
      if (mounted) {
        // Sort by displayOrder, then by question for consistent display
        fetchedFaqs.sort((a, b) {
          int orderCompare = a.displayOrder.compareTo(b.displayOrder);
          if (orderCompare != 0) return orderCompare;
          return a.question.toLowerCase().compareTo(b.question.toLowerCase());
        });
        setState(() {
          _faqs = fetchedFaqs;
          _isLoading = false;
          _errorMessage = null;
        });
        if (_faqs.isNotEmpty) {
          _listAnimationController.reset();
          _listAnimationController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load FAQs: ${e.toString()}";
        });
      }
    }
  }

  void _navigateToAddEditFaqScreen({FaqItemModel? faq}) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.pushNamed(
      context,
      AdminAddEditFaqScreen.routeName,
      arguments: {'faq': faq}, // Pass FaqItemModel directly
    );
    if (result == true && mounted) {
      _fetchFaqs(isRefresh: true);
    }
  }

  Future<void> _handleDeleteFaq(
      String faqId, String question, ThemeProvider themeProvider) async {
    HapticFeedback.mediumImpact();
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: themeProvider.cardBackground,
          shape: RoundedRectangleBorder(
              borderRadius: themeProvider.cardBorderRadius),
          title: Text('Delete FAQ?',
              style: GoogleFonts.inter(
                  color: themeProvider.primaryText,
                  fontWeight: FontWeight.w600)),
          content: Text('Are you sure you want to delete the FAQ: "$question"?',
              style: GoogleFonts.inter(color: themeProvider.secondaryText)),
          actions: <Widget>[
            TextButton(
                child: Text('Cancel',
                    style:
                        GoogleFonts.inter(color: themeProvider.secondaryText)),
                onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
                child: Text('Delete',
                    style: GoogleFonts.inter(
                        color: themeProvider.errorColor,
                        fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      setState(() => _isLoading = true);
      try {
        final success = await _faqService.deleteFaq(faqId);
        if (mounted) {
          if (success) {
            _showFeedbackSnackbar('FAQ "$question" deleted successfully.');
            _fetchFaqs(isRefresh: true);
          } else {
            _showFeedbackSnackbar('Failed to delete FAQ.', isError: true);
            setState(() => _isLoading = false);
          }
        }
      } catch (e) {
        if (mounted) {
          _showFeedbackSnackbar("Error: ${e.toString()}", isError: true);
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _toggleFaqStatus(FaqItemModel faq, bool newStatus) async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      final success = await _faqService.updateFaqStatus(faq.id, newStatus);
      if (mounted) {
        if (success) {
          _showFeedbackSnackbar(
              'FAQ "${faq.question.truncate(20)}" ${newStatus ? "activated" : "deactivated"}.');
          _fetchFaqs(
              isRefresh: true); // Refresh to get the updated list from "source"
        } else {
          _showFeedbackSnackbar('Failed to update status.', isError: true);
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar("Error: ${e.toString()}", isError: true);
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
    final Color adminAccentColor = themeProvider.gas2doorPurple;

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        title: Text('Manage FAQs',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: themeProvider.primaryText),
            onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
              icon: Icon(Icons.add_comment_outlined,
                  color: adminAccentColor, size: 26),
              onPressed: () => _navigateToAddEditFaqScreen(),
              tooltip: "Add New FAQ"),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchFaqs(isRefresh: true),
        color: adminAccentColor,
        backgroundColor: themeProvider.cardBackground,
        child: _buildBody(themeProvider),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditFaqScreen(),
        backgroundColor: adminAccentColor,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: "Add New FAQ",
      ),
    );
  }

  Widget _buildBody(ThemeProvider themeProvider) {
    if (_isLoading && _faqs.isEmpty) return _buildLoadingShimmer(themeProvider);
    if (_errorMessage != null) return _buildErrorState(themeProvider);
    if (_faqs.isEmpty) return _buildEmptyState(themeProvider);

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _faqs.length,
      itemBuilder: (context, index) {
        final faq = _faqs[index];
        final itemAnimation =
            Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                .animate(
          CurvedAnimation(
              parent: _listAnimationController,
              curve: Interval((0.05 * index).clamp(0.0, 1.0),
                  (0.5 + 0.05 * index).clamp(0.0, 1.0),
                  curve: Curves.easeOutCubic)),
        );
        return FadeTransition(
          opacity: _listAnimationController,
          child: SlideTransition(
            position: itemAnimation,
            child: _AdminFaqListItemWidget(
              faq: faq,
              themeProvider: themeProvider,
              onTap: () => _navigateToAddEditFaqScreen(faq: faq),
              onToggleStatus: (newStatus) => _toggleFaqStatus(faq, newStatus),
              onDelete: () =>
                  _handleDeleteFaq(faq.id, faq.question, themeProvider),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingShimmer(ThemeProvider themeProvider) {
    /* ... same as before ... */
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: 5,
      itemBuilder: (context, index) {
        return CustomCard(
          margin: const EdgeInsets.only(bottom: 12.0),
          color: themeProvider.cardBackground,
          borderRadius: themeProvider.cardBorderRadiusValue,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonLine(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: 18,
                    themeProvider: themeProvider),
                const SizedBox(height: 8),
                _buildSkeletonLine(
                    width: double.infinity,
                    height: 14,
                    themeProvider: themeProvider),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  _buildSkeletonLine(
                      width: 30,
                      height: 30,
                      themeProvider: themeProvider,
                      borderRadius: 4),
                  const SizedBox(width: 10),
                  _buildSkeletonLine(
                      width: 30,
                      height: 30,
                      themeProvider: themeProvider,
                      borderRadius: 4),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLine(
      {required double width,
      required double height,
      required ThemeProvider themeProvider,
      double borderRadius = 4}) {
    /* ... same as before ... */
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.grey[700]!.withOpacity(0.6)
            : Colors.grey[300]!,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider) {
    /* ... same as before ... */
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined,
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Failed to Load FAQs',
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
                onPressed: () => _fetchFaqs(isRefresh: true),
                color: themeProvider.gas2doorPrimaryBlue,
                icon: Icon(Icons.refresh_rounded,
                    color: themeProvider.infoColorOnDarkBgs)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider) {
    /* ... same as before ... */
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.help_outline_rounded,
                color: themeProvider.secondaryText.withOpacity(0.6), size: 80),
            const SizedBox(height: 24),
            Text('No FAQs Found',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            Text(
                'Tap the "+" button to add your first Frequently Asked Question.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    color: themeProvider.secondaryText,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _AdminFaqListItemWidget extends StatelessWidget {
  final FaqItemModel faq;
  final ThemeProvider themeProvider;
  final VoidCallback onTap;
  final Function(bool) onToggleStatus;
  final VoidCallback onDelete;

  const _AdminFaqListItemWidget({
    required this.faq,
    required this.themeProvider,
    required this.onTap,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 1.5,
      child: ExpansionTile(
        iconColor: themeProvider.primaryText,
        collapsedIconColor: themeProvider.secondaryText,
        backgroundColor: themeProvider.cardBackground,
        collapsedBackgroundColor: themeProvider.cardBackground,
        shape: RoundedRectangleBorder(
            borderRadius: themeProvider.cardBorderRadius),
        collapsedShape: RoundedRectangleBorder(
            borderRadius: themeProvider.cardBorderRadius),
        title: Text(faq.question,
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: themeProvider.primaryText),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            "Order: ${faq.displayOrder} | Status: ${faq.isActive ? 'Active' : 'Inactive'} ${faq.category != null ? '| Cat: ${faq.category}' : ''}",
            style: GoogleFonts.inter(
                fontSize: 12, color: themeProvider.tertiaryText),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(faq.answer,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: themeProvider.secondaryText,
                  height: 1.4)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: Icon(Icons.edit_outlined,
                    size: 18, color: themeProvider.gas2doorPrimaryBlue),
                label: Text("Edit",
                    style: GoogleFonts.inter(
                        color: themeProvider.gas2doorPrimaryBlue,
                        fontWeight: FontWeight.w500,
                        fontSize: 13)),
                onPressed: onTap,
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10)),
              ),
              const Spacer(), // Pushes switch and delete to the right more
              Text(faq.isActive ? "Active" : "Inactive",
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: faq.isActive
                          ? themeProvider.gas2doorTeal
                          : themeProvider.secondaryText)),
              Switch.adaptive(
                value: faq.isActive,
                onChanged: onToggleStatus,
                activeColor: themeProvider.gas2doorTeal,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              IconButton(
                icon: Icon(Icons.delete_forever_outlined,
                    color: themeProvider.errorColor.withOpacity(0.8), size: 20),
                onPressed: onDelete,
                tooltip: "Delete FAQ",
                splashRadius: 20,
              ),
            ],
          )
        ],
      ),
    );
  }
}

// Helper extension for string truncation
extension StringTruncateExtension on String {
  String truncate(int maxLength, {String omission = "..."}) {
    return (length <= maxLength)
        ? this
        : substring(0, maxLength - omission.length) + omission;
  }
}
