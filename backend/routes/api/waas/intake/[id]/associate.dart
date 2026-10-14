import 'dart:convert';
import 'package:backend/src/repositories/waas_intake_repository.dart';
import 'package:backend/src/waas_intake_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Explicit out-of-band verification by an admin. Mail sender is not identity.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final gate = await intakeOwnerGate(context, action: PermissionAction.edit);
  if (gate.denied != null) return gate.denied!;
  if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  try {
    final body =
        jsonDecode(await context.request.body()) as Map<String, dynamic>;
    await context.read<WaasIntakeRepository>().associate(
      tenantId: gate.payload!.tenantId,
      id: id,
      customerId: body['customer_id'] as String,
      actorId: gate.payload!.userId,
      verificationNote: body['verification_note'] as String,
    );
    return Response.json(body: {'status': 'associated'});
  } on StateError catch (_) {
    return Response.json(
      statusCode: 404,
      body: {'error': 'not_found_or_not_pending'},
    );
  } on Exception catch (_) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'invalid_association'},
    );
  }
}
