import 'dart:convert';

import 'package:backend/src/auth_service.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/auth/register
/// Self-Service-Tenant-Anlage (Roadmap M1): legt einen neuen Mandanten
/// samt Owner-Benutzer an und gibt direkt ein gültiges JWT zurück.
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

  late final RegisterRequest req;
  try {
    req = RegisterRequest.fromJson(body);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  if (req.companyName.trim().isEmpty ||
      req.email.trim().isEmpty ||
      req.password.length < 8) {
    return Response.json(
      statusCode: 400,
      body: {
        'error': 'validation_failed',
        'message':
            'company_name und email dürfen nicht leer sein, password muss '
                'mindestens 8 Zeichen lang sein.',
      },
    );
  }

  final userRepository = context.read<UserRepository>();
  final tenantRepository = context.read<TenantRepository>();
  final authService = context.read<AuthService>();

  final existing = await userRepository.findByEmail(req.email);
  if (existing != null) {
    return Response.json(
      statusCode: 409,
      body: {'error': 'email_already_registered'},
    );
  }

  final tenant = await tenantRepository.create(req.companyName.trim());
  final passwordHash = authService.hashPassword(req.password);
  final user = await userRepository.create(
    tenantId: tenant.id,
    email: req.email.trim(),
    passwordHash: passwordHash,
    role: UserRole.owner,
  );

  final token = authService.issueToken(
    userId: user.id,
    tenantId: tenant.id,
    email: user.email,
    role: user.role.toJson(),
  );

  final response = AuthResponse(token: token, user: user, tenant: tenant);
  return Response.json(statusCode: 201, body: response.toJson());
}
