import 'dart:convert';

import 'package:backend/src/auth_service.dart';
import 'package:backend/src/repositories/customer_portal_account_repository.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/customer-auth/login — Login für Kundenportal-Zugänge
/// (`app_kunde`). Öffentlich, kein Tenant-Scope erforderlich.
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

  late final CustomerLoginRequest req;
  try {
    req = CustomerLoginRequest.fromJson(body);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  final portalAccountRepository = context.read<CustomerPortalAccountRepository>();
  final customerRepository = context.read<CustomerRepository>();
  final tenantRepository = context.read<TenantRepository>();
  final authService = context.read<AuthService>();

  final record = await portalAccountRepository.findByEmail(req.email);
  if (record == null || !authService.verifyPassword(req.password, record.passwordHash)) {
    return Response.json(statusCode: 401, body: {'error': 'invalid_credentials'});
  }

  final account = record.account;
  final customer = await customerRepository.findById(tenantId: account.tenantId, id: account.customerId);
  final tenant = await tenantRepository.findById(account.tenantId);
  if (customer == null || tenant == null) {
    return Response.json(statusCode: 500, body: {'error': 'tenant_missing'});
  }

  final token = authService.issueToken(
    userId: account.id,
    tenantId: account.tenantId,
    email: account.email,
    role: 'customer',
  );

  final response = CustomerAuthResponse(
    token: token,
    account: account,
    customerName: customer.name,
    tenantName: tenant.name,
    tenantBrandingColor: tenant.brandingColor,
  );
  return Response.json(body: response.toJson());
}
