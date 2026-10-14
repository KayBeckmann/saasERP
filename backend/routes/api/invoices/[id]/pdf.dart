import 'package:backend/src/pdf/invoice_pdf_builder.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/repositories/waas_invoice_document_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/invoices/<id>/pdf — Rechnung als PDF.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = await requirePermission(context, module: PermissionModule.invoices, action: PermissionAction.export);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final documents = context.read<WaasInvoiceDocumentRepository>();
  if (await documents.isWaasInvoice(tenantId: payload.tenantId, invoiceId: id)) {
    final issued = await documents.read(tenantId: payload.tenantId, invoiceId: id);
    if (issued == null)
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    return Response.bytes(
      body: issued.pdf,
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition':
            'inline; filename="invoice-v${issued.version}.pdf"',
      },
    );
  }
  final invoiceRepo = context.read<InvoiceRepository>();
  final invoice = await invoiceRepo.findPublishedById(
    tenantId: payload.tenantId,
    id: id,
  );
  if (invoice == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final tenant = await context.read<TenantRepository>().findById(payload.tenantId);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final customerId = invoice.customerId;
  final customer = customerId == null
      ? null
      : await context.read<CustomerRepository>().findById(
          tenantId: payload.tenantId,
          id: customerId,
        );

  // Für Schlussrechnungen: Vorrechnungen laden und in die Invoice-Instanz injizieren
  Invoice invoiceWithPrior = invoice;
  if (invoice.invoiceType == InvoiceType.closingInvoice &&
      invoice.orderId != null) {
    final priorInvoices = await invoiceRepo.listPriorForOrder(
      tenantId: payload.tenantId,
      orderId: invoice.orderId!,
    );
    // Aktuelle Rechnung aus der Liste ausschließen
    final filtered = priorInvoices
        .where((r) => r.invoiceNumber != invoice.invoiceNumber)
        .toList();
    if (filtered.isNotEmpty) {
      invoiceWithPrior = Invoice.fromJson({
        ...invoice.toJson(),
        'prior_invoices': filtered.map((r) => r.toJson()).toList(),
      });
    }
  }

  final bytes = await buildInvoicePdf(
    invoice: invoiceWithPrior,
    tenant: tenant,
    customer: customer,
  );

  return Response.bytes(
    body: bytes,
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'inline; filename="${invoice.invoiceNumber}.pdf"',
    },
  );
}
