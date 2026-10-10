import 'dart:convert';
import 'package:backend/src/repositories/waas_intake_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:backend/src/waas_intake_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// Explicit out-of-band verification by owner. Mail sender is not identity.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final denied = intakeOwnerGate(context);
  if (denied != null) return denied;
  if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  try {
    final body =
        jsonDecode(await context.request.body()) as Map<String, dynamic>;
    await context.read<WaasIntakeRepository>().associate(
      tenantId: authenticateRequest(context)!.tenantId,
      id: id,
      customerId: body['customer_id'] as String,
      actorId: authenticateRequest(context)!.userId,
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
