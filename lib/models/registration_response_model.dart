// File: lib/models/registration_response_model.dart

class RegistrationResponseModel {
  final String userId;
  final String message;

  RegistrationResponseModel({
    required this.userId,
    required this.message,
  });

  factory RegistrationResponseModel.fromJson(Map<String, dynamic> json) {
    return RegistrationResponseModel(
      userId: json['userId'] as String? ?? '',
      message: json['message'] as String? ?? 'Registration status unknown.',
    );
  }
}
