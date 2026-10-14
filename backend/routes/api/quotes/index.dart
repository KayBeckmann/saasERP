import 'package:backend/src/subscription_validation.dart';
import 'dart:convert';

import 'package:backend/src/repositories/quote_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/quotes — Angebotsliste des aktuellen Mandanten.
/// POST /api/quotes — neues Angebot anlegen.
Future<Response> onRequest(RequestContext context) async {
  final action = context.request.method == HttpMethod.post
      ? PermissionAction.create
      : PermissionAction.view;
  final auth = await requirePermission(context, module: PermissionModule.quotes, action: action);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  final quoteRepository = context.read<QuoteRepository>();

  if (context.request.method == HttpMethod.get) {
    final quotes = await quoteRepository.list(payload.tenantId);
    return Response.json(
      body: {'quotes': quotes.map((q) => q.toJson()).toList()},
    );
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateQuoteRequest req;
    try {
      req = CreateQuoteRequest.fromJson(body);
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    try {
      validateSubscription(
        req.isSubscription,
        req.billingInterval,
        req.billingStartDate,
        req.customerId,
      );
    } on ArgumentError {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'validation_failed',
          'message': 'Abo benötigt Kunde, Intervall und Startdatum.',
        },
      );
    }

    if (req.title.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'validation_failed',
          'message': 'title darf nicht leer sein.',
        },
      );
    }

    final quote = await quoteRepository.create(
      tenantId: payload.tenantId,
      req: req,
    );
    return Response.json(statusCode: 201, body: quote.toJson());
  }

  return Response(statusCode: 405);
}
