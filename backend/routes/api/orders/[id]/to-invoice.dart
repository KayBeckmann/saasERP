import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/order_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/orders/<id>/to-invoice — erzeugt aus einem Auftrag eine neue
/// Rechnung (Kunde, Titel, Notizen und Positionen inkl. Gruppen-Label werden
/// übernommen, `order_id` verweist auf den Ursprungsauftrag).
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final orderRepository = context.read<OrderRepository>();
  final invoiceRepository = context.read<InvoiceRepository>();

  final order = await orderRepository.findById(tenantId: auth.tenantId, id: id);
  if (order == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final req = CreateInvoiceRequest(
    customerId: order.customerId,
    title: order.title,
    notes: order.notes,
    items: order.items
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
          ),
        )
        .toList(),
  );

  final invoice = await invoiceRepository.create(tenantId: auth.tenantId, req: req, orderId: order.id);
  return Response.json(statusCode: 201, body: invoice.toJson());
}
