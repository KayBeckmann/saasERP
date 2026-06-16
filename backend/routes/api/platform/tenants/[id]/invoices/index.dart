import 'dart:convert';

import 'package:backend/src/repositories/platform_invoice_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/platform/tenants/<id>/invoices — Plattform-Rechnungen eines
/// Mandanten (Plattform-Admin).
/// POST /api/platform/tenants/<id>/invoices — neue Plattform-Rechnung für
/// den Mandanten anlegen (M4 — "Eat your own dog food").
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null || !auth.isPlatformAdmin) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final platformInvoiceRepository = context.read<PlatformInvoiceRepository>();

  if (context.request.method == HttpMethod.get) {
    final invoices = await platformInvoiceRepository.listForTenant(id);
    return Response.json(body: {'invoices': invoices.map((i) => i.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreatePlatformInvoiceRequest req;
    try {
      req = CreatePlatformInvoiceRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (!req.periodEnd.isAfter(req.periodStart)) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'period_end muss nach period_start liegen.'},
      );
    }

    final invoice = await platformInvoiceRepository.create(tenantId: id, req: req);
    return Response.json(statusCode: 201, body: invoice.toJson());
  }

  return Response(statusCode: 405);
}
