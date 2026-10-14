import 'package:backend/src/repositories/waas_billing_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Explicit owner-triggered draft generation; server clock, no client period.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final auth = await requirePermission(context, module: PermissionModule.waas, action: PermissionAction.edit);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;
  try {
    final created = await context.read<WaasBillingRepository>().run(
      tenantId: payload.tenantId,
      contractId: id,
      asOf: DateTime.now().toUtc(),
    );
    return Response.json(body: {'created_invoice_ids': created});
  } on StateError catch (_) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
}
