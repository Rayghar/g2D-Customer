// File: lib/screens/customer/address_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/address_model.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import './add_edit_address_screen.dart'; // For navigation
import '../../services/api_service.dart'; // For API calls

class AddressListScreen extends StatefulWidget {
  static const String routeName = '/address_list';
  final bool isSelectingAddress;
  // final GlobalKey<NavigatorState>? navigatorKey; // Not typically needed if pushed by another navigator
  final String?
      customerId; // Not directly used if ApiService handles auth token
  final String?
      currentAddressId; // ID of the address currently set as default or selected

  const AddressListScreen({
    super.key,
    this.isSelectingAddress = false,
    // this.navigatorKey,
    this.customerId,
    this.currentAddressId,
  });

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<AddressModel> _addresses = [];
  String? _errorMessage;
  late AnimationController _listAnimationController;
  String?
      _currentlyProcessingAddressId; // For loading state on individual items

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fetchAddresses();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAddresses({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final fetchedAddresses = await _apiService.getMyAddresses();
      if (mounted) {
        setState(() {
          _addresses = fetchedAddresses;
          _isLoading = false;
        });
        _listAnimationController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              "Failed to load addresses: ${e.toString().replaceFirst("Exception: ", "")}";
          _isLoading = false;
        });
        _showFeedbackSnackbar(_errorMessage!, isError: true);
      }
    }
  }

  Future<void> _handleSetDefault(String addressId) async {
    if (mounted) setState(() => _currentlyProcessingAddressId = addressId);
    HapticFeedback.mediumImpact();
    try {
      final updatedDefaultAddress =
          await _apiService.setDefaultAddress(addressId);
      if (mounted) {
        _showFeedbackSnackbar(
            'Address "${updatedDefaultAddress.label}" set as default.');
        _fetchAddresses(
            showLoading: false); // Refresh list to reflect new default
        if (widget.isSelectingAddress) {
          // If selecting, pop with the new default
          Navigator.of(context).pop(updatedDefaultAddress);
        }
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(
            'Failed to set default: ${e.toString().replaceFirst("Exception: ", "")}',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _currentlyProcessingAddressId = null);
    }
  }

  Future<void> _handleDelete(String addressId, String addressLabel) async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
            'Are you sure you want to delete the address "$addressLabel"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCEL')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('DELETE',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) setState(() => _currentlyProcessingAddressId = addressId);
    try {
      // **BACKEND GAP**: Assumes DELETE /api/v1/addresses/:addressId exists
      // If not, this will fail.
      final response = await _apiService.deleteAddress(addressId);
      if (mounted) {
        _showFeedbackSnackbar(
            response['message'] ?? 'Address deleted successfully.');
        _fetchAddresses(showLoading: false); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(
            'Delete failed: ${e.toString().replaceFirst("Exception: ", "")}',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _currentlyProcessingAddressId = null);
    }
  }

  void _navigateToAddEditScreen({AddressModel? addressToEdit}) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.of(context).pushNamed(
      AddEditAddressScreen.routeName,
      arguments: {
        'address': addressToEdit,
        'customerId':
            widget.customerId, // Pass customerId if needed by AddEditAddress
      },
    );
    if (result == true && mounted) {
      // true indicates a save was made
      _fetchAddresses(showLoading: false);
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        title: Text(
            widget.isSelectingAddress
                ? 'Select Delivery Address'
                : 'My Addresses',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText, fontWeight: FontWeight.w600)),
        backgroundColor: themeProvider.cardBackground,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_location_alt_outlined,
                color: themeProvider.gas2doorPrimaryBlue, size: 26),
            tooltip: 'Add New Address',
            onPressed: () => _navigateToAddEditScreen(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAddresses,
        color: themeProvider.gas2doorPrimaryBlue,
        backgroundColor: themeProvider.cardBackground,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                    color: themeProvider.gas2doorPrimaryBlue))
            : _errorMessage != null
                ? _buildErrorState(themeProvider, _errorMessage!)
                : _addresses.isEmpty
                    ? _buildEmptyState(themeProvider)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _addresses.length,
                        itemBuilder: (context, index) {
                          final address = _addresses[index];
                          final animation = Tween<Offset>(
                                  begin: const Offset(0, 0.3), end: Offset.zero)
                              .animate(CurvedAnimation(
                                  parent: _listAnimationController,
                                  curve: Interval((0.1 * index).clamp(0.0, 1.0),
                                      (0.5 + (0.1 * index)).clamp(0.0, 1.0),
                                      curve: Curves.easeOutCubic)));
                          if (!_listAnimationController.isAnimating &&
                              !_listAnimationController.isCompleted) {
                            _listAnimationController
                                .forward(); // Start animation if not already
                          }
                          return SlideTransition(
                            position: animation,
                            child: FadeTransition(
                              opacity:
                                  _listAnimationController, // Use controller directly for fade
                              child: _AddressItemCard(
                                address: address,
                                themeProvider: themeProvider,
                                isCurrentlySelected:
                                    widget.isSelectingAddress &&
                                        widget.currentAddressId == address.id,
                                isProcessing:
                                    _currentlyProcessingAddressId == address.id,
                                onSelect: widget.isSelectingAddress
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        Navigator.of(context).pop(address);
                                      }
                                    : null,
                                onEdit: () => _navigateToAddEditScreen(
                                    addressToEdit: address),
                                onSetDefault: address.isDefault
                                    ? null
                                    : () => _handleSetDefault(address.id),
                                onDelete: () =>
                                    _handleDelete(address.id, address.label),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_rounded,
                color: themeProvider.errorColor, size: 60),
            const SizedBox(height: 20),
            Text('Could Not Load Addresses',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                style: GoogleFonts.inter(
                    color: themeProvider.secondaryText, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            CustomButton(
                text: "Retry",
                onPressed: _fetchAddresses,
                color: themeProvider.gas2doorPrimaryBlue,
                icon: Icon(Icons.refresh_rounded, color: Colors.white))
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
            Icon(Icons.add_location_outlined,
                color: themeProvider.secondaryText.withOpacity(0.5), size: 70),
            const SizedBox(height: 24),
            Text('No Addresses Saved Yet',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            Text('Add your delivery addresses to make ordering quick and easy.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14, color: themeProvider.secondaryText)),
            const SizedBox(height: 24),
            CustomButton(
              text: "Add New Address",
              onPressed: () => _navigateToAddEditScreen(),
              color: themeProvider.gas2doorPrimaryBlue,
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: Colors.white),
            )
          ],
        ),
      ),
    );
  }
}

