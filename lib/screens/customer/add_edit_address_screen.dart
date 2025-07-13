// File: lib/screens/customer/add_edit_address_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../models/address_model.dart';
import '../../services/api_service.dart';

// Custom AddressComponent class to handle address components
class AddressComponent {
  final String longName;
  final List<String> types;

  AddressComponent({required this.longName, required this.types});
}

class AddEditAddressScreen extends StatefulWidget {
  static const String routeName = '/add_edit_address';
  final AddressModel? address;
  const AddEditAddressScreen({super.key, this.address});

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;

  late TextEditingController _labelController;
  late TextEditingController _fullAddressController;
  late TextEditingController _streetController;
  late TextEditingController _apartmentOrSuiteController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;
  late TextEditingController _countryController;
  late TextEditingController _deliveryInstructionsController;
  bool _isDefaultAddress = false;
  double? _latitude;
  double? _longitude;

  final ApiService _apiService = ApiService();
  // IMPORTANT: Replace with your actual Google Maps API key
  final String _googleApiKey = "AIzaSyBZ3FRunKc6w3WKoYjmOKaEN9f6eo-Zap4";

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.address != null;
    _labelController =
        TextEditingController(text: _isEditMode ? widget.address!.label : '');
    _fullAddressController = TextEditingController(
        text: _isEditMode ? widget.address!.fullAddress : '');
    _streetController =
        TextEditingController(text: _isEditMode ? widget.address!.street : '');
    _apartmentOrSuiteController = TextEditingController(
        text: _isEditMode ? widget.address!.apartmentOrSuite : '');
    _cityController =
        TextEditingController(text: _isEditMode ? widget.address!.city : '');
    _stateController =
        TextEditingController(text: _isEditMode ? widget.address!.state : '');
    _postalCodeController = TextEditingController(
        text: _isEditMode ? widget.address!.postalCode : '');
    _countryController = TextEditingController(
        text: _isEditMode ? widget.address!.country : 'Nigeria');
    _deliveryInstructionsController = TextEditingController(
        text: _isEditMode ? widget.address!.deliveryInstructions : '');
    _isDefaultAddress = _isEditMode ? widget.address!.isDefault : false;
    _latitude = _isEditMode ? widget.address!.latitude : null;
    _longitude = _isEditMode ? widget.address!.longitude : null;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _fullAddressController.dispose();
    _streetController.dispose();
    _apartmentOrSuiteController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _deliveryInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _populateAddressFields(Prediction prediction) async {
    if (prediction.placeId == null) {
      _showFeedbackSnackbar('Unable to fetch place details.', isError: true);
      return;
    }

    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=${prediction.placeId}&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch place details from Google API.');
      }

      final data = json.decode(response.body);
      final result = data['result'];
      if (result == null) {
        throw Exception('No place details found in API response.');
      }

      List<AddressComponent> components = (result['address_components'] as List)
          .map((c) => AddressComponent(
                longName: c['long_name'] ?? '',
                types: List<String>.from(c['types'] ?? []),
              ))
          .toList();

      AddressComponent emptyComponent() =>
          AddressComponent(longName: '', types: []);

      String streetNumber = components
          .firstWhere((c) => c.types.contains("street_number"),
              orElse: emptyComponent)
          .longName;
      String route = components
          .firstWhere((c) => c.types.contains("route"), orElse: emptyComponent)
          .longName;
      String city = components
          .firstWhere(
              (c) =>
                  c.types.contains("locality") ||
                  c.types.contains("administrative_area_level_2"),
              orElse: emptyComponent)
          .longName;
      String state = components
          .firstWhere((c) => c.types.contains("administrative_area_level_1"),
              orElse: emptyComponent)
          .longName;
      String country = components
          .firstWhere((c) => c.types.contains("country"),
              orElse: emptyComponent)
          .longName;
      String postalCode = components
          .firstWhere((c) => c.types.contains("postal_code"),
              orElse: emptyComponent)
          .longName;

