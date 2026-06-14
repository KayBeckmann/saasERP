import 'dart:convert';

import 'package:backend/src/repositories/customer_portal_account_repository.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/customers/<id>/portal-access — Status des Kundenzugangs lesen.
/// POST /api/customers/<id>/portal-access — Kundenzugang anlegen (Einladung).
/// DELETE /api/customers/<id>/portal-access — Kundenzugang widerrufen.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final customerRepository = context.read<CustomerRepository>();
  final portalAccountRepository = context.read<CustomerPortalAccountRepository>();

  final customer = await customerRepository.findById(tenantId: auth.tenantId, id: id);
  if (customer == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  if (context.request.method == HttpMethod.get) {
    final account = await portalAccountRepository.findByCustomerId(
      tenantId: auth.tenantId,
      customerId: id,
    );
    if (account == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: account.toJson());
  }

  if (context.request.method == HttpMethod.post) {
    final existing = await portalAccountRepository.findByCustomerId(
      tenantId: auth.tenantId,
      customerId: id,
    );
    if (existing != null) {
      return Response.json(statusCode: 409, body: {'error': 'portal_access_exists'});
    }

    var email = customer.email;
    final rawBody = await context.request.body();
    if (rawBody.trim().isNotEmpty) {
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(rawBody) as Map<String, dynamic>;
      } on FormatException {
        return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
      }
      late final CreateCustomerPortalAccountRequest req;
      try {
        req = CreateCustomerPortalAccountRequest.fromJson(body);
      } on TypeError {
        return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
      }
      if (req.email != null && req.email!.trim().isNotEmpty) {
        email = req.email!.trim();
      }
    }

    if (email == null || email.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'validation_failed',
          'message': 'E-Mail-Adresse fehlt — Kunde hat keine E-Mail hinterlegt und keine wurde übergeben.',
        },
      );
    }

    final account = await portalAccountRepository.create(
      tenantId: auth.tenantId,
      customerId: id,
      email: email,
    );
    return Response.json(statusCode: 201, body: account.toJson());
  }

  if (context.request.method == HttpMethod.delete) {
    final deleted = await portalAccountRepository.delete(tenantId: auth.tenantId, customerId: id);
    if (!deleted) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}
