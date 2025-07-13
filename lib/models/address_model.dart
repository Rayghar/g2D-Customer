// File: lib/models/address_model.dart

class AddressModel {
  final String id;
  String label;
  String fullAddress; // This is required
  String street; // This is required
  String? apartmentOrSuite;
  String city; // This is required
  String state; // This is required
  String? postalCode;
  String country; // This is required
  bool isDefault;
  final double? latitude;
  final double? longitude;
  String? deliveryInstructions; // <<< ADDED THIS FIELD

  AddressModel({
    required this.id,
    required this.label,
    required this.fullAddress, // Made sure it's required
    required this.street, // Changed from streetAddress, made required
    this.apartmentOrSuite,
    required this.city,
    required this.state,
    this.postalCode,
    required this.country,
    this.isDefault = false,
    this.latitude,
    this.longitude,
    this.deliveryInstructions, // <<< ADDED TO CONSTRUCTOR
  });

  // Getter for a short representation of the address
  String get addressShort {
    List<String> parts = [];
    if (street.isNotEmpty) parts.add(street);
    if (apartmentOrSuite != null && apartmentOrSuite!.isNotEmpty)
      parts.add(apartmentOrSuite!);
    if (city.isNotEmpty) parts.add(city);
    if (parts.isEmpty)
      return label; // Fallback to label if other parts are empty
    return parts.join(', ');
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    try {
      return AddressModel(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        fullAddress: json['fullAddress'] as String? ?? '',
        street: json['street'] as String? ?? '', // Use 'street' from JSON
        apartmentOrSuite: json['apartmentOrSuite'] as String?,
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        postalCode: json['postalCode'] as String?,
        country: json['country'] as String? ?? 'Nigeria',
        isDefault: (json['isDefault'] as bool?) ?? false,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        deliveryInstructions:
            json['deliveryInstructions'] as String?, // <<< ADDED FROM JSON
      );
    } catch (e) {
      print('Error parsing AddressModel from JSON: $e\nJSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'fullAddress': fullAddress,
      'street': street,
      if (apartmentOrSuite != null && apartmentOrSuite!.isNotEmpty)
        'apartmentOrSuite': apartmentOrSuite,
      'city': city,
      'state': state,
      if (postalCode != null && postalCode!.isNotEmpty)
        'postalCode': postalCode,
      'country': country,
      'isDefault': isDefault,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (deliveryInstructions != null &&
          deliveryInstructions!.isNotEmpty) // <<< ADDED TO JSON
        'deliveryInstructions': deliveryInstructions,
    };
  }
}
