import 'package:backend/src/pdf/invoice_pdf_builder.dart';
import 'package:backend/src/repositories/customer_portal_account_repository.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/customer-portal/invoices/<id>/pdf — Rechnung des eingeloggten
/// Endkunden als PDF.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null || auth.role != 'customer') {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final portalAccountRepository = context.read<CustomerPortalAccountRepository>();
  final account = await portalAccountRepository.findById(auth.userId);
  if (account == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final invoice = await context.read<InvoiceRepository>().findById(tenantId: auth.tenantId, id: id);
  if (invoice == null || invoice.customerId != account.customerId) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final tenant = await context.read<TenantRepository>().findById(auth.tenantId);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final customer = await context.read<CustomerRepository>().findById(
        tenantId: auth.tenantId,
        id: account.customerId,
      );

  final bytes = await buildInvoicePdf(invoice: invoice, tenant: tenant, customer: customer);

  return Response.bytes(
    body: bytes,
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'inline; filename="${invoice.invoiceNumber}.pdf"',
    },
  );
}
