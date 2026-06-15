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
    this.isPlatformAdmin = false,
  });

  final String id;
  final String tenantId;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  /// `true` für den saasERP-Plattform-Admin (Abo-Verwaltung über alle
  /// Mandanten hinweg, M3) — unabhängig vom mandanten-skopierten [role].
  final bool isPlatformAdmin;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        email: json['email'] as String,
        role: UserRole.fromJson(json['role'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        isPlatformAdmin: json['is_platform_admin'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'email': email,
        'role': role.toJson(),
        'created_at': createdAt.toIso8601String(),
        'is_platform_admin': isPlatformAdmin,
      };
}
