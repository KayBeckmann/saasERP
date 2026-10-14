import 'dart:convert';

import 'package:backend/src/repositories/role_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// PATCH  /api/roles/<id> — Name/Berechtigungen einer anpassbaren Rolle
/// ändern (RF2: Modul `members`, Aktion `edit`). Die Admin-Rolle behält
/// immer volle Rechte (siehe RoleRepository.update) — nur ihr Name ist
/// änderbar.
/// DELETE /api/roles/<id> — Rolle löschen. Schlägt fehl, wenn es die
/// Admin-Rolle ist oder noch Mitglieder zugewiesen sind.
Future<Response> onRequest(RequestContext context, String id) async {
  final action = context.request.method == HttpMethod.delete
      ? PermissionAction.delete
      : PermissionAction.edit;
  final auth = await requirePermission(context, module: PermissionModule.members, action: action);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;
  final authz = auth.authz!;

  final roleRepository = context.read<RoleRepository>();

  if (context.request.method == HttpMethod.patch) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }
    late final UpsertRoleRequest req;
    try {
      req = UpsertRoleRequest.fromJson(body);
    } catch (_) {
      return Response.json(statusCode: 400, body: {'error': 'validation_failed'});
    }
    if (!authz.isAdminRole) {
      final denied = req.permissions.where((p) => !authz.can(p.module, p.action)).toList();
      if (denied.isNotEmpty) {
        return Response.json(statusCode: 403, body: {'error': 'cannot_grant_permissions_you_lack'});
      }
    }
    final updated = await roleRepository.update(tenantId: payload.tenantId, roleId: id, req: req);
    if (updated == null) return Response.json(statusCode: 404, body: {'error': 'not_found'});
    return Response.json(body: updated.toJson());
  }

  if (context.request.method == HttpMethod.delete) {
    final deleted = await roleRepository.delete(tenantId: payload.tenantId, roleId: id);
    if (!deleted) {
      return Response.json(statusCode: 400, body: {'error': 'cannot_delete_role'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}
