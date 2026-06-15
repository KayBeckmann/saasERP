import 'dart:convert';

import 'package:backend/src/auth_service.dart';
import 'package:backend/src/repositories/customer_portal_account_repository.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/customer-invites/<token>/accept — Endkunde vergibt sein
/// Passwort über den Einladungslink. Aktiviert den Zugang und gibt direkt
/// ein JWT (Rolle `customer`) zurück.
Future<Response> onRequest(RequestContext context, String token) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
  }

  late final AcceptCustomerInviteRequest req;
  try {
    req = AcceptCustomerInviteRequest.fromJson(body);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  if (req.password.length < 8) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'validation_failed', 'message': 'password muss mindestens 8 Zeichen lang sein.'},
    );
  }

  final portalAccountRepository = context.read<CustomerPortalAccountRepository>();
  final customerRepository = context.read<CustomerRepository>();
  final tenantRepository = context.read<TenantRepository>();
  final authService = context.read<AuthService>();

  final passwordHash = authService.hashPassword(req.password);
  final account = await portalAccountRepository.acceptInvite(
    inviteToken: token,
    passwordHash: passwordHash,
  );
  if (account == null) {
    return Response.json(statusCode: 404, body: {'error': 'invite_not_found_or_used'});
  }

  final customer = await customerRepository.findById(tenantId: account.tenantId, id: account.customerId);
  final tenant = await tenantRepository.findById(account.tenantId);
  if (customer == null || tenant == null) {
    return Response.json(statusCode: 500, body: {'error': 'tenant_missing'});
  }

  final jwt = authService.issueToken(
    userId: account.id,
    tenantId: account.tenantId,
    email: account.email,
    role: 'customer',
  );

  final response = CustomerAuthResponse(
    token: jwt,
    account: account,
    customerName: customer.name,
    tenantName: tenant.name,
    tenantBrandingColor: tenant.brandingColor,
    tenantLogoUrl: tenant.logoUrl,
  );
  return Response.json(body: response.toJson());
}
