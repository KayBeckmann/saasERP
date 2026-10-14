import 'dart:convert';

import 'package:backend/src/repositories/role_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET  /api/roles — alle Rollen des Mandanten samt Berechtigungen (RF2:
/// Modul `members`, Aktion `view` — wer Mitglieder sehen darf, darf auch
/// die verfügbaren Rollen sehen, z. B. für einen Rollen-Auswahldialog).
/// POST /api/roles — neue anpassbare Rolle anlegen (Modul `members`,
/// Aktion `create`). Nur ein Admin darf eine Rolle mit Admin-Rechten auf
/// irgendeinem Modul anlegen (Selbst-Eskalationsschutz).
Future<Response> onRequest(RequestContext context) async {
  final action = context.request.method == HttpMethod.post
      ? PermissionAction.create
      : PermissionAction.view;
  final auth = await requirePermission(context, module: PermissionModule.members, action: action);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;
  final authz = auth.authz!;

  final roleRepository = context.read<RoleRepository>();

  if (context.request.method == HttpMethod.get) {
    final roles = await roleRepository.listForTenant(payload.tenantId);
    return Response.json(body: {'roles': roles.map((r) => r.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
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
    if (req.name.trim().isEmpty) {
      return Response.json(statusCode: 400, body: {'error': 'name_required'});
    }
    // Selbst-Eskalationsschutz: eine neue Rolle darf keine Berechtigung
    // enthalten, die der anlegende Nutzer selbst nicht hat.
    if (!authz.isAdminRole) {
      final denied = req.permissions.where((p) => !authz.can(p.module, p.action)).toList();
      if (denied.isNotEmpty) {
        return Response.json(statusCode: 403, body: {'error': 'cannot_grant_permissions_you_lack'});
      }
    }

    final role = await roleRepository.create(tenantId: payload.tenantId, req: req);
    return Response.json(statusCode: 201, body: role.toJson());
  }

  return Response(statusCode: 405);
}
