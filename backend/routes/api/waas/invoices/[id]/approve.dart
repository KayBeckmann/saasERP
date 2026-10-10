import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/repositories/waas_invoice_document_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Owner-only release: persist the PDF/XML pair and approval in one transaction.
/// No email or debit. Existing approvals cannot be regenerated.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final auth = authenticateRequest(context);
  if (auth == null)
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  if (auth.role != UserRole.owner.toJson()) {
    return Response.json(statusCode: 403, body: {'error': 'forbidden'});
  }
  final invoice = await context.read<InvoiceRepository>().findById(
    tenantId: auth.tenantId,
    id: id,
  );
  if (invoice == null || invoice.customerId == null || invoice.items.isEmpty) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  final tenant = await context.read<TenantRepository>().findById(auth.tenantId);
  final customer = await context.read<CustomerRepository>().findById(
    tenantId: auth.tenantId,
    id: invoice.customerId!,
  );
  if (tenant == null || customer == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  final approved = await context.read<WaasInvoiceDocumentRepository>().approve(
    tenantId: auth.tenantId,
    invoiceId: id,
    actorId: auth.userId,
    invoice: invoice,
    tenant: tenant,
    customer: customer,
  );
  if (!approved) {
    return Response.json(
      statusCode: 404,
      body: {'error': 'not_found_or_already_approved'},
    );
  }
  return Response.json(body: {'approved': true, 'document_version': 1});
}
