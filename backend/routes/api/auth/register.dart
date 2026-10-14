import 'dart:async';
import 'dart:convert';

import 'package:backend/src/auth_service.dart';
import 'package:backend/src/notification_service.dart';
import 'package:backend/src/repositories/role_repository.dart';
import 'package:backend/src/repositories/subscription_repository.dart';
import 'package:backend/src/repositories/tenant_access_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:backend/src/tenant_encryption_service.dart';
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
  final tenantAccessRepository = context.read<TenantAccessRepository>();
  final tenantEncryptionService = context.read<TenantEncryptionService>();
  final roleRepository = context.read<RoleRepository>();
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
  // RF2: Rollenvorlagen anlegen (Admin/Buchhaltung/.../Nur Lesen) und den
  // registrierenden Nutzer als Admin dieses Mandanten eintragen — die
  // eigentliche Autorisierung läuft ab hier ausschließlich über role_id/
  // role_permissions, nicht mehr über users.role (siehe request_auth.dart).
  final adminRoleId = await roleRepository.ensureBuiltinRoles(tenant.id);
  await tenantAccessRepository.grant(
    userId: user.id,
    tenantId: tenant.id,
    roleId: adminRoleId,
  );
  await tenantEncryptionService.provisionTenant(tenant.id);
  // Die registrierende Person ist immer Admin ihres neuen Mandanten —
  // roleId/roleName/isAdminRole direkt aus der gerade erfolgten Zuweisung
  // übernehmen, ohne zusätzliche Abfrage.
  final enrichedUser = user.copyWith(roleId: adminRoleId, roleName: 'Admin', isAdminRole: true);

  final tierId = req.tierId;
  if (tierId != null && tierId.isNotEmpty) {
    final subscriptionRepository = context.read<SubscriptionRepository>();
    final now = DateTime.now();
    await subscriptionRepository.create(
      tenantId: tenant.id,
      req: CreateSubscriptionRequest(
        tierId: tierId,
        termMonths: 12,
        startDate: now,
        endDate: DateTime(now.year + 1, now.month, now.day),
        downPayment: req.downPayment,
      ),
    );
  }

  final token = authService.issueToken(
    userId: enrichedUser.id,
    tenantId: tenant.id,
    email: enrichedUser.email,
    // Anzeige-Metadaten (siehe request_auth.dart) — die registrierende
    // Person ist immer Admin ihres neuen Mandanten.
    role: 'Admin',
    isPlatformAdmin: enrichedUser.isPlatformAdmin,
  );

  unawaited(context.read<NotificationService>().notifyOwnerWelcome(
        email: enrichedUser.email,
        companyName: tenant.name,
      ));

  final response = AuthResponse(token: token, user: enrichedUser, tenant: tenant);
  return Response.json(statusCode: 201, body: response.toJson());
}
