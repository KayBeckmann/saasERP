import 'dart:convert';

import 'package:backend/src/repositories/subscription_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/platform/tenants/<id>/subscriptions/<subscriptionId>/cancel —
/// kündigt ein aktives Abo zum übergebenen Stichtag `cancelled_at` und
/// liefert ein Beleg/Übersicht-Objekt mit Restlaufzeit und Vertragsstrafe.
Future<Response> onRequest(RequestContext context, String id, String subscriptionId) async {
  final auth = authenticateRequest(context);
  if (auth == null || !auth.isPlatformAdmin) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
  }

  DateTime cancelledAt;
  try {
    cancelledAt = DateTime.parse(body['cancelled_at'] as String);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  final subscriptionRepository = context.read<SubscriptionRepository>();
  final subscription = await subscriptionRepository.cancel(
    tenantId: id,
    id: subscriptionId,
    cancelledAt: cancelledAt,
  );
  if (subscription == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final statement = SubscriptionCancellationStatement(
    subscription: subscription,
    remainingMonths: subscription.remainingMonths(cancelledAt),
    penalty: subscription.penaltyAt(cancelledAt),
  );
  return Response.json(body: statement.toJson());
}
