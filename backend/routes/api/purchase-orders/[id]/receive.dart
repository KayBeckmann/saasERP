import 'dart:convert';

import 'package:backend/src/repositories/purchase_order_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/purchase-orders/<id>/receive — erfasst einen Wareneingang:
/// addiert je Position die gelieferte Menge zu `quantity_delivered` und
/// aktualisiert den Bestellstatus (`ordered` -> `partially_delivered` ->
/// `fully_delivered`).
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = await requirePermission(context, module: PermissionModule.purchaseOrders, action: PermissionAction.edit);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
  }

  late final ReceivePurchaseOrderRequest req;
  try {
    req = ReceivePurchaseOrderRequest.fromJson(body);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  if (req.items.isEmpty) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'validation_failed', 'message': 'Wareneingang benötigt mindestens eine Position.'},
    );
  }

  final purchaseOrderRepository = context.read<PurchaseOrderRepository>();
  final purchaseOrder = await purchaseOrderRepository.receive(tenantId: payload.tenantId, id: id, req: req);
  if (purchaseOrder == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  return Response.json(body: purchaseOrder.toJson());
}
