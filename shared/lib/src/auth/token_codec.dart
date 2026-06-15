import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'auth_token_payload.dart';

/// Gemeinsame JWT-Logik für Backend (Ausstellung/Verifikation) und Apps
/// (lokale Prüfung von Ablauf und Claims ohne Backend-Roundtrip).
class TokenCodec {
  const TokenCodec(this._secret);

  final String _secret;

  /// Signiert ein neues Token mit Tenant-Scope (Backend-seitig).
  String issue({
    required String userId,
    required String tenantId,
    required String email,
    required String role,
    bool isPlatformAdmin = false,
    Duration validFor = const Duration(hours: 12),
  }) {
    final jwt = JWT(
      {
        'tenant_id': tenantId,
        'email': email,
        'role': role,
        'is_platform_admin': isPlatformAdmin,
      },
      subject: userId,
    );
    return jwt.sign(SecretKey(_secret), expiresIn: validFor);
  }

  /// Verifiziert Signatur + Ablauf und gibt die Claims zurück.
  /// Wirft [JWTException], wenn das Token ungültig/abgelaufen ist.
  AuthTokenPayload verify(String token) {
    final jwt = JWT.verify(token, SecretKey(_secret));
    return AuthTokenPayload.fromJwtPayload(jwt.payload as Map<String, dynamic>);
  }

  /// Decodiert die Claims ohne Signaturprüfung — z. B. damit Apps das
  /// Ablaufdatum lokal prüfen können, bevor ein Request ans Backend geht.
  static AuthTokenPayload decodeUnverified(String token) {
    final jwt = JWT.decode(token);
    return AuthTokenPayload.fromJwtPayload(jwt.payload as Map<String, dynamic>);
  }
}
