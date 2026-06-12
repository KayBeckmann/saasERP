import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'config.dart';

class AuthTokenPayload {
  AuthTokenPayload({
    required this.userId,
    required this.tenantId,
    required this.email,
    required this.role,
  });

  final String userId;
  final String tenantId;
  final String email;
  final String role;
}

/// Passwort-Hashing (bcrypt) und JWT-Erstellung/-Validierung mit Tenant-Scope.
class AuthService {
  AuthService(this._config);

  final AppConfig _config;

  String hashPassword(String password) =>
      BCrypt.hashpw(password, BCrypt.gensalt());

  bool verifyPassword(String password, String hash) =>
      BCrypt.checkpw(password, hash);

  String issueToken({
    required String userId,
    required String tenantId,
    required String email,
    required String role,
  }) {
    final jwt = JWT(
      {
        'tenant_id': tenantId,
        'email': email,
        'role': role,
      },
      subject: userId,
    );
    return jwt.sign(
      SecretKey(_config.jwtSecret),
      expiresIn: const Duration(hours: 12),
    );
  }

  /// Validiert das Bearer-Token und gibt den dekodierten Payload zurück.
  /// Wirft [JWTException], wenn das Token ungültig/abgelaufen ist.
  AuthTokenPayload verifyToken(String token) {
    final jwt = JWT.verify(token, SecretKey(_config.jwtSecret));
    final payload = jwt.payload as Map<String, dynamic>;
    return AuthTokenPayload(
      userId: payload['sub'] as String,
      tenantId: payload['tenant_id'] as String,
      email: payload['email'] as String,
      role: payload['role'] as String,
    );
  }
}
