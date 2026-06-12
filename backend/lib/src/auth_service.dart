import 'package:bcrypt/bcrypt.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'config.dart';

/// Passwort-Hashing (bcrypt) und JWT-Erstellung/-Validierung mit Tenant-Scope.
///
/// Die eigentliche Token-Logik steckt in [TokenCodec] (`saaserp_shared`),
/// damit sie auch von der Kunden-App zur lokalen Token-Prüfung genutzt
/// werden kann.
class AuthService {
  AuthService(AppConfig config) : _tokenCodec = TokenCodec(config.jwtSecret);

  final TokenCodec _tokenCodec;

  String hashPassword(String password) =>
      BCrypt.hashpw(password, BCrypt.gensalt());

  bool verifyPassword(String password, String hash) =>
      BCrypt.checkpw(password, hash);

  String issueToken({
    required String userId,
    required String tenantId,
    required String email,
    required String role,
  }) =>
      _tokenCodec.issue(
        userId: userId,
        tenantId: tenantId,
        email: email,
        role: role,
      );

  /// Validiert das Bearer-Token und gibt den dekodierten Payload zurück.
  /// Wirft [JWTException], wenn das Token ungültig/abgelaufen ist.
  AuthTokenPayload verifyToken(String token) => _tokenCodec.verify(token);
}