      setState(() {
        _fullAddressController.text =
            result['formatted_address'] ?? prediction.description ?? '';
        _streetController.text = "$streetNumber $route".trim();
        _cityController.text = city;
        _stateController.text = state;
        _countryController.text = country;
        _postalCodeController.text = postalCode;
        _latitude = result['geometry']?['location']?['lat'];
        _longitude = result['geometry']?['location']?['lng'];
      });
    } catch (e) {
      _showFeedbackSnackbar('Error fetching details: ${e.toString()}',
          isError: true);
    }
  }

  Future<void> _handleSaveAddress() async {
    if (!_formKey.currentState!.validate()) {
      _showFeedbackSnackbar('Please fill all required fields.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    final addressData = {
      'label': _labelController.text.trim(),
      'fullAddress': _fullAddressController.text.trim(),
      'street': _streetController.text.trim(),
      'apartmentOrSuite': _apartmentOrSuiteController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'postalCode': _postalCodeController.text.trim(),
      'country': _countryController.text.trim(),
      'isDefault': _isDefaultAddress,
      'deliveryInstructions': _deliveryInstructionsController.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
    };

    try {
      if (_isEditMode) {
        await _apiService.updateAddress(widget.address!.id, addressData);
      } else {
        await _apiService.createAddress(addressData);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        _showFeedbackSnackbar(
            'Failed to save address: ${e.toString().replaceFirst("Exception: ", "")}',
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor:
            isError ? themeProvider.errorColor : themeProvider.successColor));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Address' : 'Add New Address',
            style: GoogleFonts.inter(
                color: themeProvider.primaryText, fontWeight: FontWeight.w600)),
        backgroundColor: themeProvider.cardBackground,
        actions: [
          if (!_isLoading)
            TextButton(
                onPressed: _handleSaveAddress,
                child: Text(_isEditMode ? 'SAVE' : 'ADD',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: themeProvider.gas2doorPrimaryBlue)))
          else
            const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomInput(
                  controller: _labelController,
                  labelText: 'Address Label*',
                  hintText: 'e.g., Home, Office',
                  validator: (v) => v!.isEmpty ? 'Label is required' : null,
                  prefixIcon: Icons.label_outline_rounded),
              const SizedBox(height: 18),

              // ========================== FIX IS HERE ==========================
              GooglePlaceAutoCompleteTextField(
                textEditingController: _fullAddressController,
                googleAPIKey: _googleApiKey,
                // The itemClick callback is used to get the selected Prediction
                itemClick: (Prediction prediction) {
                  _fullAddressController.text = prediction.description ?? '';
                  _fullAddressController.selection = TextSelection.fromPosition(
                      TextPosition(
                          offset: prediction.description?.length ?? 0));
                  // Manually fetch details after a selection is made
                  _populateAddressFields(prediction);
                },
                // Styling parameters to make the dropdown visible and match your theme
                textStyle: GoogleFonts.inter(color: themeProvider.primaryText),
                containerHorizontalPadding: 10,
                inputDecoration: InputDecoration(
                  labelText: "Search Address*",
                  hintText: "Start typing your address...",
                  prefixIcon:
                      Icon(Icons.search, color: themeProvider.secondaryText),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: themeProvider.gas2doorPrimaryBlue)),
                ),
                countries: ["ng"], // Bias results to Nigeria
              ),
              // =================================================================

              const SizedBox(height: 24),
              Text("ADDRESS DETAILS",
                  style: GoogleFonts.inter(
                      color: themeProvider.secondaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              const Divider(height: 20),
              CustomInput(
                  controller: _streetController,
                  labelText: 'Street Address*',
                  validator: (v) => v!.isEmpty ? 'Street is required' : null,
                  prefixIcon: Icons.signpost_outlined),
              const SizedBox(height: 18),
              CustomInput(
                  controller: _apartmentOrSuiteController,
                  labelText: 'Apt, Suite, etc. (Optional)',
                  prefixIcon: Icons.door_front_door_outlined),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                    child: CustomInput(
                        controller: _cityController,
                        labelText: 'City*',
                        validator: (v) =>
                            v!.isEmpty ? 'City is required' : null,
                        prefixIcon: Icons.location_city_rounded)),
                const SizedBox(width: 16),
                Expanded(
                    child: CustomInput(
                        controller: _stateController,
                        labelText: 'State*',
                        validator: (v) =>
                            v!.isEmpty ? 'State is required' : null,
                        prefixIcon: Icons.business_rounded)),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                    child: CustomInput(
                        controller: _postalCodeController,
                        labelText: 'Postal Code (Optional)',
                        prefixIcon: Icons.markunread_mailbox_outlined)),
                const SizedBox(width: 16),
                Expanded(
                    child: CustomInput(
                        controller: _countryController,
                        labelText: 'Country*',
                        validator: (v) =>
                            v!.isEmpty ? 'Country is required' : null,
                        prefixIcon: Icons.public_outlined)),
              ]),
              const SizedBox(height: 18),
              CustomInput(
                  controller: _deliveryInstructionsController,
                  labelText: 'Delivery Instructions (Optional)',
                  maxLines: 2,
                  prefixIcon: Icons.notes_outlined),
              const SizedBox(height: 24),
              SwitchListTile.adaptive(
                title: Text('Set as default delivery address',
                    style: GoogleFonts.inter(
                        color: themeProvider.primaryText,
                        fontWeight: FontWeight.w500)),
                value: _isDefaultAddress,
                onChanged: (bool value) =>
                    setState(() => _isDefaultAddress = value),
                activeColor: themeProvider.gas2doorTeal,
                secondary: Icon(Icons.star_rounded,
                    color: _isDefaultAddress
                        ? themeProvider.gas2doorTeal
                        : themeProvider.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
