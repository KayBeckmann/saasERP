import 'dart:convert';

import 'package:backend/src/repositories/platform_invoice_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/platform/tenants/<id>/invoices/<invoiceId>/mark-paid — manuelle
/// Zahlungserfassung (M4): markiert eine offene/überfällige Plattform-Rechnung
/// als bezahlt. `paid_at` ist optional, Default: heute.
Future<Response> onRequest(RequestContext context, String id, String invoiceId) async {
  final auth = authenticateRequest(context);
  if (auth == null || !auth.isPlatformAdmin) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  var paidAt = DateTime.now();
  final rawBody = await context.request.body();
  if (rawBody.isNotEmpty) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(rawBody) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    if (body['paid_at'] != null) {
      try {
        paidAt = DateTime.parse(body['paid_at'] as String);
      } on TypeError {
        return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
      } on FormatException {
        return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
      }
    }
  }

  final platformInvoiceRepository = context.read<PlatformInvoiceRepository>();
  final invoice = await platformInvoiceRepository.markPaid(tenantId: id, id: invoiceId, paidAt: paidAt);
  if (invoice == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  return Response.json(body: invoice.toJson());
}
