import 'dart:convert';

import 'package:backend/src/repositories/subscription_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/subscription/change-tier — Self-Service-Tier-Wechsel
/// (Up-/Downgrade, M3): beendet das aktuelle Abo ohne Vertragsstrafe und legt
/// mit denselben Vertragskonditionen ein neues aktives Abo mit dem
/// gewünschten Tier und frischer Laufzeit ab heute an. Nur für den Owner.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }
  if (auth.role != UserRole.owner.toJson()) {
    return Response.json(statusCode: 403, body: {'error': 'forbidden'});
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
  }

  final tierId = body['tier_id'] as String?;
  if (tierId == null || tierId.isEmpty) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'validation_failed', 'message': 'tier_id darf nicht leer sein.'},
    );
  }

  final subscriptionRepository = context.read<SubscriptionRepository>();
  final subscription = await subscriptionRepository.changeTier(
    tenantId: auth.tenantId,
    newTierId: tierId,
  );
  if (subscription == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  return Response.json(body: subscription.toJson());
}
