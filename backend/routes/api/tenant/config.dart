import 'dart:convert';

import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// PATCH /api/tenant/config — Firmendaten, Logo und Steuersätze des
/// aktuellen Mandanten setzen. Nur für Owner.
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

  late final UpdateTenantConfigRequest req;
  try {
    req = UpdateTenantConfigRequest.fromJson(body);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  if (req.defaultVatRate < 0 || req.reducedVatRate < 0) {
    return Response.json(
      statusCode: 400,
      body: {
        'error': 'validation_failed',
        'message': 'Steuersätze dürfen nicht negativ sein.',
      },
    );
  }

  final tenantRepository = context.read<TenantRepository>();
  final tenant = await tenantRepository.updateConfig(
    tenantId: auth.tenantId,
    config: req,
  );

  return Response.json(body: tenant.toJson());
}
