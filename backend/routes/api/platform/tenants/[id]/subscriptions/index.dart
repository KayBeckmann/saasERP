import 'dart:convert';

import 'package:backend/src/repositories/subscription_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/platform/tenants/<id>/subscriptions — Abo-Historie eines
/// Mandanten (Plattform-Admin).
/// POST /api/platform/tenants/<id>/subscriptions — neues Abo für den
/// Mandanten anlegen.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null || !auth.isPlatformAdmin) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final subscriptionRepository = context.read<SubscriptionRepository>();

  if (context.request.method == HttpMethod.get) {
    final subscriptions = await subscriptionRepository.listForTenant(id);
    return Response.json(body: {'subscriptions': subscriptions.map((s) => s.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateSubscriptionRequest req;
    try {
      req = CreateSubscriptionRequest.fromJson(body);
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

    final subscription = await subscriptionRepository.create(tenantId: id, req: req);
    return Response.json(statusCode: 201, body: subscription.toJson());
  }

  return Response(statusCode: 405);
}
