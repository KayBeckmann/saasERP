/// Decodierte Claims eines saasERP-JWT (Tenant-Scope, Rolle, Identität).
class AuthTokenPayload {
  const AuthTokenPayload({
    required this.userId,
    required this.tenantId,
    required this.email,
    required this.role,
    required this.expiresAt,
    this.isPlatformAdmin = false,
  });

  final String userId;
  final String tenantId;
  final String email;
  final String role;
  final DateTime expiresAt;

  /// `true` für den saasERP-Plattform-Admin (Abo-Verwaltung über alle
  /// Mandanten hinweg, M3) — unabhängig vom mandanten-skopierten [role].
  final bool isPlatformAdmin;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory AuthTokenPayload.fromJwtPayload(Map<String, dynamic> payload) =>
      AuthTokenPayload(
        userId: payload['sub'] as String,
        tenantId: payload['tenant_id'] as String,
        email: payload['email'] as String,
        role: payload['role'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          (payload['exp'] as int) * 1000,
          isUtc: true,
        ),
        isPlatformAdmin: payload['is_platform_admin'] as bool? ?? false,
      );
}
