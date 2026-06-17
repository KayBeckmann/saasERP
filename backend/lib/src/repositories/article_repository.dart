import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Artikelstamm — keine personenbezogenen Daten, daher ohne
/// Feldverschlüsselung.
class ArticleRepository {
  ArticleRepository(this._pool);

  final Pool<void> _pool;

  static const _columns = 'id, tenant_id, sku, supplier_sku, name, unit, purchase_price, '
      'sale_price, vat_rate, usage_count, stock_quantity, minimum_stock, default_supplier_id, notes, created_at';

  Future<Article> create({
    required String tenantId,
    required CreateArticleRequest req,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO articles '
        '(tenant_id, sku, supplier_sku, name, unit, purchase_price, sale_price, vat_rate, stock_quantity, minimum_stock, default_supplier_id, notes) '
        'VALUES (@tenant_id, @sku, @supplier_sku, @name, @unit, @purchase_price, @sale_price, @vat_rate, @stock_quantity, @minimum_stock, @default_supplier_id, @notes) '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'sku': req.sku,
        'supplier_sku': req.supplierSku,
        'name': req.name,
        'unit': req.unit,
        'purchase_price': req.purchasePrice,
        'sale_price': req.salePrice,
        'vat_rate': req.vatRate,
        'stock_quantity': req.stockQuantity,
        'minimum_stock': req.minimumStock,
        'default_supplier_id': req.defaultSupplierId,
        'notes': req.notes,
      },
    );
    return _fromRow(result.first.toColumnMap());
  }

  Future<List<Article>> list(String tenantId) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM articles WHERE tenant_id = @tenant_id ORDER BY name'),
      parameters: {'tenant_id': tenantId},
    );
    return result.map((row) => _fromRow(row.toColumnMap())).toList();
  }

  Future<Article?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM articles WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  /// Lädt mehrere Artikel anhand ihrer IDs (z. B. für den Bestellvorschlag).
  Future<List<Article>> findByIds({required String tenantId, required Set<String> ids}) async {
    if (ids.isEmpty) return [];
    final idList = ids.toList();
    final placeholders = [for (var i = 0; i < idList.length; i++) '@id$i'].join(', ');
    final parameters = <String, dynamic>{'tenant_id': tenantId};
    for (var i = 0; i < idList.length; i++) {
      parameters['id$i'] = idList[i];
    }
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM articles WHERE tenant_id = @tenant_id AND id IN ($placeholders)'),
      parameters: parameters,
    );
    return result.map((row) => _fromRow(row.toColumnMap())).toList();
  }

  Future<Article?> update({
    required String tenantId,
    required String id,
    required UpdateArticleRequest req,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE articles SET '
        'sku = @sku, supplier_sku = @supplier_sku, name = @name, unit = @unit, purchase_price = @purchase_price, '
        'sale_price = @sale_price, vat_rate = @vat_rate, stock_quantity = @stock_quantity, '
        'minimum_stock = @minimum_stock, default_supplier_id = @default_supplier_id, notes = @notes '
        'WHERE tenant_id = @tenant_id AND id = @id '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'id': id,
        'sku': req.sku,
        'supplier_sku': req.supplierSku,
        'name': req.name,
        'unit': req.unit,
        'purchase_price': req.purchasePrice,
        'sale_price': req.salePrice,
        'vat_rate': req.vatRate,
        'stock_quantity': req.stockQuantity,
        'minimum_stock': req.minimumStock,
        'default_supplier_id': req.defaultSupplierId,
        'notes': req.notes,
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  /// Verändert `stock_quantity` um `delta` (negativ für Lagerentnahme,
  /// positiv für Wareneingang/Korrektur). Keine Untergrenze bei 0 — ein
  /// negativer Bestand ist möglich und zeigt eine Überverbrauchssituation an.
  Future<void> adjustStock({
    required String tenantId,
    required String id,
    required double delta,
  }) async {
    await _pool.execute(
      Sql.named(
        'UPDATE articles SET stock_quantity = stock_quantity + @delta '
        'WHERE tenant_id = @tenant_id AND id = @id',
      ),
      parameters: {'tenant_id': tenantId, 'id': id, 'delta': delta},
    );
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM articles WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  /// Aktualisiert `purchase_price` für jeden Artikel, dessen `sku` zu
  /// `rows` passt. Artikel ohne Treffer landen nicht im Ergebnis — die
  /// SKUs ohne Treffer ermittelt der Aufrufer per Differenzbildung.
  Future<List<ArticlePriceUpdate>> importPurchasePrices({
    required String tenantId,
    required Map<String, double> pricesBySku,
  }) async {
    final updates = <ArticlePriceUpdate>[];
    for (final entry in pricesBySku.entries) {
      final result = await _pool.execute(
        Sql.named(
          'WITH old AS (SELECT id, purchase_price FROM articles '
          'WHERE tenant_id = @tenant_id AND sku = @sku) '
          'UPDATE articles a SET purchase_price = @new_price '
          'FROM old WHERE a.id = old.id '
          'RETURNING a.id, a.sku, a.name, old.purchase_price AS old_price, a.purchase_price AS new_price',
        ),
        parameters: {'tenant_id': tenantId, 'sku': entry.key, 'new_price': entry.value},
      );
      if (result.isEmpty) continue;
      final row = result.first.toColumnMap();
      updates.add(
        ArticlePriceUpdate(
          articleId: row['id'] as String,
          sku: row['sku'] as String,
          name: row['name'] as String,
          oldPurchasePrice: (row['old_price'] as num?)?.toDouble(),
          newPurchasePrice: (row['new_price'] as num).toDouble(),
        ),
      );
    }
    return updates;
  }

  Article _fromRow(Map<String, dynamic> row) => Article(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        sku: row['sku'] as String?,
        supplierSku: row['supplier_sku'] as String?,
        name: row['name'] as String,
        unit: row['unit'] as String?,
        purchasePrice: (row['purchase_price'] as num?)?.toDouble(),
        salePrice: (row['sale_price'] as num?)?.toDouble(),
        vatRate: (row['vat_rate'] as num).toDouble(),
        usageCount: row['usage_count'] as int,
        stockQuantity: (row['stock_quantity'] as num).toDouble(),
        minimumStock: (row['minimum_stock'] as num).toDouble(),
        defaultSupplierId: row['default_supplier_id'] as String?,
        notes: row['notes'] as String?,
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
