import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'config.dart';
import 'repositories/tenant_encryption_key_repository.dart';

/// Envelope-Encryption pro Mandant: jeder Mandant erhält einen eigenen,
/// versionierten Data Encryption Key (DEK), der mit einem globalen
/// Master-Key (`ENCRYPTION_MASTER_KEY`, der KEK) AEAD-verschlüsselt
/// gespeichert wird. Der Master-Key lebt ausschließlich in der
/// Prozessumgebung (nicht in der Datenbank/im DB-Backup) — siehe RF1 in
/// `10_Projects/saasERP/Roadmap.md`.
///
/// Unterstützt Schlüsselrotation: `rotateTenant` legt eine neue aktive
/// DEK-Version an; `TenantKeyRotationService` schreibt daraufhin alle
/// verschlüsselten Bestandsdaten des Mandanten auf die neue Version um.
class TenantEncryptionService {
  TenantEncryptionService(AppConfig config, this._repository)
      : _masterCipher = FieldCipher(sha256.convert(utf8.encode(config.encryptionMasterKey)).bytes);

  final TenantEncryptionKeyRepository _repository;
  final FieldCipher _masterCipher;

  static const _initialKeyVersion = 1;

  /// Erzeugt die erste DEK-Version für den Mandanten. Wird bei der
  /// Registrierung aufgerufen.
  Future<void> provisionTenant(String tenantId) async {
    final dek = FieldCipher.generateKey();
    final wrapped = _wrap(tenantId, _initialKeyVersion, dek);
    await _repository.create(
      tenantId: tenantId,
      keyVersion: _initialKeyVersion,
      wrappedKey: wrapped,
    );
  }

  /// Liefert einen [TenantFieldEncryption]-Wrapper mit der aktuell aktiven
  /// Schlüsselversion des Mandanten — der normale Weg für Repositories, um
  /// Felder zu ver-/entschlüsseln.
  Future<TenantFieldEncryption> forTenant(String tenantId) async {
    final active = await _repository.findActive(tenantId);
    if (active == null) {
      throw StateError('Kein aktiver Verschlüsselungs-Schlüssel für Mandant $tenantId');
    }
    final dek = _unwrap(tenantId, active.keyVersion, active.wrappedKey);
    return TenantFieldEncryption._(tenantId, FieldCipher(dek), active.keyVersion);
  }

  /// Cipher für eine bestimmte (ggf. retired) Schlüsselversion — nur für die
  /// Rotation (Umschlüsseln alter Bestandsdaten), nicht für den normalen
  /// Lesepfad der Repositories.
  Future<FieldCipher> cipherForVersion(String tenantId, int keyVersion) async {
    final row = await _repository.find(tenantId, keyVersion);
    if (row == null) {
      throw StateError('Schlüsselversion $keyVersion für Mandant $tenantId nicht gefunden');
    }
    final dek = _unwrap(tenantId, row.keyVersion, row.wrappedKey);
    return FieldCipher(dek);
  }

  /// Entschlüsselt ein Byte-Feld unabhängig davon, ob es mit der aktiven
  /// oder einer älteren (retired) Schlüsselversion verschlüsselt wurde —
  /// für Tabellen, die eine Rotation prinzipiell **nicht** umschlüsseln kann
  /// (z. B. `waas_invoice_documents`: per DB-Trigger unveränderlich/
  /// GoBD-fest). Im Gegensatz zu [TenantFieldEncryption.decryptBytesField]
  /// also bewusst **kein** [StaleKeyVersionException] bei abweichender
  /// Version — das ist hier der erwartete Normalfall nach einer Rotation,
  /// kein Hinweis auf eine Rotations-Lücke.
  Future<Uint8List?> decryptImmutableBytesField({
    required String tenantId,
    required String table,
    required String recordId,
    required String field,
    required Uint8List? value,
  }) async {
    if (value == null) return null;
    final version = FieldCipher.keyVersionOfBytes(value);
    final cipher = await cipherForVersion(tenantId, version);
    return cipher.decryptBytes(
      value,
      aad: AadBuilder.field(tenantId: tenantId, table: table, recordId: recordId, field: field),
    );
  }

  /// Erzeugt eine neue DEK-Version und aktiviert sie innerhalb derselben
  /// Transaktion [tx] (zusammen mit dem Umschlüsseln der Bestandsdaten,
  /// siehe `TenantKeyRotationService` — niemals isoliert aufrufen, sonst
  /// existiert kurzzeitig eine aktive Version ohne umgeschlüsselte Daten).
  Future<TenantFieldEncryption> beginRotation({
    required TxSession tx,
    required String tenantId,
    required int previousKeyVersion,
  }) async {
    final newVersion = previousKeyVersion + 1;
    final dek = FieldCipher.generateKey();
    final wrapped = _wrap(tenantId, newVersion, dek);
    await _repository.activateNewVersion(
      tx: tx,
      tenantId: tenantId,
      newKeyVersion: newVersion,
      wrappedKey: wrapped,
    );
    return TenantFieldEncryption._(tenantId, FieldCipher(dek), newVersion);
  }

