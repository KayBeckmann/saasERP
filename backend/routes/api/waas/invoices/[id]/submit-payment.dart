import 'package:backend/src/repositories/waas_payment_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Explicit submission, never marks an invoice paid.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final auth = await requirePermission(context, module: PermissionModule.waas, action: PermissionAction.send);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;
  try {
    final body = await context.request.json();
    if (body is! Map<String, dynamic> ||
        body['customer_id'] is! String ||
        body['mandate_id'] is! String ||
        body['amount_cents'] is! int)
      return Response.json(statusCode: 400, body: {'error': 'invalid_request'});
    final payment = await context.read<WaasPaymentRepository>().submit(
      tenantId: payload.tenantId,
      customerId: body['customer_id'] as String,
      invoiceId: id,
      mandateId: body['mandate_id'] as String,
      amountCents: body['amount_cents'] as int,
    );
    return Response.json(
      body: {'payment_id': payment.id, 'status': payment.status},
    );
  } on FormatException catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'invalid_request'});
  } on StateError catch (_) {
    return Response.json(
      statusCode: 409,
      body: {'error': 'payment_not_available'},
    );
  }
}
