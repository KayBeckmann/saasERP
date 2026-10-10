import 'package:backend/src/repositories/waas_payment_repository.dart';
import 'package:dart_frog/dart_frog.dart';

/// Provider callback: no tenant JWT. Authentication is the raw-body signature
/// verified with the credential alias bound to this merchant id in the DB.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final signature = context.request.headers['x-waas-signature'];
  if (signature == null || signature.isEmpty)
    return Response.json(statusCode: 401, body: {'error': 'invalid_signature'});
  final bytes = <int>[];
  await for (final chunk in context.request.bytes()) {
    bytes.addAll(chunk);
    if (bytes.length > 16384) return Response(statusCode: 413);
  }
  try {
    final outcome = await context.read<WaasPaymentRepository>().processWebhook(
      merchantId: id,
      rawBody: bytes,
      signature: signature,
    );
    return Response.json(body: {'outcome': outcome});
  } on FormatException catch (_) {
    return Response.json(statusCode: 401, body: {'error': 'invalid_signature'});
  } on StateError catch (_) {
    return Response.json(statusCode: 409, body: {'error': 'event_rejected'});
  }
}
