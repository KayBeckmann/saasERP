import 'dart:convert';

import 'package:backend/src/repositories/purchase_order_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/purchase-orders/<id> — einzelne Bestellung lesen.
/// PATCH /api/purchase-orders/<id> — Bestellung aktualisieren. Setzt die
/// Anfrage einen Status != `open`, ist das fachlich eine Freigabe/Versand
/// (oder eine Änderung an einer bereits freigegebenen Bestellung) und
/// braucht deshalb `PermissionAction.release` statt des für reine
/// Entwurfsbearbeitung ausreichenden `edit` (Roadmap: "Entwurf anlegen/
/// ändern und Freigabe/Versand getrennt").
/// DELETE /api/purchase-orders/<id> — Bestellung löschen.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get &&
      context.request.method != HttpMethod.patch &&
      context.request.method != HttpMethod.delete) {
    return Response(statusCode: 405);
  }

  UpdatePurchaseOrderRequest? patchReq;
  if (context.request.method == HttpMethod.patch) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }
    try {
      patchReq = UpdatePurchaseOrderRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }
  }

  final action = switch (context.request.method) {
    HttpMethod.delete => PermissionAction.delete,
    HttpMethod.patch when patchReq!.status != PurchaseOrderStatus.open => PermissionAction.release,
    HttpMethod.patch => PermissionAction.edit,
    _ => PermissionAction.view,
  };
  final auth = await requirePermission(context, module: PermissionModule.purchaseOrders, action: action);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  final purchaseOrderRepository = context.read<PurchaseOrderRepository>();

  if (context.request.method == HttpMethod.get) {
    final purchaseOrder = await purchaseOrderRepository.findById(tenantId: payload.tenantId, id: id);
    if (purchaseOrder == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: purchaseOrder.toJson());
  }

  if (context.request.method == HttpMethod.patch) {
    final req = patchReq!;
    if (req.items.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'Bestellung benötigt mindestens eine Position.'},
      );
    }

    final purchaseOrder = await purchaseOrderRepository.update(tenantId: payload.tenantId, id: id, req: req);
    if (purchaseOrder == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: purchaseOrder.toJson());
  }

  if (context.request.method == HttpMethod.delete) {
    final deleted = await purchaseOrderRepository.delete(tenantId: payload.tenantId, id: id);
    if (!deleted) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}
