import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:uuid/uuid.dart';

import '../tenant_encryption_service.dart';

const _table = 'suppliers';

/// Lieferantenstamm — `contact_person`, `email`, `phone`, `address`, `iban`
/// und `notes` werden pro Mandant feldverschlüsselt gespeichert
/// (authentifizierte Envelope-Encryption) und bei jedem Lesezugriff
/// entschlüsselt.
class SupplierRepository {
  SupplierRepository(this._pool, this._encryptionService);

  final Pool<void> _pool;
  final TenantEncryptionService _encryptionService;
  static const _uuid = Uuid();

  static const _columns = 'id, tenant_id, name, contact_person, email, phone, '
      'address, iban, payment_terms_days, notes, created_at';

  Future<Supplier> create({
    required String tenantId,
    required CreateSupplierRequest req,
  }) async {
    final crypto = await _encryptionService.forTenant(tenantId);
    final id = _uuid.v4();

    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO suppliers '
        '(id, tenant_id, name, contact_person, email, phone, address, iban, payment_terms_days, notes) '
        'VALUES (@id, @tenant_id, @name, @contact_person, @email, @phone, @address, @iban, @payment_terms_days, @notes) '
        'RETURNING $_columns',
      ),
      parameters: {
        'id': id,
        'tenant_id': tenantId,
        'name': req.name,
        'contact_person': crypto.encryptField(table: _table, recordId: id, field: 'contact_person', value: req.contactPerson),
        'email': crypto.encryptField(table: _table, recordId: id, field: 'email', value: req.email),
        'phone': crypto.encryptField(table: _table, recordId: id, field: 'phone', value: req.phone),
        'address': crypto.encryptField(table: _table, recordId: id, field: 'address', value: req.address),
        'iban': crypto.encryptField(table: _table, recordId: id, field: 'iban', value: req.iban),
        'payment_terms_days': req.paymentTermsDays,
        'notes': crypto.encryptField(table: _table, recordId: id, field: 'notes', value: req.notes),
      },
    );
    return _fromRow(result.first.toColumnMap(), crypto);
  }

  Future<List<Supplier>> list(String tenantId) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM suppliers WHERE tenant_id = @tenant_id ORDER BY name'),
      parameters: {'tenant_id': tenantId},
    );
    if (result.isEmpty) return [];
    final crypto = await _encryptionService.forTenant(tenantId);
    return result.map((row) => _fromRow(row.toColumnMap(), crypto)).toList();
  }

  Future<Supplier?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM suppliers WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;
    final crypto = await _encryptionService.forTenant(tenantId);
    return _fromRow(result.first.toColumnMap(), crypto);
  }

  Future<Supplier?> update({
    required String tenantId,
    required String id,
    required UpdateSupplierRequest req,
  }) async {
    final crypto = await _encryptionService.forTenant(tenantId);
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
        'contact_person': crypto.encryptField(table: _table, recordId: id, field: 'contact_person', value: req.contactPerson),
        'email': crypto.encryptField(table: _table, recordId: id, field: 'email', value: req.email),
        'phone': crypto.encryptField(table: _table, recordId: id, field: 'phone', value: req.phone),
        'address': crypto.encryptField(table: _table, recordId: id, field: 'address', value: req.address),
        'iban': crypto.encryptField(table: _table, recordId: id, field: 'iban', value: req.iban),
        'payment_terms_days': req.paymentTermsDays,
        'notes': crypto.encryptField(table: _table, recordId: id, field: 'notes', value: req.notes),
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap(), crypto);
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM suppliers WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  Supplier _fromRow(Map<String, dynamic> row, TenantFieldEncryption crypto) {
    final id = row['id'] as String;
    String? dec(String field, String? value) =>
        crypto.decryptField(table: _table, recordId: id, field: field, value: value);
    return Supplier(
      id: id,
      tenantId: row['tenant_id'] as String,
      name: row['name'] as String,
      contactPerson: dec('contact_person', row['contact_person'] as String?),
      email: dec('email', row['email'] as String?),
      phone: dec('phone', row['phone'] as String?),
      address: dec('address', row['address'] as String?),
      iban: dec('iban', row['iban'] as String?),
      paymentTermsDays: row['payment_terms_days'] as int?,
      notes: dec('notes', row['notes'] as String?),
      createdAt: (row['created_at'] as DateTime).toUtc(),
    );
  }
}
