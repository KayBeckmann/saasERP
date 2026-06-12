import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'auth_service.dart';

/// Liest und validiert den `Authorization: Bearer <token>`-Header.
///
/// Gibt `null` zurück, wenn der Header fehlt oder das Token ungültig/
/// abgelaufen ist — der Aufrufer antwortet dann mit 401.
AuthTokenPayload? authenticateRequest(RequestContext context) {
  final header = context.request.headers['Authorization'];
  if (header == null || !header.startsWith('Bearer ')) return null;

  final token = header.substring('Bearer '.length);
  final authService = context.read<AuthService>();
  try {
    return authService.verifyToken(token);
  } on JWTException {
    return null;
  }
}
