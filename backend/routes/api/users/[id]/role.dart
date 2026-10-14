import 'dart:convert';

import 'package:backend/src/repositories/role_repository.dart';
import 'package:backend/src/repositories/tenant_access_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// PATCH /api/users/<id>/role — ändert die Rolle eines Mitglieds (RF2: Modul
/// `members`, Aktion `edit`). Rollenwechsel wirkt sofort (keine
/// Session-Invalidierung nötig — `AuthorizationService` liest live).
/// Schutzmechanismen: niemand kann sich selbst die Admin-Rolle entziehen
/// (verhindert versehentlichen Lockout); nur ein Admin darf die Admin-Rolle
/// vergeben (Selbst-Eskalationsschutz); der letzte Admin kann nicht
/// herabgestuft werden.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: 405);
  }

  final auth = await requirePermission(
    context,
    module: PermissionModule.members,
    action: PermissionAction.edit,
  );
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;
  final authz = auth.authz!;

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
  }
  final newRoleId = body['role_id'] as String?;
  if (newRoleId == null || newRoleId.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'role_id_required'});
  }

  final roleRepository = context.read<RoleRepository>();
  final tenantAccessRepository = context.read<TenantAccessRepository>();

  final newRole = await roleRepository.findById(tenantId: payload.tenantId, roleId: newRoleId);
  if (newRole == null) {
    return Response.json(statusCode: 400, body: {'error': 'invalid_role'});
  }
  if (newRole.isAdminRole && !authz.isAdminRole) {
    return Response.json(statusCode: 403, body: {'error': 'cannot_grant_admin_role'});
  }

  final currentRoleId = await tenantAccessRepository.roleIdForUserAndTenant(
    userId: id,
    tenantId: payload.tenantId,
  );
  if (currentRoleId == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  if (payload.userId == id && !newRole.isAdminRole) {
    final currentRole = await roleRepository.findById(tenantId: payload.tenantId, roleId: currentRoleId);
    if (currentRole != null && currentRole.isAdminRole) {
      return Response.json(statusCode: 400, body: {'error': 'cannot_self_demote'});
    }
  }

  if (!newRole.isAdminRole && currentRoleId != newRoleId) {
    final currentRole = await roleRepository.findById(tenantId: payload.tenantId, roleId: currentRoleId);
    if (currentRole != null && currentRole.isAdminRole) {
      final adminCount = await roleRepository.countActiveAdmins(payload.tenantId);
      if (adminCount <= 1) {
        return Response.json(statusCode: 400, body: {'error': 'cannot_demote_last_admin'});
      }
    }
  }

  await tenantAccessRepository.grant(
    userId: id,
    tenantId: payload.tenantId,
    roleId: newRoleId,
  );

  return Response.json(body: {'role_id': newRole.id, 'role_name': newRole.name});
}
