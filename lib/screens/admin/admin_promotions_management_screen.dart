// File: lib/screens/admin/admin_promotions_management_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../services/api_service.dart'; // Ensure ApiService is imported
import '../../models/admin/admin_promotion_model.dart';
import './admin_add_edit_promotion_screen.dart';

class AdminPromotionManagementScreen extends StatefulWidget {
  static const String routeName = '/admin_promotions';
  const AdminPromotionManagementScreen({super.key});

  @override
  State<AdminPromotionManagementScreen> createState() =>
      _AdminPromotionManagementScreenState();
}

class _AdminPromotionManagementScreenState
    extends State<AdminPromotionManagementScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService(); // Use the actual ApiService
  bool _isLoading = true;
  List<AdminPromotionModel> _promotions = [];
  String? _errorMessage;
  late AnimationController _listAnimationController;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fetchPromotions();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchPromotions({bool isRefresh = false}) async {
    if (!mounted) return;

    // Only show full loading indicator if it's not a refresh and list is empty
    if (!isRefresh && _promotions.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (isRefresh) {
      // For refreshes, just set loading to true to enable indicators (e.g., RefreshIndicator)
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final fetchedPromotions =
          await _apiService.adminGetPromotions(); // Use apiService
      if (mounted) {
        setState(() {
          _promotions = fetchedPromotions;
          _isLoading = false;
          _errorMessage = null;
        });
        if (_promotions.isNotEmpty) {
          _listAnimationController
              .reset(); // Reset to play animation every time
          _listAnimationController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Clean up the exception message for better readability
          _errorMessage =
              "Failed to load promotions: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  void _navigateToAddEditPromotionScreen(
      {AdminPromotionModel? promotion}) async {
    HapticFeedback.lightImpact(); // Add haptic feedback for user interaction
    final result = await Navigator.pushNamed(
      context,
      AdminAddEditPromotionScreen.routeName,
      arguments: {'promotion': promotion},
    );
    if (result == true && mounted) {
      _fetchPromotions(isRefresh: true);
    }
  }

  Future<void> _togglePromotionStatus(
      AdminPromotionModel promotion, bool newStatus) async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true); // Indicate activity
    try {
      await _apiService.adminUpdatePromotion(
          promotion.id, {'isActive': newStatus}); // Use apiService
      if (mounted) {
        _showFeedbackSnackbar(
            'Promotion "${promotion.title}" ${newStatus ? "activated" : "deactivated"}.');
        _fetchPromotions(isRefresh: true); // Refresh list to get latest status
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(
            "Error: ${e.toString().replaceFirst("Exception: ", "")}",
            isError: true);
        setState(() => _isLoading = false); // Stop loading on error
      }
    }
  }

  Future<void> _handleDeletePromotion(String promotionId, String title) async {
    HapticFeedback.mediumImpact();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: themeProvider.cardBackground,
        shape: RoundedRectangleBorder(
            borderRadius: themeProvider.cardBorderRadius),
        title: Text('Delete Promotion?',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText, fontWeight: FontWeight.w600)),
        content: Text(
            'Are you sure you want to delete the promotion "$title"? This action cannot be undone.',
            style: GoogleFonts.inter(color: themeProvider.secondaryText)),
        actions: [
          TextButton(
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: themeProvider.secondaryText)),
              onPressed: () => Navigator.of(dialogContext).pop(false)),
          TextButton(
              child: Text('Delete',
                  style: GoogleFonts.inter(
                      color: themeProvider.errorColor,
                      fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(dialogContext).pop(true)),
        ],
      ),
    );

    if (confirmDelete == true) {
      setState(() => _isLoading = true); // Indicate activity
      try {
        await _apiService.adminDeletePromotion(promotionId); // Use apiService
        if (mounted) {
          _showFeedbackSnackbar('Promotion "$title" deleted successfully.');
          _fetchPromotions(isRefresh: true); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          _showFeedbackSnackbar(
              "Error: ${e.toString().replaceFirst("Exception: ", "")}",
              isError: true);
          setState(() => _isLoading = false); // Stop loading on error
        }
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
        title: Text('Promotion Management',
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
            icon: Icon(Icons.add_circle_outline_rounded,
                color: adminAccentColor, size: 28),
            onPressed: () => _navigateToAddEditPromotionScreen(),
            tooltip: "Add New Promotion",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchPromotions(isRefresh: true),
        color: adminAccentColor,
        backgroundColor: themeProvider.cardBackground,
        child: _buildBody(themeProvider),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditPromotionScreen(),
        backgroundColor: adminAccentColor,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: "Add New Promotion",
      ),
    );
  }

  Widget _buildBody(ThemeProvider themeProvider) {
    if (_isLoading && _promotions.isEmpty) {
      return _buildLoadingShimmer(themeProvider);
    }
    if (_errorMessage != null) {
      return _buildErrorState(themeProvider);
    }
    if (_promotions.isEmpty) {
      return _buildEmptyState(themeProvider);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _promotions.length,
      itemBuilder: (context, index) {
        final promotion = _promotions[index];
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
            child: _AdminPromotionListItemWidget(
              promotion: promotion,
              themeProvider: themeProvider,
              onTap: () =>
                  _navigateToAddEditPromotionScreen(promotion: promotion),
              onToggleStatus: (newStatus) =>
                  _togglePromotionStatus(promotion, newStatus),
              onDelete: () => _handleDeletePromotion(
                  promotion.id, promotion.title), // Removed themeProvider here
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingShimmer(ThemeProvider themeProvider) {
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
                    width: 200, height: 18, themeProvider: themeProvider),
                const SizedBox(height: 8),
                _buildSkeletonLine(
                    width: double.infinity,
                    height: 14,
                    themeProvider: themeProvider),
                const SizedBox(height: 6),
                _buildSkeletonLine(
                    width: 150, height: 12, themeProvider: themeProvider),
                const SizedBox(height: 10),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSkeletonLine(
                          width: 80,
                          height: 20,
                          themeProvider: themeProvider,
                          borderRadius: 10),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined,
                color: themeProvider.secondaryText.withOpacity(0.7), size: 60),
            const SizedBox(height: 20),
            Text('Failed to Load Promotions',
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
                onPressed: () => _fetchPromotions(isRefresh: true),
                color: themeProvider
                    .gas2doorPrimaryBlue, // Corrected from 'color' to 'color'
                icon: Icon(Icons.refresh_rounded,
                    color: themeProvider.infoColorOnDarkBgs)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined,
                color: themeProvider.secondaryText.withOpacity(0.6), size: 80),
            const SizedBox(height: 24),
            Text('No Promotions Found',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            Text('Create your first promotion to engage customers!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    color: themeProvider.secondaryText,
                    height: 1.5)),
            const SizedBox(height: 28),
            CustomButton(
                text: 'Add New Promotion',
                onPressed: () => _navigateToAddEditPromotionScreen(),
                color: themeProvider
                    .gas2doorPrimaryBlue, // Corrected from 'color' to 'buttonColor'
                icon: Icon(Icons.add_circle_outline_rounded,
                    color: themeProvider.infoColorOnDarkBgs)),
          ],
        ),
      ),
    );
  }
}

