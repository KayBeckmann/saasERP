import 'dart:convert';

import 'package:backend/src/repositories/subscription_tier_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// PATCH /api/platform/subscription-tiers/<id> — Abo-Tier aktualisieren.
/// DELETE /api/platform/subscription-tiers/<id> — Abo-Tier löschen.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null || !auth.isPlatformAdmin) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final subscriptionTierRepository = context.read<SubscriptionTierRepository>();

  if (context.request.method == HttpMethod.patch) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final UpdateSubscriptionTierRequest req;
    try {
      req = UpdateSubscriptionTierRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.name.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'name darf nicht leer sein.'},
      );
    }

    final tier = await subscriptionTierRepository.update(id: id, req: req);
    if (tier == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: tier.toJson());
  }

  if (context.request.method == HttpMethod.delete) {
    final deleted = await subscriptionTierRepository.delete(id);
    if (!deleted) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}
