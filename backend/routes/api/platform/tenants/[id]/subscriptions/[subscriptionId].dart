import 'dart:convert';

import 'package:backend/src/repositories/subscription_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// PATCH /api/platform/tenants/<id>/subscriptions/<subscriptionId> — Abo
/// aktualisieren (Tier-Wechsel, Kündigung, Korrektur).
Future<Response> onRequest(RequestContext context, String id, String subscriptionId) async {
  final auth = authenticateRequest(context);
  if (auth == null || !auth.isPlatformAdmin) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: 405);
  }

  final subscriptionRepository = context.read<SubscriptionRepository>();

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
  }

  late final UpdateSubscriptionRequest req;
  try {
    req = UpdateSubscriptionRequest.fromJson(body);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  if (req.termMonths <= 0) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'validation_failed', 'message': 'term_months muss größer als 0 sein.'},
    );
  }
  if (!req.endDate.isAfter(req.startDate)) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'validation_failed', 'message': 'end_date muss nach start_date liegen.'},
    );
  }

  final subscription = await subscriptionRepository.update(tenantId: id, id: subscriptionId, req: req);
  if (subscription == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  return Response.json(body: subscription.toJson());
}
