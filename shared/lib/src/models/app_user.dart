import 'user_role.dart';

/// Mandanten-Benutzer der User-App (Owner/Mitarbeiter).
///
/// Heißt `AppUser`, um Kollisionen mit `dart:io`/Framework-eigenen
/// `User`-Typen zu vermeiden.
class AppUser {
  const AppUser({
    required this.id,
    required this.tenantId,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        email: json['email'] as String,
        role: UserRole.fromJson(json['role'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'email': email,
        'role': role.toJson(),
        'created_at': createdAt.toIso8601String(),
      };
}
