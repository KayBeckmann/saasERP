import 'dart:convert';

import 'package:backend/src/auth_service.dart';
import 'package:backend/src/repositories/tenant_access_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/auth/switch_tenant — wechselt den Mandanten-Scope des
/// eingeloggten Nutzers (Tenant-Auswahl für Nutzer mit mehreren Zugängen)
/// und stellt ein neu skopiertes JWT für den Ziel-Mandanten aus.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
  }

  late final SwitchTenantRequest req;
  try {
    req = SwitchTenantRequest.fromJson(body);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  final tenantAccessRepository = context.read<TenantAccessRepository>();
  final role = await tenantAccessRepository.roleForUserAndTenant(
    userId: auth.userId,
    tenantId: req.tenantId,
  );
  if (role == null) {
    return Response.json(
      statusCode: 403,
      body: {'error': 'tenant_access_denied'},
    );
  }

  final tenantRepository = context.read<TenantRepository>();
  final userRepository = context.read<UserRepository>();
  final authService = context.read<AuthService>();

  final tenant = await tenantRepository.findById(req.tenantId);
  final user = await userRepository.findById(auth.userId);
  if (tenant == null || user == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final token = authService.issueToken(
    userId: user.id,
    tenantId: tenant.id,
    email: user.email,
    role: role,
  );

  final response = AuthResponse(token: token, user: user, tenant: tenant);
  return Response.json(body: response.toJson());
}
