import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/order_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/orders/<id>/billable-items — liefert alle Positionen des
/// Auftrags mit einem `already_invoiced`-Flag. Positionen, deren
/// `order_item_id` bereits über eine nicht-stornierte Rechnung dieses
/// Auftrags abgerechnet wurde, sind `already_invoiced: true` (Basis für
/// die Positions-Checkliste bei Teil-/Abschlags-/Schlussrechnungen).
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final orderRepository = context.read<OrderRepository>();
  final invoiceRepository = context.read<InvoiceRepository>();

  final order = await orderRepository.findById(tenantId: auth.tenantId, id: id);
  if (order == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final invoicedIds = await invoiceRepository.invoicedOrderItemIds(tenantId: auth.tenantId, orderId: order.id);

  return Response.json(
    body: {
      'items': order.items
          .map(
            (item) => {
              ...item.toJson(),
              'already_invoiced': item.id != null && invoicedIds.contains(item.id),
            },
          )
          .toList(),
    },
  );
}
