import 'dart:convert';

import 'package:backend/src/auth_service.dart';
import 'package:backend/src/repositories/role_repository.dart';
import 'package:backend/src/repositories/tenant_access_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET  /api/users — Mitgliederliste des Mandanten (RF2: Modul `members`).
/// POST /api/users — neues Mitglied einladen/anlegen (RF2: Modul `members`,
/// Aktion `create`). Ohne `role_id` bekommt der neue Zugang die
/// "Nur Lesen"-Rolle (Least Privilege, siehe CreateEmployeeRequest-Doc).
/// Nur ein Mitglied mit der Admin-Rolle darf einem neuen Mitglied selbst die
/// Admin-Rolle zuweisen (Selbst-Eskalationsschutz).
Future<Response> onRequest(RequestContext context) async {
  final action = context.request.method == HttpMethod.post
      ? PermissionAction.create
      : PermissionAction.view;
  final auth = await requirePermission(context, module: PermissionModule.members, action: action);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;
  final authz = auth.authz!;

  final userRepository = context.read<UserRepository>();

  if (context.request.method == HttpMethod.get) {
    final users = await userRepository.listForTenant(payload.tenantId);
    return Response.json(body: {'users': users.map((u) => u.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateEmployeeRequest req;
    try {
      req = CreateEmployeeRequest.fromJson(body);
    } catch (_) {
      return Response.json(statusCode: 400, body: {'error': 'validation_failed'});
    }

    if (req.email.trim().isEmpty || req.password.length < 8) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'validation_failed',
          'message': 'email darf nicht leer sein, password muss mindestens 8 Zeichen haben.',
        },
      );
    }

    final roleRepository = context.read<RoleRepository>();
    String targetRoleId;
    if (req.roleId != null) {
      final targetRole = await roleRepository.findById(tenantId: payload.tenantId, roleId: req.roleId!);
      if (targetRole == null) {
        return Response.json(statusCode: 400, body: {'error': 'invalid_role'});
      }
      // Selbst-Eskalationsschutz: nur ein Admin darf eine weitere Admin-Rolle
      // vergeben (RF2-Sicherheitsvertrag: "keine Selbst-Eskalation").
      if (targetRole.isAdminRole && !authz.isAdminRole) {
        return Response.json(statusCode: 403, body: {'error': 'cannot_grant_admin_role'});
      }
      targetRoleId = targetRole.id;
    } else {
      final roles = await roleRepository.listForTenant(payload.tenantId);
      targetRoleId = roles.firstWhere((r) => r.name == 'Nur Lesen').id;
    }

    final existing = await userRepository.findByEmail(req.email.trim());
    if (existing != null) {
      return Response.json(statusCode: 409, body: {'error': 'email_already_registered'});
    }

    final authService = context.read<AuthService>();
    final tenantAccessRepository = context.read<TenantAccessRepository>();

    final passwordHash = authService.hashPassword(req.password);
    final user = await userRepository.create(
      tenantId: payload.tenantId,
      email: req.email.trim(),
      passwordHash: passwordHash,
      // users.role ist nur noch die grobe Anzeige-Näherung (siehe
      // UserRepository-Klassendoc), nicht die eigentliche RF2-Rolle.
      role: UserRole.employee,
    );
    await tenantAccessRepository.grant(
      userId: user.id,
      tenantId: payload.tenantId,
      roleId: targetRoleId,
    );

    return Response.json(statusCode: 201, body: user.toJson());
  }

  return Response(statusCode: 405);
}