  Future<TenantEncryptionKeyRow?> activeKey(String tenantId) => _repository.findActive(tenantId);

  Future<List<TenantEncryptionKeyRow>> listKeyVersions(String tenantId) =>
      _repository.listVersions(tenantId);

  String _wrap(String tenantId, int keyVersion, List<int> dek) => _masterCipher.encrypt(
        base64Encode(dek),
        aad: AadBuilder.tenantDek(tenantId: tenantId, keyVersion: keyVersion),
        keyVersion: keyVersion,
      );

  Uint8List _unwrap(String tenantId, int keyVersion, String wrappedKey) => Uint8List.fromList(
        base64Decode(
          _masterCipher.decrypt(
            wrappedKey,
            aad: AadBuilder.tenantDek(tenantId: tenantId, keyVersion: keyVersion),
          ),
        ),
      );
}

/// Wird geworfen, wenn ein gelesener Ciphertext eine andere Schlüsselversion
/// trägt als die aktuell aktive — im Normalbetrieb ein Zeichen, dass eine
/// Rotation diese Zeile/Tabelle nicht (vollständig) umgeschlüsselt hat.
class StaleKeyVersionException implements Exception {
  StaleKeyVersionException(this.table, this.field, this.foundVersion, this.activeVersion);

  final String table;
  final String field;
  final int foundVersion;
  final int activeVersion;

  @override
  String toString() => 'StaleKeyVersionException: $table.$field ist noch mit Schlüsselversion '
      '$foundVersion verschlüsselt, aktiv ist Version $activeVersion — '
      'Rotation für diese Tabelle hat diese Zeile nicht erfasst.';
}

/// Komfort-Wrapper für Repositories: kapselt Mandant + aktive
/// Schlüsselversion und bindet die AAD automatisch anhand von
/// Tabelle/Datensatz-ID/Feldname (siehe [AadBuilder]).
///
/// Entschlüsselt bewusst **nur** mit der aktiven Version (synchron, kein
/// Datenbank-Rückruf pro Zeile) — nach einer abgeschlossenen Rotation sind
/// alle Zeilen auf die neue Version umgeschlüsselt; eine abweichende
/// Version im Ciphertext ist dann ein Fehlerzustand ([StaleKeyVersionException]),
/// keine normale Alterungs-Situation, die stillschweigend aufgelöst werden
/// sollte.
class TenantFieldEncryption {
  TenantFieldEncryption._(this.tenantId, this._cipher, this.keyVersion);

  final String tenantId;
  final FieldCipher _cipher;
  final int keyVersion;

  String? encryptField({
    required String table,
    required String recordId,
    required String field,
    required String? value,
  }) {
    if (value == null || value.isEmpty) return null;
    return _cipher.encrypt(
      value,
      aad: AadBuilder.field(tenantId: tenantId, table: table, recordId: recordId, field: field),
      keyVersion: keyVersion,
    );
  }

  String? decryptField({
    required String table,
    required String recordId,
    required String field,
    required String? value,
  }) {
    if (value == null) return null;
    final foundVersion = FieldCipher.keyVersionOf(value);
    if (foundVersion != keyVersion) {
      throw StaleKeyVersionException(table, field, foundVersion, keyVersion);
    }
    return _cipher.decrypt(
      value,
      aad: AadBuilder.field(tenantId: tenantId, table: table, recordId: recordId, field: field),
    );
  }

  Uint8List? encryptBytesField({
    required String table,
    required String recordId,
    required String field,
    required Uint8List? value,
  }) {
    if (value == null) return null;
    return _cipher.encryptBytes(
      value,
      aad: AadBuilder.field(tenantId: tenantId, table: table, recordId: recordId, field: field),
      keyVersion: keyVersion,
    );
  }

  Uint8List? decryptBytesField({
    required String table,
    required String recordId,
    required String field,
    required Uint8List? value,
  }) {
    if (value == null) return null;
    final foundVersion = FieldCipher.keyVersionOfBytes(value);
    if (foundVersion != keyVersion) {
      throw StaleKeyVersionException(table, field, foundVersion, keyVersion);
    }
    return _cipher.decryptBytes(
      value,
      aad: AadBuilder.field(tenantId: tenantId, table: table, recordId: recordId, field: field),
    );
  }
}
