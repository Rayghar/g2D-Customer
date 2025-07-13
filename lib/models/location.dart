// File: lib/models/location.dart

class Location {
  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  Location({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    try {
      return Location(
        id: json['id'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
    } catch (e) {
      print('Error parsing Location from JSON: $e\nJSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
