import 'dart:convert';

import 'package:backend/src/auth_service.dart';
import 'package:backend/src/repositories/tenant_access_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET  /api/users — Mitarbeiterliste des Mandanten (nur Owner).
/// POST /api/users — neuen Mitarbeiter anlegen (nur Owner).
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }
  if (auth.role != UserRole.owner.toJson()) {
    return Response.json(statusCode: 403, body: {'error': 'forbidden'});
  }

  final userRepository = context.read<UserRepository>();

  if (context.request.method == HttpMethod.get) {
    final users = await userRepository.listForTenant(auth.tenantId);
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

    // Owner kann nur employee-Konten anlegen, nicht weitere Owner
    if (req.role == UserRole.owner) {
      return Response.json(statusCode: 400, body: {'error': 'cannot_create_owner'});
    }

    final existing = await userRepository.findByEmail(req.email.trim());
    if (existing != null) {
      return Response.json(statusCode: 409, body: {'error': 'email_already_registered'});
    }

    final authService = context.read<AuthService>();
    final tenantAccessRepository = context.read<TenantAccessRepository>();

    final passwordHash = authService.hashPassword(req.password);
    final user = await userRepository.create(
      tenantId: auth.tenantId,
      email: req.email.trim(),
      passwordHash: passwordHash,
      role: req.role,
    );
    await tenantAccessRepository.grant(
      userId: user.id,
      tenantId: auth.tenantId,
      role: user.role.toJson(),
    );

    return Response.json(statusCode: 201, body: user.toJson());
  }

  return Response(statusCode: 405);
}
