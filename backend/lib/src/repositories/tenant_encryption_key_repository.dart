import 'package:postgres/postgres.dart';

/// Eine (master-key-gewrappte) Tenant-Schlüsselversion.
class TenantEncryptionKeyRow {
  const TenantEncryptionKeyRow({
    required this.tenantId,
    required this.keyVersion,
    required this.wrappedKey,
    required this.status,
  });

  final String tenantId;
  final int keyVersion;
  final String wrappedKey;
  final String status;

  bool get isActive => status == 'active';
}

/// Speichert die mit dem Master-Key gewrappten Data-Encryption-Keys (DEK)
/// der Mandanten (Envelope-Encryption, siehe `TenantEncryptionService`) —
/// versioniert, um Schlüsselrotation zu ermöglichen (RF1).
class TenantEncryptionKeyRepository {
  TenantEncryptionKeyRepository(this._pool);

  final Pool<void> _pool;

  static const _columns = 'tenant_id, key_version, wrapped_key, status';

  /// Legt die erste (aktive) Schlüsselversion für einen neuen Mandanten an.
  /// Wird bei der Registrierung aufgerufen.
  Future<void> create({
    required String tenantId,
    required int keyVersion,
    required String wrappedKey,
  }) async {
    await _pool.execute(
      Sql.named(
        'INSERT INTO tenant_encryption_keys (tenant_id, key_version, wrapped_key, status) '
        "VALUES (@tenant_id, @key_version, @wrapped_key, 'active') "
        'ON CONFLICT (tenant_id, key_version) DO NOTHING',
      ),
      parameters: {
        'tenant_id': tenantId,
        'key_version': keyVersion,
        'wrapped_key': wrappedKey,
      },
    );
  }

  /// Die aktuell aktive Schlüsselversion eines Mandanten (für neue
  /// Verschlüsselungen).
  Future<TenantEncryptionKeyRow?> findActive(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns FROM tenant_encryption_keys '
        "WHERE tenant_id = @tenant_id AND status = 'active'",
      ),
      parameters: {'tenant_id': tenantId},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  /// Eine bestimmte (ggf. retired) Schlüsselversion — zum Entschlüsseln von
  /// Altdaten nach einer Rotation.
  Future<TenantEncryptionKeyRow?> find(String tenantId, int keyVersion) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns FROM tenant_encryption_keys '
        'WHERE tenant_id = @tenant_id AND key_version = @key_version',
      ),
      parameters: {'tenant_id': tenantId, 'key_version': keyVersion},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  /// Alle Schlüsselversionen eines Mandanten, neueste zuerst — für die
  /// Rotations-Abnahme/Diagnose.
  Future<List<TenantEncryptionKeyRow>> listVersions(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns FROM tenant_encryption_keys '
        'WHERE tenant_id = @tenant_id ORDER BY key_version DESC',
      ),
      parameters: {'tenant_id': tenantId},
    );
    return result.map((row) => _fromRow(row.toColumnMap())).toList();
  }

  /// Transaktionale Rotation: legt [newKeyVersion] als neue aktive Version
  /// an und setzt die zuvor aktive Version auf `retired`. Muss innerhalb
  /// derselben Transaktion erfolgen, in der auch alle Bestandsdaten auf die
  /// neue Version umgeschlüsselt werden (siehe `TenantKeyRotationService`),
  /// damit niemals zwei aktive Versionen gleichzeitig existieren.
  Future<void> activateNewVersion({
    required TxSession tx,
    required String tenantId,
    required int newKeyVersion,
    required String wrappedKey,
  }) async {
    await tx.execute(
      Sql.named(
        "UPDATE tenant_encryption_keys SET status = 'retired', retired_at = now() "
        "WHERE tenant_id = @tenant_id AND status = 'active'",
      ),
      parameters: {'tenant_id': tenantId},
    );
    await tx.execute(
      Sql.named(
        'INSERT INTO tenant_encryption_keys (tenant_id, key_version, wrapped_key, status) '
        "VALUES (@tenant_id, @key_version, @wrapped_key, 'active')",
      ),
      parameters: {
        'tenant_id': tenantId,
        'key_version': newKeyVersion,
        'wrapped_key': wrappedKey,
      },
    );
  }

  TenantEncryptionKeyRow _fromRow(Map<String, dynamic> row) => TenantEncryptionKeyRow(
        tenantId: row['tenant_id'] as String,
        keyVersion: row['key_version'] as int,
        wrappedKey: row['wrapped_key'] as String,
        status: row['status'] as String,
      );
}
