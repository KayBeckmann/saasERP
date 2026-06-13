import 'dart:convert';

import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/customers — Kundenliste des aktuellen Mandanten.
/// POST /api/customers — neuen Kunden anlegen (Kundennummer wird vergeben).
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final customerRepository = context.read<CustomerRepository>();

  if (context.request.method == HttpMethod.get) {
    final customers = await customerRepository.list(auth.tenantId);
    return Response.json(body: {'customers': customers.map((c) => c.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateCustomerRequest req;
    try {
      req = CreateCustomerRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.name.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'name darf nicht leer sein.'},
      );
    }

    final customer = await customerRepository.create(tenantId: auth.tenantId, req: req);
    return Response.json(statusCode: 201, body: customer.toJson());
  }

  return Response(statusCode: 405);
}
