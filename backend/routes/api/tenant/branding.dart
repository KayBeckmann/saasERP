import 'dart:convert';

import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

final _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// PATCH /api/tenant/branding — Branding-Farbe des aktuellen Mandanten
/// setzen oder zurücksetzen (`branding_color: null`). Nur für Owner,
/// Grundlage für mandantenspezifisches Theming (Whitelabel-Potenzial).
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }
  if (auth.role != UserRole.owner.toJson()) {
    return Response.json(statusCode: 403, body: {'error': 'forbidden'});
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
  }

  late final UpdateTenantBrandingRequest req;
  try {
    req = UpdateTenantBrandingRequest.fromJson(body);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  final brandingColor = req.brandingColor;
  if (brandingColor != null && !_hexColor.hasMatch(brandingColor)) {
    return Response.json(
      statusCode: 400,
      body: {
        'error': 'validation_failed',
        'message': 'branding_color muss ein Hex-Code (#RRGGBB) oder null sein.',
      },
    );
  }

  final tenantRepository = context.read<TenantRepository>();
  final tenant = await tenantRepository.updateBranding(
    tenantId: auth.tenantId,
    brandingColor: brandingColor,
  );

  return Response.json(body: tenant.toJson());
}