class _AdminPromotionListItemWidget extends StatelessWidget {
  final AdminPromotionModel promotion;
  final ThemeProvider themeProvider;
  final VoidCallback onTap;
  final Function(bool) onToggleStatus;
  final VoidCallback onDelete;

  const _AdminPromotionListItemWidget({
    required this.promotion,
    required this.themeProvider,
    required this.onTap,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    bool isExpired = promotion.validUntil.isBefore(now);
    bool effectiveIsActive = promotion.isActive && !isExpired;

    Color statusColor = effectiveIsActive
        ? themeProvider.successColor
        : (isExpired ? themeProvider.errorColor : themeProvider.secondaryText);
    String statusText =
        effectiveIsActive ? "Active" : (isExpired ? "Expired" : "Inactive");

    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 1.5,
      child: InkWell(
        onTap: onTap, // Navigate to edit on tap
        borderRadius: themeProvider.cardBorderRadius,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(promotion.title,
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.primaryText),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(15)),
                        child: Text(statusText,
                            style: GoogleFonts.inter(
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 11)),
                      ),
                      if (!isExpired) // Only show switch if not expired
                        Switch.adaptive(
                          value: promotion.isActive,
                          onChanged: onToggleStatus,
                          activeColor: themeProvider.gas2doorTeal,
                          inactiveThumbColor: themeProvider.tertiaryText,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        )
                    ],
                  )
                ],
              ),
              const SizedBox(height: 4),
              Text(promotion.shortDescription,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: themeProvider.secondaryText,
                      height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.code_rounded,
                    size: 16, color: themeProvider.tertiaryText),
                const SizedBox(width: 6),
                Text(promotion.promoCode ?? 'Auto-Applied',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: themeProvider.gas2doorPurple,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                Icon(Icons.sell_outlined,
                    size: 16, color: themeProvider.tertiaryText),
                const SizedBox(width: 6),
                Text(promotion.typeAndValueDisplay,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: themeProvider.secondaryText)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.date_range_outlined,
                    size: 16, color: themeProvider.tertiaryText),
                const SizedBox(width: 6),
                Text('Valid: ${promotion.validityPeriodDisplay}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: themeProvider.tertiaryText)),
              ]),
              Divider(
                  height: 20,
                  color: themeProvider.tertiaryText.withOpacity(0.2)),
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
                  TextButton.icon(
                    icon: Icon(Icons.delete_forever_outlined,
                        size: 18, color: themeProvider.errorColor),
                    label: Text("Delete",
                        style: GoogleFonts.inter(
                            color: themeProvider.errorColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 13)),
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
