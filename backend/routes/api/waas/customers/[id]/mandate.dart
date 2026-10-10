import 'package:backend/src/repositories/waas_payment_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Owner-only hosted handoff. Never collects bank data.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final auth = authenticateRequest(context);
  if (auth == null)
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  if (auth.role != UserRole.owner.toJson())
    return Response.json(statusCode: 403, body: {'error': 'forbidden'});
  try {
    final flow = await context.read<WaasPaymentRepository>().startMandate(
      tenantId: auth.tenantId,
      customerId: id,
    );
    return Response.json(
      body: {
        'mandate_id': flow.id,
        'hosted_url': flow.url.toString(),
        'status': flow.status,
      },
    );
  } on StateError catch (_) {
    return Response.json(statusCode: 404, body: {'error': 'not_available'});
  }
}
