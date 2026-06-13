import 'dart:convert';

import 'package:backend/src/repositories/purchase_order_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/purchase-orders/<id> — einzelne Bestellung lesen.
/// PATCH /api/purchase-orders/<id> — Bestellung aktualisieren.
/// DELETE /api/purchase-orders/<id> — Bestellung löschen.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final purchaseOrderRepository = context.read<PurchaseOrderRepository>();

  if (context.request.method == HttpMethod.get) {
    final purchaseOrder = await purchaseOrderRepository.findById(tenantId: auth.tenantId, id: id);
    if (purchaseOrder == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: purchaseOrder.toJson());
  }

  if (context.request.method == HttpMethod.patch) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final UpdatePurchaseOrderRequest req;
    try {
      req = UpdatePurchaseOrderRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.items.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'Bestellung benötigt mindestens eine Position.'},
      );
    }

    final purchaseOrder = await purchaseOrderRepository.update(tenantId: auth.tenantId, id: id, req: req);
    if (purchaseOrder == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: purchaseOrder.toJson());
  }

  if (context.request.method == HttpMethod.delete) {
    final deleted = await purchaseOrderRepository.delete(tenantId: auth.tenantId, id: id);
    if (!deleted) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}
