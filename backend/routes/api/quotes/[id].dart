import 'dart:convert';

import 'package:backend/src/repositories/quote_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/quotes/<id> — einzelnes Angebot lesen.
/// PATCH /api/quotes/<id> — Angebot aktualisieren.
/// DELETE /api/quotes/<id> — Angebot löschen.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final quoteRepository = context.read<QuoteRepository>();

  if (context.request.method == HttpMethod.get) {
    final quote = await quoteRepository.findById(tenantId: auth.tenantId, id: id);
    if (quote == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: quote.toJson());
  }

  if (context.request.method == HttpMethod.patch) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final UpdateQuoteRequest req;
    try {
      req = UpdateQuoteRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.title.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'title darf nicht leer sein.'},
      );
    }

    final quote = await quoteRepository.update(tenantId: auth.tenantId, id: id, req: req);
    if (quote == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: quote.toJson());
  }

  if (context.request.method == HttpMethod.delete) {
    final deleted = await quoteRepository.delete(tenantId: auth.tenantId, id: id);
    if (!deleted) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}
