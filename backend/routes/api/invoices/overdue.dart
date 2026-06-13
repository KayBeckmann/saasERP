import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/invoices/overdue — überfällige, nicht bezahlte Rechnungen des
/// aktuellen Mandanten. Grundlage für den Mahnlauf.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final invoices = await context.read<InvoiceRepository>().listOverdue(auth.tenantId);
  return Response.json(body: {'invoices': invoices.map((i) => i.toJson()).toList()});
}
