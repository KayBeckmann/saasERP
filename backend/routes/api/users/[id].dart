import 'package:backend/src/repositories/role_repository.dart';
import 'package:backend/src/repositories/tenant_access_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// DELETE /api/users/<id> — Mitglied aus dem Mandanten entfernen (RF2:
/// Modul `members`, Aktion `delete`). Niemand kann sich selbst entfernen;
/// der letzte Träger der Admin-Rolle kann nicht entfernt werden
/// (Admin-Governance, verhindert einen mandantenweiten Lockout).
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.delete) {
    return Response(statusCode: 405);
  }

  final auth = await requirePermission(
    context,
    module: PermissionModule.members,
    action: PermissionAction.delete,
  );
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  if (payload.userId == id) {
    return Response.json(statusCode: 400, body: {'error': 'cannot_remove_self'});
  }

  final tenantAccessRepository = context.read<TenantAccessRepository>();
  final roleRepository = context.read<RoleRepository>();

  final targetRoleId = await tenantAccessRepository.roleIdForUserAndTenant(
    userId: id,
    tenantId: payload.tenantId,
  );
  if (targetRoleId == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  final targetRole = await roleRepository.findById(tenantId: payload.tenantId, roleId: targetRoleId);
  if (targetRole != null && targetRole.isAdminRole) {
    final adminCount = await roleRepository.countActiveAdmins(payload.tenantId);
    if (adminCount <= 1) {
      return Response.json(statusCode: 400, body: {'error': 'cannot_remove_last_admin'});
    }
  }

  final userRepository = context.read<UserRepository>();
  final removed = await userRepository.removeFromTenant(
    userId: id,
    tenantId: payload.tenantId,
  );
  if (!removed) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  return Response(statusCode: 204);
}
