import 'dart:async';
import 'dart:convert';

import 'package:backend/src/notification_service.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/invoices/<id> — einzelne Rechnung lesen.
/// PATCH /api/invoices/<id> — Rechnung aktualisieren.
/// DELETE /api/invoices/<id> — Rechnung löschen.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final invoiceRepository = context.read<InvoiceRepository>();

  if (context.request.method == HttpMethod.get) {
    final invoice = await invoiceRepository.findById(tenantId: auth.tenantId, id: id);
    if (invoice == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: invoice.toJson());
  }

  if (context.request.method == HttpMethod.patch) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final UpdateInvoiceRequest req;
    try {
      req = UpdateInvoiceRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.title.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'title darf nicht leer sein.'},
      );
    }

    final existing = await invoiceRepository.findById(tenantId: auth.tenantId, id: id);
    final invoice = await invoiceRepository.update(tenantId: auth.tenantId, id: id, req: req);
    if (invoice == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }

    if (invoice.status == InvoiceStatus.sent && existing?.status != InvoiceStatus.sent) {
      final notificationService = context.read<NotificationService>();
      unawaited(notificationService.notifyCustomerNewInvoice(tenantId: auth.tenantId, invoice: invoice));
    }

    return Response.json(body: invoice.toJson());
  }

  if (context.request.method == HttpMethod.delete) {
    final deleted = await invoiceRepository.delete(tenantId: auth.tenantId, id: id);
    if (!deleted) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}
