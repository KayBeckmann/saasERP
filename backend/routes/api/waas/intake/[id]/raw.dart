import 'package:backend/src/repositories/waas_intake_repository.dart';
import 'package:backend/src/waas_intake_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get)
    return Response(statusCode: 405);
  final gate = await intakeOwnerGate(context, action: PermissionAction.view);
  if (gate.denied != null) return gate.denied!;
  if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  final bytes = await context.read<WaasIntakeRepository>().raw(
    tenantId: gate.payload!.tenantId,
    id: id,
  );
  if (bytes == null)
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  return Response.bytes(
    body: bytes,
    headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Disposition': 'attachment; filename="untrusted-message.eml"',
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'no-store',
      'Content-Security-Policy': "default-src 'none'; sandbox",
    },
  );
}
