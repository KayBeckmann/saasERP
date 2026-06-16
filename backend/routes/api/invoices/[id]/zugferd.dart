import 'dart:convert';

import 'package:backend/src/pdf/zugferd_xml_builder.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/invoices/<id>/zugferd — Rechnung als ZUGFeRD 2.1 Basic / Factur-X
/// XML (EN 16931). Kann direkt in Buchhaltungs-Software importiert werden
/// oder als Anhang in ein PDF/A-3b-Dokument eingebettet werden.
///
/// Für XRechnung (B2G) ist das erzeugte XML ebenfalls geeignet — die
/// Leitweg-ID des Kunden wird als `BuyerReference` übernommen, sofern
/// hinterlegt.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final invoice = await context.read<InvoiceRepository>().findById(tenantId: auth.tenantId, id: id);
  if (invoice == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  if (invoice.items.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'no_items', 'message': 'Eine Rechnung ohne Positionen kann nicht als E-Rechnung exportiert werden.'},
    );
  }

  final tenant = await context.read<TenantRepository>().findById(auth.tenantId);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final customerId = invoice.customerId;
  final customer = customerId == null
      ? null
      : await context.read<CustomerRepository>().findById(tenantId: auth.tenantId, id: customerId);

  final xml = buildZugferdXml(invoice: invoice, tenant: tenant, customer: customer);
  final bytes = utf8.encode(xml);

  return Response.bytes(
    body: bytes,
    headers: {
      'Content-Type': 'application/xml; charset=UTF-8',
      'Content-Disposition': 'attachment; filename="${invoice.invoiceNumber}-facturx.xml"',
    },
  );
}
