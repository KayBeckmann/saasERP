/// Request: Admin legt einen neuen Mitarbeiter-Zugang an.
///
/// `roleId` ist optional, damit der bestehende Flutter-Client (noch ohne
/// Rollen-Auswahl-UI, siehe RF2-Auditnotiz) weiterläuft — ohne `roleId`
/// bekommt der neue Zugang serverseitig die "Nur Lesen"-Rolle des
/// Mandanten (Least Privilege als sicherer Default), siehe
/// `routes/api/users/index.dart`.
class CreateEmployeeRequest {
  const CreateEmployeeRequest({
    required this.email,
    required this.password,
    this.roleId,
  });

  final String email;
  final String password;
  final String? roleId;

  factory CreateEmployeeRequest.fromJson(Map<String, dynamic> json) =>
      CreateEmployeeRequest(
        email: json['email'] as String,
        password: json['password'] as String,
        roleId: json['role_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        if (roleId != null) 'role_id': roleId,
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
