import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../tenant_encryption_service.dart';
import 'number_sequence_repository.dart';

/// Kundenstamm — `email`, `phone`, `address` und `notes` werden pro Mandant
/// feldverschlüsselt gespeichert (Envelope-Encryption) und bei jedem
/// Lesezugriff entschlüsselt.
class CustomerRepository {
  CustomerRepository(this._pool, this._encryptionService, this._numberSequences);

  final Pool<void> _pool;
  final TenantEncryptionService _encryptionService;
  final NumberSequenceRepository _numberSequences;

  static const _columns = 'id, tenant_id, customer_number, kind, name, '
      'contact_person, email, phone, address, e_invoice_format, leitweg_id, '
      'notes, created_at';

  Future<Customer> create({
    required String tenantId,
    required CreateCustomerRequest req,
  }) async {
    final cipher = await _encryptionService.cipherForTenant(tenantId);
    final customerNumber = await _numberSequences.next(
      tenantId: tenantId,
      sequenceKey: 'customer',
      defaultPrefix: 'K',
    );

    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO customers '
        '(tenant_id, customer_number, kind, name, contact_person, email, phone, address, e_invoice_format, leitweg_id, notes) '
        'VALUES (@tenant_id, @customer_number, @kind, @name, @contact_person, @email, @phone, @address, @e_invoice_format, @leitweg_id, @notes) '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'customer_number': customerNumber,
        'kind': req.kind.toJson(),
        'name': req.name,
        'contact_person': req.contactPerson,
        'email': _encryptNullable(cipher, req.email),
        'phone': _encryptNullable(cipher, req.phone),
        'address': _encryptNullable(cipher, req.address),
        'e_invoice_format': req.eInvoiceFormat.toJson(),
        'leitweg_id': req.leitwegId,
        'notes': _encryptNullable(cipher, req.notes),
      },
    );
    return _fromRow(result.first.toColumnMap(), cipher);
  }

  Future<List<Customer>> list(String tenantId) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM customers WHERE tenant_id = @tenant_id ORDER BY name'),
      parameters: {'tenant_id': tenantId},
    );
    if (result.isEmpty) return [];
    final cipher = await _encryptionService.cipherForTenant(tenantId);
    return result.map((row) => _fromRow(row.toColumnMap(), cipher)).toList();
  }

  Future<Customer?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM customers WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;
    final cipher = await _encryptionService.cipherForTenant(tenantId);
    return _fromRow(result.first.toColumnMap(), cipher);
  }

  Future<Customer?> update({
    required String tenantId,
    required String id,
    required UpdateCustomerRequest req,
  }) async {
    final cipher = await _encryptionService.cipherForTenant(tenantId);
    final result = await _pool.execute(
      Sql.named(
        'UPDATE customers SET '
        'kind = @kind, name = @name, contact_person = @contact_person, '
        'email = @email, phone = @phone, address = @address, '
        'e_invoice_format = @e_invoice_format, leitweg_id = @leitweg_id, notes = @notes '
        'WHERE tenant_id = @tenant_id AND id = @id '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'id': id,
        'kind': req.kind.toJson(),
        'name': req.name,
        'contact_person': req.contactPerson,
        'email': _encryptNullable(cipher, req.email),
        'phone': _encryptNullable(cipher, req.phone),
        'address': _encryptNullable(cipher, req.address),
        'e_invoice_format': req.eInvoiceFormat.toJson(),
        'leitweg_id': req.leitwegId,
        'notes': _encryptNullable(cipher, req.notes),
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap(), cipher);
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM customers WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  String? _encryptNullable(FieldCipher cipher, String? value) =>
      (value == null || value.isEmpty) ? null : cipher.encrypt(value);

  String? _decryptNullable(FieldCipher cipher, String? value) =>
      value == null ? null : cipher.decrypt(value);

  Customer _fromRow(Map<String, dynamic> row, FieldCipher cipher) => Customer(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        customerNumber: row['customer_number'] as String,
        kind: CustomerKind.fromJson(row['kind'] as String),
        name: row['name'] as String,
        contactPerson: row['contact_person'] as String?,
        email: _decryptNullable(cipher, row['email'] as String?),
        phone: _decryptNullable(cipher, row['phone'] as String?),
        address: _decryptNullable(cipher, row['address'] as String?),
        eInvoiceFormat: EInvoiceFormat.fromJson(row['e_invoice_format'] as String),
        leitwegId: row['leitweg_id'] as String?,
        notes: _decryptNullable(cipher, row['notes'] as String?),
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
