import 'package:backend/src/pdf/dunning_pdf_builder.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/invoices/<id>/dunning-pdf — Mahnung als PDF, passend zur
/// aktuellen Mahnstufe der Rechnung.
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

  if (invoice.dunningLevel < 1) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'not_dunned', 'message': 'Für diese Rechnung wurde noch keine Mahnung erstellt.'},
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

  final bytes = await buildDunningPdf(invoice: invoice, tenant: tenant, customer: customer);

  return Response.bytes(
    body: bytes,
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'inline; filename="Mahnung-${invoice.invoiceNumber}.pdf"',
    },
  );
}
