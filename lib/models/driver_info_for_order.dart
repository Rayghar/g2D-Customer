// File: lib/models/driver_info_for_order.dart

class DriverInfoForOrder {
  final String id;
  final String name;
  final String? phone;
  final String? vehicleType;
  final String? licensePlate;

  DriverInfoForOrder({
    required this.id,
    required this.name,
    this.phone,
    this.vehicleType,
    this.licensePlate,
  });

  factory DriverInfoForOrder.fromJson(Map<String, dynamic> json) {
    return DriverInfoForOrder(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'N/A',
      phone: json['phone'] as String?,
      vehicleType: json['vehicleType'] as String?,
      licensePlate: json['licensePlate'] as String?,
    );
  }
}
