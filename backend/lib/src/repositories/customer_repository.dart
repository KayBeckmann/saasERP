import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:uuid/uuid.dart';

import '../tenant_encryption_service.dart';
import 'number_sequence_repository.dart';

const _table = 'customers';

/// Kundenstamm — `email`, `phone`, `address` und `notes` werden pro Mandant
/// feldverschlüsselt gespeichert (authentifizierte Envelope-Encryption,
/// AAD an Mandant/Tabelle/Datensatz/Feld gebunden) und bei jedem
/// Lesezugriff entschlüsselt.
class CustomerRepository {
  CustomerRepository(this._pool, this._encryptionService, this._numberSequences);

  final Pool<void> _pool;
  final TenantEncryptionService _encryptionService;
  final NumberSequenceRepository _numberSequences;
  static const _uuid = Uuid();

  static const _columns = 'id, tenant_id, customer_number, kind, name, '
      'contact_person, email, phone, address, e_invoice_format, leitweg_id, '
      'notes, created_at';

  Future<Customer> create({
    required String tenantId,
    required CreateCustomerRequest req,
  }) async {
    final crypto = await _encryptionService.forTenant(tenantId);
    final customerNumber = await _numberSequences.next(
      tenantId: tenantId,
      sequenceKey: 'customer',
      defaultPrefix: 'K',
    );
    // ID wird anwendungsseitig VOR dem Insert erzeugt (statt Postgres'
    // gen_random_uuid()-Default abzuwarten), damit sie als Teil der AAD in
    // dieselbe Verschlüsselung einfließen kann wie beim späteren Lesen.
    final id = _uuid.v4();

    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO customers '
        '(id, tenant_id, customer_number, kind, name, contact_person, email, phone, address, e_invoice_format, leitweg_id, notes) '
        'VALUES (@id, @tenant_id, @customer_number, @kind, @name, @contact_person, @email, @phone, @address, @e_invoice_format, @leitweg_id, @notes) '
        'RETURNING $_columns',
      ),
      parameters: {
        'id': id,
        'tenant_id': tenantId,
        'customer_number': customerNumber,
        'kind': req.kind.toJson(),
        'name': req.name,
        'contact_person': req.contactPerson,
        'email': crypto.encryptField(table: _table, recordId: id, field: 'email', value: req.email),
        'phone': crypto.encryptField(table: _table, recordId: id, field: 'phone', value: req.phone),
        'address': crypto.encryptField(table: _table, recordId: id, field: 'address', value: req.address),
        'e_invoice_format': req.eInvoiceFormat.toJson(),
        'leitweg_id': req.leitwegId,
        'notes': crypto.encryptField(table: _table, recordId: id, field: 'notes', value: req.notes),
      },
    );
    return _fromRow(result.first.toColumnMap(), crypto);
  }

  Future<List<Customer>> list(String tenantId) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM customers WHERE tenant_id = @tenant_id ORDER BY name'),
      parameters: {'tenant_id': tenantId},
    );
    if (result.isEmpty) return [];
    final crypto = await _encryptionService.forTenant(tenantId);
    return result.map((row) => _fromRow(row.toColumnMap(), crypto)).toList();
  }

  Future<Customer?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM customers WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;
    final crypto = await _encryptionService.forTenant(tenantId);
    return _fromRow(result.first.toColumnMap(), crypto);
  }

  Future<Customer?> update({
    required String tenantId,
    required String id,
    required UpdateCustomerRequest req,
  }) async {
    final crypto = await _encryptionService.forTenant(tenantId);
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
        'email': crypto.encryptField(table: _table, recordId: id, field: 'email', value: req.email),
        'phone': crypto.encryptField(table: _table, recordId: id, field: 'phone', value: req.phone),
        'address': crypto.encryptField(table: _table, recordId: id, field: 'address', value: req.address),
        'e_invoice_format': req.eInvoiceFormat.toJson(),
        'leitweg_id': req.leitwegId,
        'notes': crypto.encryptField(table: _table, recordId: id, field: 'notes', value: req.notes),
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap(), crypto);
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM customers WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  Customer _fromRow(Map<String, dynamic> row, TenantFieldEncryption crypto) {
    final id = row['id'] as String;
    String? dec(String field, String? value) =>
        crypto.decryptField(table: _table, recordId: id, field: field, value: value);
    return Customer(
      id: id,
      tenantId: row['tenant_id'] as String,
      customerNumber: row['customer_number'] as String,
      kind: CustomerKind.fromJson(row['kind'] as String),
      name: row['name'] as String,
      contactPerson: row['contact_person'] as String?,
      email: dec('email', row['email'] as String?),
      phone: dec('phone', row['phone'] as String?),
      address: dec('address', row['address'] as String?),
      eInvoiceFormat: EInvoiceFormat.fromJson(row['e_invoice_format'] as String),
      leitwegId: row['leitweg_id'] as String?,
      notes: dec('notes', row['notes'] as String?),
      createdAt: (row['created_at'] as DateTime).toUtc(),
    );
  }
}
