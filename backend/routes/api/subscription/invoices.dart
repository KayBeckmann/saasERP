import 'package:backend/src/repositories/platform_invoice_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/subscription/invoices — Selbstauskunft: eigene
/// Plattform-Rechnungen des Mandanten (M4). Nur für den Owner.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final auth = await requirePermission(context, module: PermissionModule.tenantConfig, action: PermissionAction.view);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  final platformInvoiceRepository = context.read<PlatformInvoiceRepository>();
  final invoices = await platformInvoiceRepository.listForTenant(payload.tenantId);
  return Response.json(body: {'invoices': invoices.map((i) => i.toJson()).toList()});
}
