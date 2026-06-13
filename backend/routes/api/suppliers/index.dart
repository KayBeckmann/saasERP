import 'dart:convert';

import 'package:backend/src/repositories/supplier_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/suppliers — Lieferantenliste des aktuellen Mandanten.
/// POST /api/suppliers — neuen Lieferanten anlegen.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final supplierRepository = context.read<SupplierRepository>();

  if (context.request.method == HttpMethod.get) {
    final suppliers = await supplierRepository.list(auth.tenantId);
    return Response.json(body: {'suppliers': suppliers.map((s) => s.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateSupplierRequest req;
    try {
      req = CreateSupplierRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.name.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'name darf nicht leer sein.'},
      );
    }

    final supplier = await supplierRepository.create(tenantId: auth.tenantId, req: req);
    return Response.json(statusCode: 201, body: supplier.toJson());
  }

  return Response(statusCode: 405);
}
