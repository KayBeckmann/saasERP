import 'package:backend/src/repositories/order_repository.dart';
import 'package:backend/src/repositories/quote_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/quotes/<id>/to-order — erzeugt aus einem Angebot einen neuen
/// Auftrag (Kunde, Titel, Notizen und Positionen inkl. Gruppen-Label werden
/// übernommen, `quote_id` verweist auf das Ursprungsangebot).
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final auth = await requirePermission(context, module: PermissionModule.orders, action: PermissionAction.create);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  final quoteRepository = context.read<QuoteRepository>();
  final orderRepository = context.read<OrderRepository>();

  final quote = await quoteRepository.findById(tenantId: payload.tenantId, id: id);
  if (quote == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final req = CreateOrderRequest(
    customerId: quote.customerId,
    isSubscription: quote.isSubscription,
    billingInterval: quote.billingInterval,
    billingStartDate: quote.billingStartDate,
    title: quote.title,
    notes: quote.notes,
    items: quote.items
        .map(
          (item) => OrderItem(
            kind: OrderItemKind.fromJson(item.kind.toJson()),
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

  final order = await orderRepository.create(
    tenantId: payload.tenantId,
    req: req,
    quoteId: quote.id,
  );
  return Response.json(statusCode: 201, body: order.toJson());
}
