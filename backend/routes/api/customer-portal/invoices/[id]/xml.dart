import 'package:backend/src/repositories/customer_portal_account_repository.dart';
import 'package:backend/src/repositories/waas_invoice_document_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/customer-portal/invoices/<id>/xml — issued WaaS XML only.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get)
    return Response(statusCode: 405);
  final auth = authenticateRequest(context);
  if (auth == null || auth.role != 'customer') {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }
  final account = await context
      .read<CustomerPortalAccountRepository>()
      .findById(auth.userId);
  if (account == null || account.tenantId != auth.tenantId) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  final document = await context.read<WaasInvoiceDocumentRepository>().read(
    tenantId: auth.tenantId,
    invoiceId: id,
    customerId: account.customerId,
  );
  if (document == null)
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  return Response.bytes(
    body: document.xml,
    headers: {
      'Content-Type': 'application/xml; charset=UTF-8',
      'Content-Disposition':
          'attachment; filename="invoice-v${document.version}.xml"',
    },
  );
}
