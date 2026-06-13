import 'dart:convert';

import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/invoices — Rechnungsliste des aktuellen Mandanten.
/// POST /api/invoices — neue Rechnung anlegen.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final invoiceRepository = context.read<InvoiceRepository>();

  if (context.request.method == HttpMethod.get) {
    final invoices = await invoiceRepository.list(auth.tenantId);
    return Response.json(body: {'invoices': invoices.map((i) => i.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateInvoiceRequest req;
    try {
      req = CreateInvoiceRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.title.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'title darf nicht leer sein.'},
      );
    }

    final invoice = await invoiceRepository.create(tenantId: auth.tenantId, req: req);
    return Response.json(statusCode: 201, body: invoice.toJson());
  }

  return Response(statusCode: 405);
}
