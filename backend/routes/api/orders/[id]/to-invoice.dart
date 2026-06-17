import 'dart:convert';

import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/order_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/orders/<id>/to-invoice — erzeugt aus einem Auftrag eine neue
/// Rechnung (Kunde, Titel, Notizen werden übernommen). Optionaler JSON-Body:
/// `invoice_type` (standard/partial/down_payment/final, Default `standard`)
/// und `item_ids` (Liste von `order_items.id`, Default: alle Positionen).
/// Bereits abgerechnete Positionen (siehe `billable-items`) werden immer
/// ausgeschlossen (Doppelabrechnungsschutz). Bei `invoice_type: final` wird
/// `prior_invoiced_total` aus der Summe aller vorherigen, nicht-stornierten
/// Rechnungen dieses Auftrags berechnet.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  var invoiceType = InvoiceType.standard;
  List<String>? itemIds;

  final rawBody = await context.request.body();
  if (rawBody.trim().isNotEmpty) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(rawBody) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }
    if (body['invoice_type'] != null) {
      invoiceType = InvoiceType.fromJson(body['invoice_type'] as String);
    }
    if (body['item_ids'] != null) {
      itemIds = (body['item_ids'] as List).map((e) => e as String).toList();
    }
  }

  final orderRepository = context.read<OrderRepository>();
  final invoiceRepository = context.read<InvoiceRepository>();

  final order = await orderRepository.findById(tenantId: auth.tenantId, id: id);
  if (order == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final invoicedIds = await invoiceRepository.invoicedOrderItemIds(tenantId: auth.tenantId, orderId: order.id);

  // Closing invoices include ALL positions (already-invoiced ones appear as full sum;
  // prior invoices are deducted separately). All other types exclude already-invoiced items.
  var items = invoiceType == InvoiceType.closingInvoice
      ? order.items.toList()
      : order.items.where((item) => item.id == null || !invoicedIds.contains(item.id)).toList();
  if (itemIds != null) {
    final selected = itemIds.toSet();
    items = items.where((item) => item.id != null && selected.contains(item.id)).toList();
  }

  if (items.isEmpty) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'no_billable_items', 'message': 'Keine abrechenbaren Positionen vorhanden.'},
    );
  }

  double? priorInvoicedTotal;
  List<PriorInvoiceRef> priorInvoices = [];
  if (invoiceType == InvoiceType.closingInvoice) {
    priorInvoices = await invoiceRepository.listPriorForOrder(
      tenantId: auth.tenantId,
      orderId: order.id,
    );
    priorInvoicedTotal = priorInvoices.fold<double>(0.0, (sum, r) => sum + r.totalGross);
    if (priorInvoicedTotal == 0) priorInvoicedTotal = null;
  }

  final req = CreateInvoiceRequest(
    customerId: order.customerId,
    title: order.title,
    notes: order.notes,
    invoiceType: invoiceType,
    priorInvoicedTotal: priorInvoicedTotal,
    items: items
        .map(
          (item) => InvoiceItem(
            kind: InvoiceItemKind.fromJson(item.kind.toJson()),
            articleId: item.articleId,
            productId: item.productId,
            description: item.description,
            quantity: item.quantity,
            unit: item.unit,
            unitPrice: item.unitPrice,
            vatRate: item.vatRate,
            groupLabel: item.groupLabel,
            orderItemId: item.id,
          ),
        )
        .toList(),
  );

  final invoice = await invoiceRepository.create(tenantId: auth.tenantId, req: req, orderId: order.id);
  final responseJson = invoice.toJson();
  if (priorInvoices.isNotEmpty) {
    responseJson['prior_invoices'] = priorInvoices.map((r) => r.toJson()).toList();
  }
  return Response.json(statusCode: 201, body: responseJson);
}
