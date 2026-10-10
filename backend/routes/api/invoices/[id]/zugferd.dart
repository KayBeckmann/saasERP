import 'dart:convert';

import 'package:backend/src/pdf/zugferd_xml_builder.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/repositories/waas_invoice_document_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/invoices/<id>/zugferd — separates, nicht extern validiertes
/// CII-XML. Keine Zusage für EN 16931, XRechnung oder PDF/A-3.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final documents = context.read<WaasInvoiceDocumentRepository>();
  if (await documents.isWaasInvoice(tenantId: auth.tenantId, invoiceId: id)) {
    final issued = await documents.read(tenantId: auth.tenantId, invoiceId: id);
    if (issued == null)
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    return Response.bytes(
      body: issued.xml,
      headers: {
        'Content-Type': 'application/xml; charset=UTF-8',
        'Content-Disposition':
            'attachment; filename="invoice-v${issued.version}.xml"',
      },
    );
  }
  final invoice = await context.read<InvoiceRepository>().findPublishedById(
    tenantId: auth.tenantId,
    id: id,
  );
  if (invoice == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  if (invoice.items.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {
        'error': 'no_items',
        'message':
            'Eine Rechnung ohne Positionen kann nicht als E-Rechnung exportiert werden.',
      },
    );
  }

  final tenant = await context.read<TenantRepository>().findById(auth.tenantId);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final customerId = invoice.customerId;
  final customer = customerId == null
      ? null
      : await context.read<CustomerRepository>().findById(
          tenantId: auth.tenantId,
          id: customerId,
        );

  final xml = buildZugferdXml(
    invoice: invoice,
    tenant: tenant,
    customer: customer,
  );
  final bytes = utf8.encode(xml);

  return Response.bytes(
    body: bytes,
    headers: {
      'Content-Type': 'application/xml; charset=UTF-8',
      'Content-Disposition':
          'attachment; filename="${invoice.invoiceNumber}-facturx.xml"',
    },
  );
}
