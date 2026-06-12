import 'dart:convert';

import 'package:backend/src/auth_service.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/auth/login
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
  }

  late final LoginRequest req;
  try {
    req = LoginRequest.fromJson(body);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  final userRepository = context.read<UserRepository>();
  final tenantRepository = context.read<TenantRepository>();
  final authService = context.read<AuthService>();

  final record = await userRepository.findByEmail(req.email);
  if (record == null ||
      !authService.verifyPassword(req.password, record.passwordHash)) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'invalid_credentials'},
    );
  }

  final tenant = await tenantRepository.findById(record.user.tenantId);
  if (tenant == null) {
    return Response.json(statusCode: 500, body: {'error': 'tenant_missing'});
  }

  final token = authService.issueToken(
    userId: record.user.id,
    tenantId: tenant.id,
    email: record.user.email,
    role: record.user.role.toJson(),
  );

  final response = AuthResponse(token: token, user: record.user, tenant: tenant);
  return Response.json(body: response.toJson());
}
