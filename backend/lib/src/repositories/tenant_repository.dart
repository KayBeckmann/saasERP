import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

class TenantRepository {
  TenantRepository(this._pool);

  final Pool<void> _pool;

  Future<Tenant> create(String name) async {
    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO tenants (name) VALUES (@name) '
        'RETURNING id, name, created_at',
      ),
      parameters: {'name': name},
    );
    return _fromRow(result.first.toColumnMap());
  }

  Future<Tenant?> findById(String id) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT id, name, created_at FROM tenants WHERE id = @id',
      ),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Tenant _fromRow(Map<String, dynamic> row) => Tenant(
        id: row['id'] as String,
        name: row['name'] as String,
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
