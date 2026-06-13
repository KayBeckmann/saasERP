import 'package:backend/src/repositories/article_repository.dart';
import 'package:backend/src/repositories/order_repository.dart';
import 'package:backend/src/repositories/product_repository.dart';
import 'package:backend/src/repositories/supplier_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/orders/<id>/purchase-proposal — Bestellvorschlag für den
/// Auftrag: Mengen aller Artikel-Positionen sowie der in verwendeten
/// Produkten enthaltenen Artikel werden je Artikel aufsummiert. Die
/// vorgeschlagene Bestellmenge ist die Fehlmenge (Bedarf minus aktuellem
/// Lagerbestand, siehe Roadmap-Entscheidung 2026-06-12). Artikel mit
/// Fehlmenge <= 0 erscheinen nicht im Vorschlag. Die Ergebnisse werden nach
/// `default_supplier_id` gruppiert (Artikel ohne Standard-Lieferant landen
/// in einer Gruppe mit `supplier_id: null`).
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final orderRepository = context.read<OrderRepository>();
  final order = await orderRepository.findById(tenantId: auth.tenantId, id: id);
  if (order == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final productRepository = context.read<ProductRepository>();
  final articleRepository = context.read<ArticleRepository>();
  final supplierRepository = context.read<SupplierRepository>();

  final requiredQuantities = <String, double>{};
  for (final item in order.items) {
    if (item.kind == OrderItemKind.article && item.articleId != null) {
      requiredQuantities[item.articleId!] = (requiredQuantities[item.articleId!] ?? 0) + item.quantity;
      continue;
    }
    if (item.kind == OrderItemKind.product && item.productId != null) {
      final product = await productRepository.findById(tenantId: auth.tenantId, id: item.productId!);
      if (product == null) continue;
      for (final component in product.components) {
        if (component.kind == ProductComponentKind.article && component.articleId != null) {
          requiredQuantities[component.articleId!] =
              (requiredQuantities[component.articleId!] ?? 0) + component.quantity * item.quantity;
        }
      }
    }
  }

  if (requiredQuantities.isEmpty) {
    return Response.json(body: {'proposals': <Map<String, dynamic>>[]});
  }

  final articles = await articleRepository.findByIds(tenantId: auth.tenantId, ids: requiredQuantities.keys.toSet());
  final articlesById = {for (final article in articles) article.id: article};

  final suppliers = await supplierRepository.list(auth.tenantId);
  final supplierNames = {for (final supplier in suppliers) supplier.id: supplier.name};

  final itemsBySupplier = <String?, List<PurchaseProposalItem>>{};
  for (final entry in requiredQuantities.entries) {
    final article = articlesById[entry.key];
    if (article == null) continue;

    final orderQuantity = entry.value - article.stockQuantity;
    if (orderQuantity <= 0) continue;

    itemsBySupplier.putIfAbsent(article.defaultSupplierId, () => []).add(
          PurchaseProposalItem(
            articleId: article.id,
            description: article.name,
            unit: article.unit,
            requiredQuantity: entry.value,
            stockQuantity: article.stockQuantity,
            orderQuantity: orderQuantity,
            unitPrice: article.purchasePrice,
          ),
        );
  }

  final proposals = itemsBySupplier.entries
      .map(
        (entry) => PurchaseProposalGroup(
          supplierId: entry.key,
          supplierName: entry.key == null ? null : supplierNames[entry.key],
          items: entry.value,
        ),
      )
      .toList();

  return Response.json(body: {'proposals': proposals.map((group) => group.toJson()).toList()});
}
