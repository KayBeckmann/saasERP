import 'dart:convert';

import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/customers — Kundenliste des aktuellen Mandanten.
/// POST /api/customers — neuen Kunden anlegen (Kundennummer wird vergeben).
Future<Response> onRequest(RequestContext context) async {
  final action = context.request.method == HttpMethod.post
      ? PermissionAction.create
      : PermissionAction.view;
  final auth = await requirePermission(context, module: PermissionModule.customers, action: action);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  final customerRepository = context.read<CustomerRepository>();

  if (context.request.method == HttpMethod.get) {
    final customers = await customerRepository.list(payload.tenantId);
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

    final customer = await customerRepository.create(tenantId: payload.tenantId, req: req);
    return Response.json(statusCode: 201, body: customer.toJson());
  }

  return Response(statusCode: 405);
}
