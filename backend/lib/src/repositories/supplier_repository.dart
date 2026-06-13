import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../tenant_encryption_service.dart';

/// Lieferantenstamm — `email`, `phone`, `address`, `iban` und `notes`
/// werden pro Mandant feldverschlüsselt gespeichert (Envelope-Encryption)
/// und bei jedem Lesezugriff entschlüsselt.
class SupplierRepository {
  SupplierRepository(this._pool, this._encryptionService);

  final Pool<void> _pool;
  final TenantEncryptionService _encryptionService;

  static const _columns = 'id, tenant_id, name, contact_person, email, phone, '
      'address, iban, payment_terms_days, notes, created_at';

  Future<Supplier> create({
    required String tenantId,
    required CreateSupplierRequest req,
  }) async {
    final cipher = await _encryptionService.cipherForTenant(tenantId);

    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO suppliers '
        '(tenant_id, name, contact_person, email, phone, address, iban, payment_terms_days, notes) '
        'VALUES (@tenant_id, @name, @contact_person, @email, @phone, @address, @iban, @payment_terms_days, @notes) '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'name': req.name,
        'contact_person': req.contactPerson,
        'email': _encryptNullable(cipher, req.email),
        'phone': _encryptNullable(cipher, req.phone),
        'address': _encryptNullable(cipher, req.address),
        'iban': _encryptNullable(cipher, req.iban),
        'payment_terms_days': req.paymentTermsDays,
        'notes': _encryptNullable(cipher, req.notes),
      },
    );
    return _fromRow(result.first.toColumnMap(), cipher);
  }

  Future<List<Supplier>> list(String tenantId) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM suppliers WHERE tenant_id = @tenant_id ORDER BY name'),
      parameters: {'tenant_id': tenantId},
    );
    if (result.isEmpty) return [];
    final cipher = await _encryptionService.cipherForTenant(tenantId);
    return result.map((row) => _fromRow(row.toColumnMap(), cipher)).toList();
  }

  Future<Supplier?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM suppliers WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;
    final cipher = await _encryptionService.cipherForTenant(tenantId);
    return _fromRow(result.first.toColumnMap(), cipher);
  }

  Future<Supplier?> update({
    required String tenantId,
    required String id,
    required UpdateSupplierRequest req,
  }) async {
    final cipher = await _encryptionService.cipherForTenant(tenantId);
    final result = await _pool.execute(
      Sql.named(
        'UPDATE suppliers SET '
        'name = @name, contact_person = @contact_person, email = @email, '
        'phone = @phone, address = @address, iban = @iban, '
        'payment_terms_days = @payment_terms_days, notes = @notes '
        'WHERE tenant_id = @tenant_id AND id = @id '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'id': id,
        'name': req.name,
        'contact_person': req.contactPerson,
        'email': _encryptNullable(cipher, req.email),
        'phone': _encryptNullable(cipher, req.phone),
        'address': _encryptNullable(cipher, req.address),
        'iban': _encryptNullable(cipher, req.iban),
        'payment_terms_days': req.paymentTermsDays,
        'notes': _encryptNullable(cipher, req.notes),
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap(), cipher);
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM suppliers WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  String? _encryptNullable(FieldCipher cipher, String? value) =>
      (value == null || value.isEmpty) ? null : cipher.encrypt(value);

  String? _decryptNullable(FieldCipher cipher, String? value) =>
      value == null ? null : cipher.decrypt(value);

  Supplier _fromRow(Map<String, dynamic> row, FieldCipher cipher) => Supplier(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        name: row['name'] as String,
        contactPerson: row['contact_person'] as String?,
        email: _decryptNullable(cipher, row['email'] as String?),
        phone: _decryptNullable(cipher, row['phone'] as String?),
        address: _decryptNullable(cipher, row['address'] as String?),
        iban: _decryptNullable(cipher, row['iban'] as String?),
        paymentTermsDays: row['payment_terms_days'] as int?,
        notes: _decryptNullable(cipher, row['notes'] as String?),
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
