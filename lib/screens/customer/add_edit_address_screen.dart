// File: lib/screens/customer/add_edit_address_screen.dart
// ADVISORY: This version fixes the reported bugs (messy suggestions, backspace response, address parsing/duplication) plus other polish.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../widgets/card.dart';
import '../../models/address_model.dart';
import '../../services/api_service.dart';

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

  String? _selectedLabel;
  final List<String> _predefinedLabels = [
    'Home',
    'Office',
    'Work',
    "Parents'",
    'Other'
  ];

  final ApiService _apiService = ApiService();

  String? _googleApiKey;

  // Focus nodes
  final FocusNode _aptFocus = FocusNode();
  final FocusNode _cityFocus = FocusNode();
  final FocusNode _stateFocus = FocusNode();
  final FocusNode _postalFocus = FocusNode();
  final FocusNode _countryFocus = FocusNode();

  bool _squelchStreetOnChanged = false;

  final Uuid _uuid = const Uuid();
  String _sessionToken = '';

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.address != null;
    _labelController =
        TextEditingController(text: _isEditMode ? widget.address!.label : '');
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

    _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ??
        dotenv.env['GOOGLE_PLACES_API_KEY'] ??
        dotenv.env['Maps_API_KEY'];

    if (_isEditMode) {
      if (_predefinedLabels.contains(widget.address!.label)) {
        _selectedLabel = widget.address!.label;
      } else {
        _selectedLabel = 'Other';
        _labelController.text = widget.address!.label;
      }
    }

    _sessionToken = _uuid.v4();

    _streetController.addListener(_handleStreetChanged);
  }

  @override
  void dispose() {
    _streetController.removeListener(_handleStreetChanged);
    _labelController.dispose();
    _streetController.dispose();
    _apartmentOrSuiteController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _deliveryInstructionsController.dispose();

    _aptFocus.dispose();
    _cityFocus.dispose();
    _stateFocus.dispose();
    _postalFocus.dispose();
    _countryFocus.dispose();

    super.dispose();
  }

  void _handleStreetChanged() {
    if (_squelchStreetOnChanged) return;
    if (_streetController.text.length < 5) {
      setState(() {
        _cityController.clear();
        _stateController.clear();
        _postalCodeController.clear();
        _countryController.text = 'Nigeria';
        _latitude = null;
        _longitude = null;
      });
    }
  }

  String _safeGetComponent(
    List<AddressComponent> components,
    List<String> types,
  ) {
    AddressComponent? component = components.firstWhere(
      (c) => c.types.any((type) => types.contains(type)),
      orElse: () => AddressComponent(longName: '', types: []),
    );
    return component.longName;
  }

  void _setControllerText(TextEditingController c, String value,
      {bool guardStreet = false}) {
    if (guardStreet) _squelchStreetOnChanged = true;
    c.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    if (guardStreet) {
      Future.microtask(() => _squelchStreetOnChanged = false);
    }
  }

  Future<void> _populateAddressFields(Prediction prediction,
      {required String fallbackFullText}) async {
    if (_googleApiKey == null || _googleApiKey!.trim().isEmpty) {
      _showFeedbackSnackbar('Google Places API key not found.', isError: true);
      return;
    }
    if (prediction.placeId == null || prediction.placeId!.isEmpty) {
      _showFeedbackSnackbar('Unable to fetch place details.', isError: true);
      return;
    }

    final fields = 'address_component,geometry,formatted_address';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=${Uri.encodeComponent(prediction.placeId!)}'
      '&fields=$fields'
      '&sessiontoken=${Uri.encodeComponent(_sessionToken)}'
      '&key=${Uri.encodeComponent(_googleApiKey!)}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final data = json.decode(response.body);
      final status = (data['status'] ?? '').toString();
      if (status != 'OK') {
        final err = data['error_message']?.toString() ?? '';
        throw Exception(
            'Google Places: $status${err.isEmpty ? '' : ' - $err'}');
      }

      final result = data['result'];
      if (result == null) {
        throw Exception('No place details found in API response.');
      }

      final compsRaw = (result['address_components'] as List? ?? []);
      final components = compsRaw
          .map((c) => AddressComponent(
                longName: c['long_name'] ?? '',
                types: List<String>.from(c['types'] ?? []),
              ))
          .toList();

      final city = _safeGetComponent(
          components, ['locality', 'administrative_area_level_2']);
      final state =
          _safeGetComponent(components, ['administrative_area_level_1']);
      final country = _safeGetComponent(components, ['country']);
      final postalCode = _safeGetComponent(components, ['postal_code']);

      final streetNumber = _safeGetComponent(components, ['street_number']);
      final route = _safeGetComponent(components, ['route']);
      final premise = _safeGetComponent(components, ['premise']);
      final neighborhood = _safeGetComponent(components, ['neighborhood']);
      final subpremise =
          _safeGetComponent(components, ['subpremise']); // Apt/suite

      String street =
          [streetNumber, route].where((s) => s.isNotEmpty).join(' ').trim();
      if (premise.isNotEmpty) {
        street = [premise, street].join(' ').trim();
      }
      if (street.isEmpty && neighborhood.isNotEmpty) {
        street = neighborhood;
      }
      if (street.isEmpty) {
        final formatted =
            result['formatted_address']?.toString().trim() ?? fallbackFullText;
        street = formatted.split(',').first.trim();
      }

      final lat = result['geometry']?['location']?['lat'];
      final lng = result['geometry']?['location']?['lng'];

      setState(() {
        _setControllerText(_streetController, street, guardStreet: true);
        _setControllerText(_cityController, city);
        _setControllerText(_stateController, state);
        _setControllerText(_countryController, country);
        _setControllerText(_postalCodeController, postalCode);
        if (subpremise.isNotEmpty &&
            _apartmentOrSuiteController.text.trim().isEmpty) {
          _setControllerText(_apartmentOrSuiteController, subpremise);
        }
        _latitude = (lat is num) ? lat.toDouble() : _latitude;
        _longitude = (lng is num) ? lng.toDouble() : _longitude;
      });
    } catch (e) {
      _showFeedbackSnackbar('Error fetching details: ${e.toString()}',
          isError: true);
    } finally {
      _sessionToken = _uuid.v4();
    }
  }

  Future<void> _handleSaveAddress() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) {
      _showFeedbackSnackbar('Please fill all required fields.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    String finalLabel = _selectedLabel == 'Other'
        ? _labelController.text.trim()
        : _selectedLabel ?? 'Home';

    final addressData = AddressModel(
      id: widget.address?.id ?? '',
      label: finalLabel,
      fullAddress:
          '${_streetController.text.trim()}, ${_cityController.text.trim()}, ${_stateController.text.trim()}',
      street: _streetController.text.trim(),
      apartmentOrSuite: _apartmentOrSuiteController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      country: _countryController.text.trim(),
      isDefault: _isDefaultAddress,
      deliveryInstructions: _deliveryInstructionsController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );

    try {
      if (_isEditMode) {
        await _apiService.updateAddress(
            widget.address!.id, addressData.toJson());
      } else {
        await _apiService.createAddress(addressData.toJson());
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackbar(
          'Failed to save address: ${e.toString().replaceFirst("Exception: ", "")}',
          isError: true,
        );
      }
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
          _isEditMode ? 'Edit Address' : 'Add New Address',
          style: GoogleFonts.inter(
            color: themeProvider.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: themeProvider.cardBackground,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabelCard(themeProvider),
                const SizedBox(height: 16),
                _buildLocationCard(themeProvider),
                const SizedBox(height: 16),
                _buildDetailsCard(themeProvider),
                const SizedBox(height: 16),
                _buildOptionsCard(themeProvider),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration:
            BoxDecoration(color: themeProvider.cardBackground, boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ]),
        child: CustomButton(
          text: _isLoading ? 'Saving...' : 'Save Address',
          onPressed: _isLoading ? null : _handleSaveAddress,
          color: themeProvider.gas2doorPrimaryBlue,
          height: 52,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.check_circle_outline, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildLabelCard(ThemeProvider themeProvider) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address Label*',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              children: _predefinedLabels.map((label) {
                final isSelected = _selectedLabel == label;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) _selectedLabel = label;
                    });
                  },
                  selectedColor: themeProvider.gas2doorPrimaryBlue,
                  labelStyle: GoogleFonts.inter(
                    color:
                        isSelected ? Colors.white : themeProvider.primaryText,
                  ),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : themeProvider.tertiaryText.withOpacity(0.3),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_selectedLabel == 'Other') ...[
              const SizedBox(height: 16),
              CustomInput(
                controller: _labelController,
                labelText: 'Custom Label*',
                hintText: 'e.g., Grandma\'s House',
                validator: (v) =>
                    v!.isEmpty ? 'Custom label is required' : null,
                prefixIcon: Icons.label_outline_rounded,
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(ThemeProvider themeProvider) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location Details',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 16),
            GooglePlaceAutoCompleteTextField(
              textEditingController: _streetController,
              googleAPIKey: _googleApiKey ?? '',
              inputDecoration: InputDecoration(
                labelText: "Search Street Address*",
                prefixIcon:
                    Icon(Icons.search, color: themeProvider.secondaryText),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: themeProvider.gas2doorPrimaryBlue,
                    width: 2,
                  ),
                ),
              ),
              boxDecoration: BoxDecoration(
                color: themeProvider.cardBackground,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              itemBuilder: (context, index, prediction) {
                return Column(
                  children: [
                    ListTile(
                      title: Text(
                        prediction.description ?? '',
                        style:
                            GoogleFonts.inter(color: themeProvider.primaryText),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: themeProvider.tertiaryText.withOpacity(0.2),
                    ),
                  ],
                );
              },
              isLatLngRequired: false,
              getPlaceDetailWithLatLng:
                  (prediction) {}, // we handle details manually
              itemClick: (Prediction prediction) async {
                final selected = (prediction.description ?? '').trim();
                _setControllerText(_streetController, selected,
                    guardStreet: true);

                await _populateAddressFields(
                  prediction,
                  fallbackFullText: selected,
                );

                // Dismiss keyboard after selection
                FocusScope.of(context).unfocus();
              },
              textStyle: GoogleFonts.inter(color: themeProvider.primaryText),
              countries: const ["ng"],
            ),
            const SizedBox(height: 16),
            Focus(
              focusNode: _aptFocus,
              child: CustomInput(
                controller: _apartmentOrSuiteController,
                labelText: 'Apt, Suite, etc. (Optional)',
                prefixIcon: Icons.door_front_door_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(ThemeProvider themeProvider) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: Focus(
                  focusNode: _cityFocus,
                  child: CustomInput(
                    controller: _cityController,
                    labelText: 'City*',
                    validator: (v) => v!.isEmpty ? 'City required' : null,
                    prefixIcon: Icons.location_city_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Focus(
                  focusNode: _stateFocus,
                  child: CustomInput(
                    controller: _stateController,
                    labelText: 'State*',
                    validator: (v) => v!.isEmpty ? 'State required' : null,
                    prefixIcon: Icons.business_rounded,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Focus(
                  focusNode: _postalFocus,
                  child: CustomInput(
                    controller: _postalCodeController,
                    labelText: 'Postal Code',
                    prefixIcon: Icons.markunread_mailbox_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Focus(
                  focusNode: _countryFocus,
                  child: CustomInput(
                    controller: _countryController,
                    labelText: 'Country*',
                    validator: (v) => v!.isEmpty ? 'Country required' : null,
                    prefixIcon: Icons.public_outlined,
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsCard(ThemeProvider themeProvider) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Options',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryText)),
            const SizedBox(height: 8),
            CustomInput(
              controller: _deliveryInstructionsController,
              labelText: 'Delivery Instructions (Optional)',
              hintText: 'e.g., Leave at the front desk',
              maxLines: 3,
              prefixIcon: Icons.notes_outlined,
            ),
            SwitchListTile.adaptive(
              title: Text(
                'Set as default address',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w500),
              ),
              value: _isDefaultAddress,
              onChanged: (bool value) =>
                  setState(() => _isDefaultAddress = value),
              activeColor: themeProvider.gas2doorTeal,
              secondary: Icon(
                Icons.star_rounded,
                color: _isDefaultAddress
                    ? themeProvider.gas2doorTeal
                    : themeProvider.secondaryText,
              ),
              contentPadding: const EdgeInsets.only(left: 4, top: 8),
            ),
          ],
        ),
      ),
    );
  }
}
