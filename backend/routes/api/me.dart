import 'package:backend/src/authorization_service.dart';
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

  final rawUser = await userRepository.findById(auth.userId);
  final tenant = await tenantRepository.findById(auth.tenantId);
  if (rawUser == null || tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  // RF2: aktuelle Rolle live nachladen (siehe login.dart) — nötig, damit die
  // App auch nach restoreSession() (kein Login-Response verfügbar) ihre
  // eigene roleId/roleName/isAdminRole kennt.
  final authz = await context.read<AuthorizationService>().loadContext(
        userId: auth.userId,
        tenantId: auth.tenantId,
      );
  final user = authz == null
      ? rawUser
      : rawUser.copyWith(
          roleId: authz.roleId,
          roleName: authz.roleName,
          isAdminRole: authz.isAdminRole,
        );

  return Response.json(body: {
    'user': user.toJson(),
    'tenant': tenant.toJson(),
  });
}
