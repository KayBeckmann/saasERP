import 'dart:convert';

import 'package:backend/src/repositories/subscription_tier_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/platform/subscription-tiers — alle Abo-Tiers (Plattform-Admin).
/// POST /api/platform/subscription-tiers — neues Abo-Tier anlegen.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null || !auth.isPlatformAdmin) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final subscriptionTierRepository = context.read<SubscriptionTierRepository>();

  if (context.request.method == HttpMethod.get) {
    final tiers = await subscriptionTierRepository.list();
    return Response.json(body: {'subscription_tiers': tiers.map((t) => t.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateSubscriptionTierRequest req;
    try {
      req = CreateSubscriptionTierRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.name.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'name darf nicht leer sein.'},
      );
    }

    final tier = await subscriptionTierRepository.create(req);
    return Response.json(statusCode: 201, body: tier.toJson());
  }

  return Response(statusCode: 405);
}
