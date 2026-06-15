import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Abo-Tiers von saasERP (z. B. "Starter"/"Professional"/"Enterprise") —
/// global gepflegt vom Plattform-Admin, nicht mandanten-gescopt.
class SubscriptionTierRepository {
  SubscriptionTierRepository(this._pool);

  final Pool<void> _pool;

  static const _columns = 'id, name, monthly_price, yearly_price, user_limit, '
      'feature_summary, sort_order, is_active, created_at';

  Future<List<SubscriptionTier>> list() async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM subscription_tiers ORDER BY sort_order ASC, name ASC'),
    );
    return result.map((row) => _fromRow(row.toColumnMap())).toList();
  }

  Future<SubscriptionTier?> findById(String id) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM subscription_tiers WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<SubscriptionTier> create(CreateSubscriptionTierRequest req) async {
    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO subscription_tiers (name, monthly_price, yearly_price, user_limit, '
        'feature_summary, sort_order, is_active) '
        'VALUES (@name, @monthly_price, @yearly_price, @user_limit, '
        '@feature_summary, @sort_order, @is_active) '
        'RETURNING $_columns',
      ),
      parameters: {
        'name': req.name,
        'monthly_price': req.monthlyPrice,
        'yearly_price': req.yearlyPrice,
        'user_limit': req.userLimit,
        'feature_summary': req.featureSummary,
        'sort_order': req.sortOrder,
        'is_active': req.isActive,
      },
    );
    return _fromRow(result.first.toColumnMap());
  }

  Future<SubscriptionTier?> update({required String id, required UpdateSubscriptionTierRequest req}) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE subscription_tiers SET name = @name, monthly_price = @monthly_price, '
        'yearly_price = @yearly_price, user_limit = @user_limit, '
        'feature_summary = @feature_summary, sort_order = @sort_order, is_active = @is_active '
        'WHERE id = @id '
        'RETURNING $_columns',
      ),
      parameters: {
        'id': id,
        'name': req.name,
        'monthly_price': req.monthlyPrice,
        'yearly_price': req.yearlyPrice,
        'user_limit': req.userLimit,
        'feature_summary': req.featureSummary,
        'sort_order': req.sortOrder,
        'is_active': req.isActive,
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<bool> delete(String id) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM subscription_tiers WHERE id = @id'),
      parameters: {'id': id},
    );
    return result.affectedRows > 0;
  }

  SubscriptionTier _fromRow(Map<String, dynamic> row) => SubscriptionTier(
        id: row['id'] as String,
        name: row['name'] as String,
        monthlyPrice: (row['monthly_price'] as num).toDouble(),
        yearlyPrice: (row['yearly_price'] as num).toDouble(),
        userLimit: row['user_limit'] as int?,
        featureSummary: row['feature_summary'] as String?,
        sortOrder: row['sort_order'] as int,
        isActive: row['is_active'] as bool,
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
