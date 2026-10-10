import 'package:backend/src/repositories/waas_billing_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Explicit owner-triggered draft generation; server clock, no client period.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final auth = authenticateRequest(context);
  if (auth == null)
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  if (auth.role != UserRole.owner.toJson())
    return Response.json(statusCode: 403, body: {'error': 'forbidden'});
  try {
    final created = await context.read<WaasBillingRepository>().run(
      tenantId: auth.tenantId,
      contractId: id,
      asOf: DateTime.now().toUtc(),
    );
    return Response.json(body: {'created_invoice_ids': created});
  } on StateError catch (_) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
}
