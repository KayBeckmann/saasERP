import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/order_repository.dart';
import 'package:backend/src/repositories/product_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/orders/<id>/billable-items — liefert alle Positionen des Auftrags
/// mit `already_invoiced`-Flag.
///
/// Query-Parameter `expand_products=1`: Positionen vom Typ `product` werden in
/// ihre Artikel-Komponenten aufgelöst (für den Materialabschlag-Dialog). Die
/// aufgelösten Positionen erhalten eine synthetische ID `cmp:<component_id>`
/// und das Flag `synthetic: true`. Nur Artikel-Komponenten werden aufgelöst;
/// Arbeitsstunden-Komponenten werden übersprungen. Direktpositionen vom Typ
/// `hours` und `text` werden in diesem Modus ebenfalls ausgeblendet.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final expandProducts =
      context.request.uri.queryParameters['expand_products'] == '1';

  final orderRepository = context.read<OrderRepository>();
  final invoiceRepository = context.read<InvoiceRepository>();

  final order =
      await orderRepository.findById(tenantId: auth.tenantId, id: id);
  if (order == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final invoicedIds = await invoiceRepository.invoicedOrderItemIds(
      tenantId: auth.tenantId, orderId: order.id);

  if (!expandProducts) {
    return Response.json(
      body: {
        'items': order.items
            .map(
              (item) => {
                ...item.toJson(),
                'already_invoiced':
                    item.id != null && invoicedIds.contains(item.id),
              },
            )
            .toList(),
      },
    );
  }

  // Expanded mode: resolve product items to article components.
  final productRepository = context.read<ProductRepository>();

  final productItems = order.items
      .where((i) =>
          i.kind == OrderItemKind.product && i.productId != null)
      .toList();
  final uniqueProductIds =
      productItems.map((i) => i.productId!).toSet().toList();

  final componentsByProduct = await productRepository
      .loadArticleComponentsForProductIds(uniqueProductIds);

  final billableItems = <Map<String, dynamic>>[];

  for (final item in order.items) {
    if (item.kind == OrderItemKind.product && item.productId != null) {
      final components = componentsByProduct[item.productId!] ?? [];
      for (final comp in components) {
        final compQty = (comp['quantity'] as num).toDouble();
        final description =
            (comp['label'] as String?)?.isNotEmpty == true
                ? comp['label'] as String
                : (comp['article_description'] as String?) ?? '';
        billableItems.add({
          'id': 'cmp:${comp['id']}',
          'kind': 'article',
          'description': description,
          'quantity': item.quantity * compQty,
          'unit': comp['article_unit'],
          'unit_price': (comp['unit_cost'] as num).toDouble(),
          'vat_rate': item.vatRate,
          'group_label': item.groupLabel,
          'already_invoiced': false,
          'synthetic': true,
          'parent_description': item.description,
        });
      }
    } else if (item.kind == OrderItemKind.article) {
      billableItems.add({
        ...item.toJson(),
        'already_invoiced': item.id != null && invoicedIds.contains(item.id),
        'synthetic': false,
      });
    }
    // hours and text are excluded in expand mode
  }

  return Response.json(body: {'items': billableItems});
}
