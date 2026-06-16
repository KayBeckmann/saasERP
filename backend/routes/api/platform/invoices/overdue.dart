import 'package:backend/src/repositories/platform_invoice_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/platform/invoices/overdue — überfällige Plattform-Rechnungen über
/// alle Mandanten (M4 — Mahnwesen-Basis für den Plattform-Admin).
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null || !auth.isPlatformAdmin) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final platformInvoiceRepository = context.read<PlatformInvoiceRepository>();
  final invoices = await platformInvoiceRepository.listOverdueAll();
  return Response.json(body: {'invoices': invoices.map((i) => i.toJson()).toList()});
}
