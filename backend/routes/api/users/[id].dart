import 'package:backend/src/repositories/user_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// DELETE /api/users/<id> — Mitarbeiter aus dem Mandanten entfernen (nur Owner).
/// Der Owner kann sich nicht selbst entfernen.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.delete) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }
  if (auth.role != UserRole.owner.toJson()) {
    return Response.json(statusCode: 403, body: {'error': 'forbidden'});
  }
  if (auth.userId == id) {
    return Response.json(statusCode: 400, body: {'error': 'cannot_remove_self'});
  }

  final userRepository = context.read<UserRepository>();
  final removed = await userRepository.removeFromTenant(
    userId: id,
    tenantId: auth.tenantId,
  );
  if (!removed) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  return Response(statusCode: 204);
}
