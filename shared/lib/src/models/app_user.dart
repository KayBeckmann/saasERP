import 'user_role.dart';

/// Mandanten-Benutzer der User-App.
///
/// Heißt `AppUser`, um Kollisionen mit `dart:io`/Framework-eigenen
/// `User`-Typen zu vermeiden.
///
/// [role] ist seit RF2 nur noch eine grobe, aus [isAdminRole] abgeleitete
/// Anzeige-Näherung (owner/employee) für Code, der die alte binäre
/// Unterscheidung noch nutzt — die tatsächliche, feingranulare Rolle steht
/// in [roleName]/[roleId]. Für Autorisierungsentscheidungen ist ausschließlich
/// der Backend-seitige `AuthorizationService` maßgeblich, nie dieses Feld.
class AppUser {
  const AppUser({
    required this.id,
    required this.tenantId,
    required this.email,
    required this.role,
    required this.createdAt,
    this.isPlatformAdmin = false,
    this.roleId,
    this.roleName,
    this.isAdminRole = false,
  });

  final String id;
  final String tenantId;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  /// `true` für den saasERP-Plattform-Admin (Abo-Verwaltung über alle
  /// Mandanten hinweg, M3) — unabhängig vom mandanten-skopierten [role].
  final bool isPlatformAdmin;

  /// RF2: tatsächliche Rolle im aktuellen Mandanten (falls im jeweiligen
  /// Kontext bekannt, z. B. Mitgliederliste, Login/Me/Tenant-Wechsel).
  final String? roleId;
  final String? roleName;

  /// RF2: `true`, wenn [roleId] die Admin-Rolle des Mandanten ist. Clients
  /// nutzen das für UI-Gating (z. B. Rollenverwaltung ein-/ausblenden) —
  /// die eigentliche Autorisierung bleibt ausschließlich serverseitig
  /// (`AuthorizationService`), dieses Feld ist reine Anzeige-Bequemlichkeit.
  final bool isAdminRole;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        email: json['email'] as String,
        role: UserRole.fromJson(json['role'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        isPlatformAdmin: json['is_platform_admin'] as bool? ?? false,
        roleId: json['role_id'] as String?,
        roleName: json['role_name'] as String?,
        isAdminRole: json['is_admin_role'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'email': email,
        'role': role.toJson(),
        'created_at': createdAt.toIso8601String(),
        'is_platform_admin': isPlatformAdmin,
        if (roleId != null) 'role_id': roleId,
        if (roleName != null) 'role_name': roleName,
        'is_admin_role': isAdminRole,
      };

  AppUser copyWith({String? roleId, String? roleName, bool? isAdminRole}) => AppUser(
        id: id,
        tenantId: tenantId,
        email: email,
        role: role,
        createdAt: createdAt,
        isPlatformAdmin: isPlatformAdmin,
        roleId: roleId ?? this.roleId,
        roleName: roleName ?? this.roleName,
        isAdminRole: isAdminRole ?? this.isAdminRole,
      );
}
