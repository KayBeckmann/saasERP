import 'user_role.dart';

/// Request: Owner legt einen neuen Mitarbeiter-Zugang an.
class CreateEmployeeRequest {
  const CreateEmployeeRequest({
    required this.email,
    required this.password,
    this.role = UserRole.employee,
  });

  final String email;
  final String password;
  final UserRole role;

  factory CreateEmployeeRequest.fromJson(Map<String, dynamic> json) =>
      CreateEmployeeRequest(
        email: json['email'] as String,
        password: json['password'] as String,
        role: json['role'] != null
            ? UserRole.fromJson(json['role'] as String)
            : UserRole.employee,
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'role': role.toJson(),
      };
}

/// Request: Benutzer ändert sein eigenes Passwort.
class ChangePasswordRequest {
  const ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  factory ChangePasswordRequest.fromJson(Map<String, dynamic> json) =>
      ChangePasswordRequest(
        currentPassword: json['current_password'] as String,
        newPassword: json['new_password'] as String,
      );

  Map<String, dynamic> toJson() => {
        'current_password': currentPassword,
        'new_password': newPassword,
      };
}
