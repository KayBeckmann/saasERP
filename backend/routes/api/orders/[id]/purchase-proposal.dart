import 'dart:convert';

import 'package:backend/src/purchase_proposal_service.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET  /api/orders/<id>/purchase-proposal — Bestellvorschlag für den
/// Auftrag (Vorschau, erzeugt noch nichts): Mengen aller Artikel-Positionen
/// sowie der in verwendeten Produkten enthaltenen Artikel werden je Artikel
/// aufsummiert. Die vorgeschlagene Bestellmenge ist die Fehlmenge (Bedarf
/// minus Lagerbestand minus bereits für diesen Auftrag bestellter Menge —
/// Idempotenz, siehe PurchaseProposalService). Artikel mit Fehlmenge <= 0
/// erscheinen nicht im Vorschlag. Gruppiert nach `default_supplier_id`
/// (Artikel ohne Standard-Lieferant landen in einer Gruppe mit
/// `supplier_id: null`).
///
/// POST /api/orders/<id>/purchase-proposal — erzeugt aus dem aktuellen
/// Vorschlag echte, pro Lieferant getrennte Bestellentwürfe (Status
/// `open`) in einem Zug. Optionaler Body `{"supplier_ids": [...]}`
/// schränkt auf bestimmte Lieferantengruppen ein (fehlende/`null`-Einträge
/// adressieren die Gruppe ohne Standard-Lieferant); ohne Body werden alle
/// Gruppen mit offener Bestellmenge angelegt.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get && context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }
  final action = context.request.method == HttpMethod.post
      ? PermissionAction.create
      : PermissionAction.view;
  final auth = await requirePermission(context, module: PermissionModule.purchaseOrders, action: action);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  final proposalService = context.read<PurchaseProposalService>();

  if (context.request.method == HttpMethod.get) {
    final proposals = await proposalService.buildProposal(tenantId: payload.tenantId, orderId: id);
    if (proposals == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: {'proposals': proposals.map((group) => group.toJson()).toList()});
  }

  // POST: Entwürfe anlegen.
  Set<String?>? supplierIds;
  final bodyText = await context.request.body();
  if (bodyText.isNotEmpty) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(bodyText) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }
    final rawIds = body['supplier_ids'] as List?;
    if (rawIds != null) {
      supplierIds = rawIds.map((e) => e as String?).toSet();
    }
  }

  final createdOrders = await proposalService.createDraftsFromProposal(
    tenantId: payload.tenantId,
    orderId: id,
    supplierIds: supplierIds,
  );
  if (createdOrders == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  return Response.json(
    statusCode: 201,
    body: {'purchase_orders': createdOrders.map((po) => po.toJson()).toList()},
  );
}
