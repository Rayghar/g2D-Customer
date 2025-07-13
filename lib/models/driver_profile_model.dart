// lib/models/driver_profile_model.dart

class DriverProfileModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? vehicleModel;
  final String? licensePlate;
  final String? serviceZone;
  final String? photoUrl;
  final bool isAvailableOnline;

  DriverProfileModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.vehicleModel,
    this.licensePlate,
    this.serviceZone,
    this.photoUrl,
    required this.isAvailableOnline,
  });

  String get initials => name.isNotEmpty
      ? name.trim().split(' ').map((l) => l[0]).take(2).join().toUpperCase()
      : '?';

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    // FIX: The user object from your API might be nested under a 'user' key or be the root object. This handles both cases.
    final userData = json['user'] as Map<String, dynamic>? ?? json;

    return DriverProfileModel(
      // FIX: Use '_id' which is common in Node/MongoDB backends, and fall back to 'id'.
      id: userData['_id'] as String? ?? userData['id'] as String? ?? '',
      name: userData['name'] as String? ?? 'N/A',
      email: userData['email'] as String?,
      // FIX: Check for 'phoneNumber' as well as 'phone'.
      phone: userData['phoneNumber'] as String? ?? userData['phone'] as String?,
      vehicleModel: userData['vehicleModel'] as String?,
      licensePlate: userData['licensePlate'] as String?,
      serviceZone: userData['serviceZone'] as String?,
      photoUrl: userData['photoUrl'] as String?,
      // FIX: Safely parse the boolean, defaulting to false if null or not found.
      isAvailableOnline: userData['isAvailableOnline'] as bool? ?? false,
    );
  }
}
