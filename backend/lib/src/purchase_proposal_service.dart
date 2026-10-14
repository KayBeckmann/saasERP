import 'package:saaserp_shared/saaserp_shared.dart';

import 'repositories/article_repository.dart';
import 'repositories/order_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/purchase_order_repository.dart';
import 'repositories/supplier_repository.dart';

/// Berechnet Bestellvorschläge aus einem Auftrag und erzeugt daraus auf
/// Wunsch echte, pro Lieferant getrennte Bestellentwürfe — in einer
/// einzigen, geteilten Logik für `GET .../purchase-proposal` (Vorschau)
/// und `POST .../purchase-proposal/create-drafts` (tatsächliche Anlage),
/// damit beide niemals auseinanderlaufen (Roadmap "Raumgruppen → Auftrag →
/// Lieferantenbestellungen").
class PurchaseProposalService {
  PurchaseProposalService(
    this._orderRepository,
    this._productRepository,
    this._articleRepository,
    this._supplierRepository,
    this._purchaseOrderRepository,
  );

  final OrderRepository _orderRepository;
  final ProductRepository _productRepository;
  final ArticleRepository _articleRepository;
  final SupplierRepository _supplierRepository;
  final PurchaseOrderRepository _purchaseOrderRepository;

  /// `null`, wenn der Auftrag nicht existiert.
  Future<List<PurchaseProposalGroup>?> buildProposal({
    required String tenantId,
    required String orderId,
  }) async {
    final order = await _orderRepository.findById(tenantId: tenantId, id: orderId);
    if (order == null) return null;

    // Je Artikel: Gesamtbedarf + Aufschlüsselung nach beitragender
    // Auftragsposition/Raumgruppe (für die Rückverfolgung, siehe
    // PurchaseOrderItemSource).
    final requiredQuantities = <String, double>{};
    final contributions = <String, List<PurchaseOrderItemSource>>{};

    void addContribution(String articleId, OrderItem sourceItem, double quantity) {
      requiredQuantities[articleId] = (requiredQuantities[articleId] ?? 0) + quantity;
      contributions.putIfAbsent(articleId, () => []).add(
            PurchaseOrderItemSource(
              orderId: orderId,
              orderItemId: sourceItem.id,
              groupLabel: sourceItem.groupLabel,
              quantity: quantity,
            ),
          );
    }

    for (final item in order.items) {
      if (item.kind == OrderItemKind.article && item.articleId != null) {
        addContribution(item.articleId!, item, item.quantity);
        continue;
      }
      if (item.kind == OrderItemKind.product && item.productId != null) {
        final product = await _productRepository.findById(tenantId: tenantId, id: item.productId!);
        if (product == null) continue;
        for (final component in product.components) {
          if (component.kind == ProductComponentKind.article && component.articleId != null) {
            addContribution(component.articleId!, item, component.quantity * item.quantity);
          }
        }
      }
    }

    if (requiredQuantities.isEmpty) return [];

    final articles =
        await _articleRepository.findByIds(tenantId: tenantId, ids: requiredQuantities.keys.toSet());
    final articlesById = {for (final article in articles) article.id: article};

    final suppliers = await _supplierRepository.list(tenantId);
    final supplierNames = {for (final supplier in suppliers) supplier.id: supplier.name};

    final alreadyOrdered =
        await _purchaseOrderRepository.sumOrderedQuantitiesForOrder(tenantId: tenantId, orderId: orderId);

    final itemsBySupplier = <String?, List<PurchaseProposalItem>>{};
    for (final entry in requiredQuantities.entries) {
      final article = articlesById[entry.key];
      if (article == null) continue;

      final already = alreadyOrdered[entry.key] ?? 0;
      final orderQuantity = entry.value - article.stockQuantity - already;
      if (orderQuantity <= 0) continue;

      itemsBySupplier.putIfAbsent(article.defaultSupplierId, () => []).add(
            PurchaseProposalItem(
              articleId: article.id,
              description: article.name,
              unit: article.unit,
              requiredQuantity: entry.value,
              stockQuantity: article.stockQuantity,
              alreadyOrderedQuantity: already,
              orderQuantity: orderQuantity,
              unitPrice: article.purchasePrice,
              sources: contributions[entry.key] ?? const [],
            ),
          );
    }

    return itemsBySupplier.entries
        .map(
          (entry) => PurchaseProposalGroup(
            supplierId: entry.key,
            supplierName: entry.key == null ? null : supplierNames[entry.key],
            items: entry.value,
          ),
        )
        .toList();
  }

  /// Erzeugt für jeden gewählten Lieferanten (oder alle, falls
  /// [supplierIds] `null` ist) einen eigenen Bestellentwurf aus dem
  /// aktuellen Vorschlag. Lieferantengruppen ohne offene Bestellmenge
  /// (z. B. durch Lagerbestand oder bereits bestehende Bestellungen bereits
  /// gedeckt) werden übersprungen. `null`, wenn der Auftrag nicht
  /// existiert.
  Future<List<PurchaseOrder>?> createDraftsFromProposal({
    required String tenantId,
    required String orderId,
    Set<String?>? supplierIds,
  }) async {
    final groups = await buildProposal(tenantId: tenantId, orderId: orderId);
    if (groups == null) return null;

    final selected =
        supplierIds == null ? groups : groups.where((g) => supplierIds.contains(g.supplierId)).toList();

    final created = <PurchaseOrder>[];
    for (final group in selected) {
      if (group.items.isEmpty) continue;
      final purchaseOrder = await _purchaseOrderRepository.create(
        tenantId: tenantId,
        req: CreatePurchaseOrderRequest(
          supplierId: group.supplierId,
          orderId: orderId,
          items: [
            for (final item in group.items)
              PurchaseOrderItem(
                articleId: item.articleId,
                description: item.description,
                quantity: item.orderQuantity,
                unit: item.unit,
                unitPrice: item.unitPrice ?? 0,
                sources: item.sources,
              ),
          ],
        ),
      );
      created.add(purchaseOrder);
    }
    return created;
  }
}
