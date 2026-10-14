import 'dart:convert';

import 'package:backend/src/repositories/purchase_order_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/purchase-orders — Bestellliste des aktuellen Mandanten.
/// POST /api/purchase-orders — neue Bestellung anlegen (manuell oder aus
/// einem Bestellvorschlag, siehe `GET /api/orders/<id>/purchase-proposal`).
Future<Response> onRequest(RequestContext context) async {
  final action = switch (context.request.method) {
    HttpMethod.post => PermissionAction.create,
    _ => PermissionAction.view,
  };
  final auth = await requirePermission(context, module: PermissionModule.purchaseOrders, action: action);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  final purchaseOrderRepository = context.read<PurchaseOrderRepository>();

  if (context.request.method == HttpMethod.get) {
    final purchaseOrders = await purchaseOrderRepository.list(payload.tenantId);
    return Response.json(body: {'purchase_orders': purchaseOrders.map((o) => o.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreatePurchaseOrderRequest req;
    try {
      req = CreatePurchaseOrderRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.items.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'Bestellung benötigt mindestens eine Position.'},
      );
    }

    final purchaseOrder = await purchaseOrderRepository.create(tenantId: payload.tenantId, req: req);
    return Response.json(statusCode: 201, body: purchaseOrder.toJson());
  }

  return Response(statusCode: 405);
}