// Extracted Address Item Card Widget
class _AddressItemCard extends StatelessWidget {
  final AddressModel address;
  final ThemeProvider themeProvider;
  final bool isCurrentlySelected;
  final bool isProcessing;
  final VoidCallback? onSelect;
  final VoidCallback onEdit;
  final VoidCallback? onSetDefault; // Nullable if already default
  final VoidCallback onDelete;

  const _AddressItemCard({
    required this.address,
    required this.themeProvider,
    this.isCurrentlySelected = false,
    this.isProcessing = false,
    this.onSelect,
    required this.onEdit,
    this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      border: isCurrentlySelected
          ? BorderSide(color: themeProvider.gas2doorPrimaryBlue, width: 1.5)
          : null,
      child: InkWell(
        // Make the whole card tappable if onSelect is provided
        onTap: onSelect,
        borderRadius: themeProvider.cardBorderRadius,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    address.label.toLowerCase().contains('home')
                        ? Icons.home_work_outlined
                        : address.label.toLowerCase().contains('work')
                            ? Icons.work_outline_rounded
                            : Icons.location_on_outlined,
                    color: themeProvider.gas2doorPrimaryBlue,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      address.label,
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.primaryText),
                    ),
                  ),
                  if (address.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: themeProvider.gas2doorTeal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('DEFAULT',
                          style: GoogleFonts.inter(
                              color: themeProvider.gas2doorTeal,
                              fontWeight: FontWeight.bold,
                              fontSize: 9.5)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(
                    left: 38), // Align with text under icon
                child: Text(
                  address.fullAddress,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: themeProvider.secondaryText,
                      height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Divider(
                  height: 24,
                  thickness: 0.3,
                  color: themeProvider.tertiaryText.withOpacity(0.2)),
              if (isProcessing)
                const Center(
                    child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.0)))
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onSetDefault != null)
                      TextButton(
                        onPressed: onSetDefault,
                        child: Text('Set as Default',
                            style: GoogleFonts.inter(
                                color: themeProvider.gas2doorTeal,
                                fontWeight: FontWeight.w500,
                                fontSize: 13)),
                      ),
                    IconButton(
                        icon: Icon(Icons.edit_outlined,
                            color: themeProvider.secondaryText, size: 20),
                        onPressed: onEdit,
                        tooltip: 'Edit Address',
                        splashRadius: 20),
                    IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            color: themeProvider.errorColor.withOpacity(0.8),
                            size: 20),
                        onPressed: onDelete,
                        tooltip: 'Delete Address',
                        splashRadius: 20),
                  ],
                )
            ],
          ),
        ),
      ),
    );
  }
}
