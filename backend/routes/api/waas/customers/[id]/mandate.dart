import 'package:backend/src/repositories/waas_payment_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Owner-only hosted handoff. Never collects bank data.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final auth = await requirePermission(context, module: PermissionModule.waas, action: PermissionAction.edit);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;
  try {
    final flow = await context.read<WaasPaymentRepository>().startMandate(
      tenantId: payload.tenantId,
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
