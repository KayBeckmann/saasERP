import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/me — geschützter Endpunkt, liefert den aktuell eingeloggten
/// Benutzer + Mandanten für das User-App-Dashboard.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final userRepository = context.read<UserRepository>();
  final tenantRepository = context.read<TenantRepository>();

  final user = await userRepository.findById(auth.userId);
  final tenant = await tenantRepository.findById(auth.tenantId);
  if (user == null || tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  return Response.json(body: {
    'user': user.toJson(),
    'tenant': tenant.toJson(),
  });
}
