import 'dart:convert';

import 'package:backend/src/repositories/supplier_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/suppliers/<id> — einzelnen Lieferanten lesen.
/// PATCH /api/suppliers/<id> — Lieferanten aktualisieren.
/// DELETE /api/suppliers/<id> — Lieferanten löschen.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final supplierRepository = context.read<SupplierRepository>();

  if (context.request.method == HttpMethod.get) {
    final supplier = await supplierRepository.findById(tenantId: auth.tenantId, id: id);
    if (supplier == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: supplier.toJson());
  }

  if (context.request.method == HttpMethod.patch) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final UpdateSupplierRequest req;
    try {
      req = UpdateSupplierRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.name.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'name darf nicht leer sein.'},
      );
    }

    final supplier = await supplierRepository.update(tenantId: auth.tenantId, id: id, req: req);
    if (supplier == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: supplier.toJson());
  }

  if (context.request.method == HttpMethod.delete) {
    final deleted = await supplierRepository.delete(tenantId: auth.tenantId, id: id);
    if (!deleted) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}
