// File: lib/models/auth_response_model.dart

class LoginSuccessData {
  final String token;
  final String userId;
  final String name;
  final String role;
  final String? message;
  final bool isNewUser; // ADD THIS FIELD

  LoginSuccessData({
    required this.token,
    required this.userId,
    required this.name,
    required this.role,
    this.message,
    this.isNewUser = false, // ADD THIS FIELD
  });

  factory LoginSuccessData.fromJson(Map<String, dynamic> json) {
    return LoginSuccessData(
      token: json['token'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? 'User',
      role: json['role'] as String? ?? '',
      message: json['message'] as String?,
      isNewUser: json['isNewUser'] as bool? ?? false, // ADD THIS LINE
    );
  }
}
