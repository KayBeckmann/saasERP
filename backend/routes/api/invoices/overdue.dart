import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/invoices/overdue — überfällige, nicht bezahlte Rechnungen des
/// aktuellen Mandanten. Grundlage für den Mahnlauf.
Future<Response> onRequest(RequestContext context) async {
  final auth = await requirePermission(context, module: PermissionModule.invoices, action: PermissionAction.view);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final invoices = await context.read<InvoiceRepository>().listOverdue(payload.tenantId);
  return Response.json(body: {'invoices': invoices.map((i) => i.toJson()).toList()});
}
