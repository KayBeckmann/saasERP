import 'dart:convert';

import 'package:backend/src/repositories/subscription_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/subscription/cancel — Self-Service-Kündigung des eigenen Abos
/// zum übergebenen Stichtag `cancelled_at` (M3). Liefert ein
/// Beleg/Übersicht-Objekt mit Restlaufzeit und Vertragsstrafe. Nur für den
/// Owner.
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

  DateTime cancelledAt;
  try {
    cancelledAt = DateTime.parse(body['cancelled_at'] as String);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  final subscriptionRepository = context.read<SubscriptionRepository>();
  final current = await subscriptionRepository.findActiveForTenant(auth.tenantId);
  if (current == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final subscription = await subscriptionRepository.cancel(
    tenantId: auth.tenantId,
    id: current.id,
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
