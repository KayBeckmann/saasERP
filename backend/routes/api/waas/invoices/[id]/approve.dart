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
  final auth = await requirePermission(context, module: PermissionModule.waas, action: PermissionAction.release);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;
  final invoice = await context.read<InvoiceRepository>().findById(
    tenantId: payload.tenantId,
    id: id,
  );
  if (invoice == null || invoice.customerId == null || invoice.items.isEmpty) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  final tenant = await context.read<TenantRepository>().findById(payload.tenantId);
  final customer = await context.read<CustomerRepository>().findById(
    tenantId: payload.tenantId,
    id: invoice.customerId!,
  );
  if (tenant == null || customer == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  final approved = await context.read<WaasInvoiceDocumentRepository>().approve(
    tenantId: payload.tenantId,
    invoiceId: id,
    actorId: payload.userId,
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
