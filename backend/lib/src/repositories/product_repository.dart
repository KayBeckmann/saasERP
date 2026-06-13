import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Produktstamm — Bundle aus Artikel- und Arbeitszeit-Positionen
/// (`product_components`) mit eigenem Verkaufspreis.
class ProductRepository {
  ProductRepository(this._pool);

  final Pool<void> _pool;

  static const _productColumns =
      'id, tenant_id, sku, name, sale_price, pending_sale_price, vat_rate, notes, created_at';

  static const _componentColumns = 'id, product_id, kind, article_id, label, quantity, unit_cost';

  Future<Product> create({
    required String tenantId,
    required CreateProductRequest req,
  }) async {
    return _pool.runTx((session) async {
      final result = await session.execute(
        Sql.named(
          'INSERT INTO products (tenant_id, sku, name, sale_price, vat_rate, notes) '
          'VALUES (@tenant_id, @sku, @name, @sale_price, @vat_rate, @notes) '
          'RETURNING $_productColumns',
        ),
        parameters: {
          'tenant_id': tenantId,
          'sku': req.sku,
          'name': req.name,
          'sale_price': req.salePrice,
          'vat_rate': req.vatRate,
          'notes': req.notes,
        },
      );
      final productId = result.first.toColumnMap()['id'] as String;

      await _insertComponents(session, tenantId: tenantId, productId: productId, components: req.components);

      final components = await _loadComponents(session, productId: productId);
      return _fromRow(result.first.toColumnMap(), components);
    });
  }

  Future<List<Product>> list(String tenantId) async {
    final productRows = await _pool.execute(
      Sql.named('SELECT $_productColumns FROM products WHERE tenant_id = @tenant_id ORDER BY name'),
      parameters: {'tenant_id': tenantId},
    );
    if (productRows.isEmpty) return [];

    final componentRows = await _pool.execute(
      Sql.named(
        'SELECT $_componentColumns FROM product_components '
        'WHERE tenant_id = @tenant_id ORDER BY product_id, sort_order',
      ),
      parameters: {'tenant_id': tenantId},
    );

    final componentsByProduct = <String, List<ProductComponent>>{};
    for (final row in componentRows) {
      final map = row.toColumnMap();
      final productId = map['product_id'] as String;
      componentsByProduct.putIfAbsent(productId, () => []).add(_componentFromRow(map));
    }

    return productRows
        .map((row) => _fromRow(row.toColumnMap(), componentsByProduct[row.toColumnMap()['id']] ?? []))
        .toList();
  }

  Future<Product?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_productColumns FROM products WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;

