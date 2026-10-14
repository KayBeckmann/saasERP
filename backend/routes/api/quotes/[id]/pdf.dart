import 'package:backend/src/pdf/quote_pdf_builder.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/quote_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/quotes/<id>/pdf — Angebot als PDF.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final auth = await requirePermission(context, module: PermissionModule.quotes, action: PermissionAction.export);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  final quote = await context.read<QuoteRepository>().findById(tenantId: payload.tenantId, id: id);
  if (quote == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final tenant = await context.read<TenantRepository>().findById(payload.tenantId);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final customerId = quote.customerId;
  final customer = customerId == null
      ? null
      : await context.read<CustomerRepository>().findById(tenantId: payload.tenantId, id: customerId);

  final bytes = await buildQuotePdf(quote: quote, tenant: tenant, customer: customer);

  return Response.bytes(
    body: bytes,
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'inline; filename="${quote.quoteNumber}.pdf"',
    },
  );
}
