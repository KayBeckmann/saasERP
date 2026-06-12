import 'package:postgres/postgres.dart';

/// Speichert die mit dem Master-Key gewrappten Data-Encryption-Keys (DEK)
/// der Mandanten (Envelope-Encryption, siehe `TenantEncryptionService`).
class TenantEncryptionKeyRepository {
  TenantEncryptionKeyRepository(this._pool);

  final Pool<void> _pool;

  Future<void> create({
    required String tenantId,
    required String wrappedKey,
  }) async {
    await _pool.execute(
      Sql.named(
        'INSERT INTO tenant_encryption_keys (tenant_id, wrapped_key) '
        'VALUES (@tenant_id, @wrapped_key) '
        'ON CONFLICT (tenant_id) DO NOTHING',
      ),
      parameters: {'tenant_id': tenantId, 'wrapped_key': wrappedKey},
    );
  }

  Future<String?> findWrappedKey(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT wrapped_key FROM tenant_encryption_keys WHERE tenant_id = @tenant_id',
      ),
      parameters: {'tenant_id': tenantId},
    );
    if (result.isEmpty) return null;
    return result.first.toColumnMap()['wrapped_key'] as String;
  }
}
