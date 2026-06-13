import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Artikelstamm — keine personenbezogenen Daten, daher ohne
/// Feldverschlüsselung.
class ArticleRepository {
  ArticleRepository(this._pool);

  final Pool<void> _pool;

  static const _columns = 'id, tenant_id, sku, name, unit, purchase_price, '
      'sale_price, vat_rate, usage_count, notes, created_at';

  Future<Article> create({
    required String tenantId,
    required CreateArticleRequest req,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO articles '
        '(tenant_id, sku, name, unit, purchase_price, sale_price, vat_rate, notes) '
        'VALUES (@tenant_id, @sku, @name, @unit, @purchase_price, @sale_price, @vat_rate, @notes) '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'sku': req.sku,
        'name': req.name,
        'unit': req.unit,
        'purchase_price': req.purchasePrice,
        'sale_price': req.salePrice,
        'vat_rate': req.vatRate,
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

  Future<Article?> update({
    required String tenantId,
    required String id,
    required UpdateArticleRequest req,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE articles SET '
        'sku = @sku, name = @name, unit = @unit, purchase_price = @purchase_price, '
        'sale_price = @sale_price, vat_rate = @vat_rate, notes = @notes '
        'WHERE tenant_id = @tenant_id AND id = @id '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'id': id,
        'sku': req.sku,
        'name': req.name,
        'unit': req.unit,
        'purchase_price': req.purchasePrice,
        'sale_price': req.salePrice,
        'vat_rate': req.vatRate,
        'notes': req.notes,
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM articles WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  Article _fromRow(Map<String, dynamic> row) => Article(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        sku: row['sku'] as String?,
        name: row['name'] as String,
        unit: row['unit'] as String?,
        purchasePrice: (row['purchase_price'] as num?)?.toDouble(),
        salePrice: (row['sale_price'] as num?)?.toDouble(),
        vatRate: (row['vat_rate'] as num).toDouble(),
        usageCount: row['usage_count'] as int,
        notes: row['notes'] as String?,
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
