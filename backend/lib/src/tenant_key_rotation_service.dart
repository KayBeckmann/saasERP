import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'tenant_encryption_service.dart';

/// Ergebnis einer abgeschlossenen Schlüsselrotation (RF1-Abnahmekriterium:
/// "Schlüsselrotation ... mit zwei Testmandanten belegen").
class RotationResult {
  const RotationResult({
    required this.tenantId,
    required this.oldVersion,
    required this.newVersion,
    required this.reencryptedCounts,
  });

  final String tenantId;
  final int oldVersion;
  final int newVersion;

  /// Anzahl umgeschlüsselter Zeilen je Tabelle.
  final Map<String, int> reencryptedCounts;
}

/// Rotiert den Data Encryption Key (DEK) eines Mandanten: erzeugt eine neue
/// aktive Schlüsselversion und schlüsselt **innerhalb derselben Transaktion**
/// alle Bestandsdaten dieses Mandanten auf die neue Version um. Dadurch
/// existiert zu keinem Zeitpunkt ein inkonsistenter Zustand (aktive Version
/// ohne vollständig umgeschlüsselte Daten) — anders als eine lazy/inkrementelle
/// Rotation, die hier bewusst nicht gewählt wurde (siehe RF1-Auditnotiz).
///
/// `waas_invoice_documents` wird **nicht** umgeschlüsselt — die Tabelle ist
/// per DB-Trigger unveränderlich (GoBD-fest) und lässt kein UPDATE zu. Das
/// ist beabsichtigt (siehe `TenantEncryptionService.decryptImmutableBytesField`),
/// keine Lücke in der Rotation.
class TenantKeyRotationService {
  TenantKeyRotationService(this._pool, this._encryptionService);

  final Pool<void> _pool;
  final TenantEncryptionService _encryptionService;

  Future<RotationResult> rotateTenant(String tenantId) async {
    final active = await _encryptionService.activeKey(tenantId);
    if (active == null) {
      throw StateError('Kein aktiver Verschlüsselungs-Schlüssel für Mandant $tenantId');
    }
    final oldVersion = active.keyVersion;
    final oldCipher = await _encryptionService.cipherForVersion(tenantId, oldVersion);

    return _pool.runTx((tx) async {
      final newCrypto = await _encryptionService.beginRotation(
        tx: tx,
        tenantId: tenantId,
        previousKeyVersion: oldVersion,
      );

      final counts = <String, int>{
        'customers': await _rotateTextFields(
          tx: tx,
          table: 'customers',
          fields: const ['email', 'phone', 'address', 'notes'],
          oldCipher: oldCipher,
          newCrypto: newCrypto,
          tenantId: tenantId,
        ),
        'suppliers': await _rotateTextFields(
          tx: tx,
          table: 'suppliers',
          fields: const ['contact_person', 'email', 'phone', 'address', 'iban', 'notes'],
          oldCipher: oldCipher,
          newCrypto: newCrypto,
          tenantId: tenantId,
        ),
        'tenants': await _rotateTextFields(
          tx: tx,
          table: 'tenants',
          fields: const ['company_address', 'company_tax_id', 'company_iban'],
          oldCipher: oldCipher,
          newCrypto: newCrypto,
          tenantId: tenantId,
          tenantColumn: 'id',
        ),
        'documents': await _rotateBytesFields(
          tx: tx,
          table: 'documents',
          fields: const ['content'],
          oldCipher: oldCipher,
          newCrypto: newCrypto,
          tenantId: tenantId,
        ),
      };

      return RotationResult(
        tenantId: tenantId,
        oldVersion: oldVersion,
        newVersion: newCrypto.keyVersion,
        reencryptedCounts: counts,
      );
    });
  }

  /// Schlüsselt alle TEXT-Felder [fields] einer Tabelle für [tenantId] um.
  /// [idColumn]/[tenantColumn] erlauben Tabellen, bei denen die Mandanten-ID
  /// selbst die Zeilen-ID ist (z. B. `tenants`, wo `id` beides ist).
  Future<int> _rotateTextFields({
    required TxSession tx,
    required String table,
    required List<String> fields,
    required FieldCipher oldCipher,
    required TenantFieldEncryption newCrypto,
    required String tenantId,
    String idColumn = 'id',
    String tenantColumn = 'tenant_id',
  }) async {
    final rows = await tx.execute(
      Sql.named(
        'SELECT $idColumn AS record_id, ${fields.join(', ')} FROM $table '
        'WHERE $tenantColumn = @tenant_id FOR UPDATE',
      ),
      parameters: {'tenant_id': tenantId},
    );

    var count = 0;
    for (final row in rows) {
      final map = row.toColumnMap();
      final recordId = map['record_id'] as String;
      final updates = <String, dynamic>{};
      var hasEncryptedValue = false;
      for (final field in fields) {
        final oldValue = map[field] as String?;
        if (oldValue == null) {
          updates[field] = null;
          continue;
        }
        hasEncryptedValue = true;
        final plaintext = oldCipher.decrypt(
          oldValue,
          aad: AadBuilder.field(tenantId: tenantId, table: table, recordId: recordId, field: field),
        );
        updates[field] = newCrypto.encryptField(
          table: table,
          recordId: recordId,
          field: field,
          value: plaintext,
        );
      }
      if (!hasEncryptedValue) continue; // Zeile ohne Klartext in diesen Feldern — nichts umzuschlüsseln.

      final setClause = fields.map((f) => '$f = @$f').join(', ');
      await tx.execute(
        Sql.named('UPDATE $table SET $setClause WHERE $idColumn = @record_id'),
        parameters: {...updates, 'record_id': recordId},
      );
      count++;
    }
    return count;
  }

  Future<int> _rotateBytesFields({
    required TxSession tx,
    required String table,
    required List<String> fields,
    required FieldCipher oldCipher,
    required TenantFieldEncryption newCrypto,
    required String tenantId,
    String idColumn = 'id',
    String tenantColumn = 'tenant_id',
  }) async {
    final rows = await tx.execute(
      Sql.named(
        'SELECT $idColumn AS record_id, ${fields.join(', ')} FROM $table '
        'WHERE $tenantColumn = @tenant_id FOR UPDATE',
      ),
      parameters: {'tenant_id': tenantId},
    );

    var count = 0;
    for (final row in rows) {
      final map = row.toColumnMap();
      final recordId = map['record_id'] as String;
      final updates = <String, dynamic>{};
      var hasEncryptedValue = false;
      for (final field in fields) {
        final oldValue = map[field] as Uint8List?;
        if (oldValue == null) {
          updates[field] = null;
          continue;
        }
        hasEncryptedValue = true;
        final plaintext = oldCipher.decryptBytes(
          oldValue,
          aad: AadBuilder.field(tenantId: tenantId, table: table, recordId: recordId, field: field),
        );
        updates[field] = newCrypto.encryptBytesField(
          table: table,
          recordId: recordId,
          field: field,
          value: Uint8List.fromList(plaintext),
        );
      }
      if (!hasEncryptedValue) continue;

      final setClause = fields.map((f) => '$f = @$f').join(', ');
      await tx.execute(
        Sql.named('UPDATE $table SET $setClause WHERE $idColumn = @record_id'),
        parameters: {...updates, 'record_id': recordId},
      );
      count++;
    }
    return count;
  }
}
