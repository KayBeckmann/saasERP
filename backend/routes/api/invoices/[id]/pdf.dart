import 'package:backend/src/pdf/invoice_pdf_builder.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/invoices/<id>/pdf — Rechnung als PDF.
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

  final tenant = await context.read<TenantRepository>().findById(auth.tenantId);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final customerId = invoice.customerId;
  final customer = customerId == null
      ? null
      : await context.read<CustomerRepository>().findById(tenantId: auth.tenantId, id: customerId);

  final bytes = await buildInvoicePdf(invoice: invoice, tenant: tenant, customer: customer);

  return Response.bytes(
    body: bytes,
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'inline; filename="${invoice.invoiceNumber}.pdf"',
    },
  );
}