    final components = await _loadComponents(_pool, productId: id);
    return _fromRow(result.first.toColumnMap(), components);
  }

  Future<Product?> update({
    required String tenantId,
    required String id,
    required UpdateProductRequest req,
  }) async {
    return _pool.runTx((session) async {
      final result = await session.execute(
        Sql.named(
          'UPDATE products SET sku = @sku, name = @name, sale_price = @sale_price, '
          'vat_rate = @vat_rate, notes = @notes '
          'WHERE tenant_id = @tenant_id AND id = @id '
          'RETURNING $_productColumns',
        ),
        parameters: {
          'tenant_id': tenantId,
          'id': id,
          'sku': req.sku,
          'name': req.name,
          'sale_price': req.salePrice,
          'vat_rate': req.vatRate,
          'notes': req.notes,
        },
      );
      if (result.isEmpty) return null;

      await session.execute(
        Sql.named('DELETE FROM product_components WHERE product_id = @product_id'),
        parameters: {'product_id': id},
      );
      await _insertComponents(session, tenantId: tenantId, productId: id, components: req.components);

      final components = await _loadComponents(session, productId: id);
      return _fromRow(result.first.toColumnMap(), components);
    });
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM products WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  /// Bestätigt den vorgeschlagenen Verkaufspreis: `sale_price` wird auf
  /// `pending_sale_price` gesetzt, der Vorschlag gelöscht und alle
  /// Artikel-Positionen auf die aktuellen Einkaufspreise aktualisiert.
  Future<Product?> confirmPendingPrice({required String tenantId, required String id}) async {
    return _pool.runTx((session) async {
      final productResult = await session.execute(
        Sql.named(
          'UPDATE products SET sale_price = pending_sale_price, pending_sale_price = NULL '
          'WHERE tenant_id = @tenant_id AND id = @id AND pending_sale_price IS NOT NULL '
          'RETURNING $_productColumns',
        ),
        parameters: {'tenant_id': tenantId, 'id': id},
      );
      if (productResult.isEmpty) return null;

      await session.execute(
        Sql.named(
          'UPDATE product_components pc SET unit_cost = a.purchase_price '
          'FROM articles a WHERE pc.article_id = a.id AND pc.product_id = @product_id '
          "AND pc.kind = 'article' AND a.purchase_price IS NOT NULL",
        ),
        parameters: {'product_id': id},
      );

      final components = await _loadComponents(session, productId: id);
      return _fromRow(productResult.first.toColumnMap(), components);
    });
  }

  /// Verwirft den vorgeschlagenen Verkaufspreis ohne Änderungen.
  Future<Product?> rejectPendingPrice({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE products SET pending_sale_price = NULL '
        'WHERE tenant_id = @tenant_id AND id = @id '
        'RETURNING $_productColumns',
      ),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;

    final components = await _loadComponents(_pool, productId: id);
    return _fromRow(result.first.toColumnMap(), components);
  }

  /// Berechnet für alle Produkte, die einen der [articleIds] als
  /// Artikel-Position enthalten, einen neuen Verkaufspreis-Vorschlag
  /// (`pending_sale_price`): Der bestehende `sale_price` wird proportional
  /// zur Kostenänderung skaliert (Marge bleibt erhalten); ist der bisherige
  /// Kostenstand 0, wird der neue Kostenstand direkt als Vorschlag gesetzt.
  Future<List<ProductPriceSuggestion>> recalculatePendingPrices({
    required String tenantId,
    required Set<String> articleIds,
  }) async {
    if (articleIds.isEmpty) return [];

    final productIds = <String>{};
    for (final articleId in articleIds) {
      final result = await _pool.execute(
        Sql.named(
          'SELECT DISTINCT product_id FROM product_components '
          "WHERE tenant_id = @tenant_id AND kind = 'article' AND article_id = @article_id",
        ),
        parameters: {'tenant_id': tenantId, 'article_id': articleId},
      );
      for (final row in result) {
        productIds.add(row.toColumnMap()['product_id'] as String);
      }
    }

    final suggestions = <ProductPriceSuggestion>[];
    for (final productId in productIds) {
      final productResult = await _pool.execute(
        Sql.named('SELECT id, name, sale_price FROM products WHERE tenant_id = @tenant_id AND id = @id'),
        parameters: {'tenant_id': tenantId, 'id': productId},
      );
      if (productResult.isEmpty) continue;
      final productRow = productResult.first.toColumnMap();
      final salePrice = (productRow['sale_price'] as num).toDouble();

      final componentResult = await _pool.execute(
        Sql.named(
          'SELECT pc.kind, pc.quantity, pc.unit_cost, a.purchase_price AS current_purchase_price '
          'FROM product_components pc LEFT JOIN articles a ON a.id = pc.article_id '
          'WHERE pc.product_id = @product_id',
        ),
        parameters: {'product_id': productId},
      );

      var oldCost = 0.0;
      var newCost = 0.0;
      for (final row in componentResult) {
        final map = row.toColumnMap();
        final kind = map['kind'] as String;
        final quantity = (map['quantity'] as num).toDouble();
        final unitCost = (map['unit_cost'] as num).toDouble();
        oldCost += quantity * unitCost;
        if (kind == 'article' && map['current_purchase_price'] != null) {
          newCost += quantity * (map['current_purchase_price'] as num).toDouble();
        } else {
          newCost += quantity * unitCost;
        }
      }

      if ((newCost - oldCost).abs() < 0.0001) continue;

      final pendingSalePrice = oldCost > 0 ? salePrice * (newCost / oldCost) : newCost;
      final rounded = (pendingSalePrice * 100).round() / 100;

      await _pool.execute(
        Sql.named('UPDATE products SET pending_sale_price = @pending WHERE id = @id'),
        parameters: {'pending': rounded, 'id': productId},
      );

      suggestions.add(
        ProductPriceSuggestion(
          productId: productId,
          name: productRow['name'] as String,
          oldSalePrice: salePrice,
          pendingSalePrice: rounded,
        ),
      );
    }

    return suggestions;
  }

  Future<void> _insertComponents(
    Session session, {
    required String tenantId,
    required String productId,
    required List<ProductComponent> components,
  }) async {
    for (var i = 0; i < components.length; i++) {
      final component = components[i];
      await session.execute(
        Sql.named(
          'INSERT INTO product_components '
          '(tenant_id, product_id, kind, article_id, label, quantity, unit_cost, sort_order) '
          'VALUES (@tenant_id, @product_id, @kind, @article_id, @label, @quantity, @unit_cost, @sort_order)',
        ),
        parameters: {
          'tenant_id': tenantId,
          'product_id': productId,
          'kind': component.kind.toJson(),
          'article_id': component.articleId,
          'label': component.label,
          'quantity': component.quantity,
          'unit_cost': component.unitCost,
          'sort_order': i,
        },
      );
    }
  }

  Future<List<ProductComponent>> _loadComponents(Session session, {required String productId}) async {
    final result = await session.execute(
      Sql.named(
        'SELECT $_componentColumns FROM product_components '
        'WHERE product_id = @product_id ORDER BY sort_order',
      ),
      parameters: {'product_id': productId},
    );
    return result.map((row) => _componentFromRow(row.toColumnMap())).toList();
  }

  ProductComponent _componentFromRow(Map<String, dynamic> row) => ProductComponent(
        id: row['id'] as String,
        kind: ProductComponentKind.fromJson(row['kind'] as String),
        articleId: row['article_id'] as String?,
        label: row['label'] as String?,
        quantity: (row['quantity'] as num).toDouble(),
        unitCost: (row['unit_cost'] as num).toDouble(),
      );

  Product _fromRow(Map<String, dynamic> row, List<ProductComponent> components) => Product(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        sku: row['sku'] as String?,
        name: row['name'] as String,
        salePrice: (row['sale_price'] as num).toDouble(),
        pendingSalePrice: (row['pending_sale_price'] as num?)?.toDouble(),
        vatRate: (row['vat_rate'] as num).toDouble(),
        notes: row['notes'] as String?,
        createdAt: (row['created_at'] as DateTime).toUtc(),
        components: components,
      );
}
