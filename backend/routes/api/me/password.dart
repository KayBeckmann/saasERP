import 'package:backend/src/auth_service.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// PATCH /api/me/password — aktuelles Passwort prüfen und neues setzen.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  final String currentPassword;
  final String newPassword;
  try {
    final req = ChangePasswordRequest.fromJson(body);
    currentPassword = req.currentPassword;
    newPassword = req.newPassword;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'validation_failed'});
  }

  if (newPassword.length < 8) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'password_too_short', 'message': 'Mindestens 8 Zeichen erforderlich.'},
    );
  }

  final authService = context.read<AuthService>();
  final userRepository = context.read<UserRepository>();

  // Aktuellen Hash laden und Passwort prüfen
  final existing = await userRepository.findByEmail(auth.email);
  if (existing == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  if (!authService.verifyPassword(currentPassword, existing.passwordHash)) {
    return Response.json(statusCode: 400, body: {'error': 'wrong_password'});
  }

  final newHash = authService.hashPassword(newPassword);
  await userRepository.updatePassword(userId: auth.userId, newPasswordHash: newHash);

  return Response.json(body: {'status': 'ok'});
}
