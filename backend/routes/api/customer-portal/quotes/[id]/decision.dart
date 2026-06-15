import 'dart:async';
import 'dart:convert';

import 'package:backend/src/notification_service.dart';
import 'package:backend/src/repositories/customer_portal_account_repository.dart';
import 'package:backend/src/repositories/quote_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// PATCH /api/customer-portal/quotes/<id>/decision — Endkunde nimmt ein
/// versendetes Angebot an oder lehnt es ab (Zeitstempel, optionaler
/// Kommentar).
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null || auth.role != 'customer') {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
  }

  late final CustomerQuoteDecisionRequest req;
  try {
    req = CustomerQuoteDecisionRequest.fromJson(body);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  if (req.decision != QuoteStatus.accepted && req.decision != QuoteStatus.rejected) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'validation_failed', 'message': 'decision muss accepted oder rejected sein.'},
    );
  }

  final portalAccountRepository = context.read<CustomerPortalAccountRepository>();
  final account = await portalAccountRepository.findById(auth.userId);
  if (account == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final quoteRepository = context.read<QuoteRepository>();
  final quote = await quoteRepository.recordCustomerDecision(
    tenantId: auth.tenantId,
    id: id,
    customerId: account.customerId,
    decision: req.decision,
    comment: req.comment,
  );
  if (quote == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final notificationService = context.read<NotificationService>();
  unawaited(notificationService.notifyOwnerQuoteDecision(tenantId: auth.tenantId, quote: quote));

  return Response.json(body: quote.toJson());
}
