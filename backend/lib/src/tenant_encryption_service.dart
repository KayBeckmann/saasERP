import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'config.dart';
import 'repositories/tenant_encryption_key_repository.dart';

/// Envelope-Encryption pro Mandant: jeder Mandant erhält einen eigenen
/// Data Encryption Key (DEK), der mit einem globalen Master-Key
/// (`ENCRYPTION_MASTER_KEY`) verschlüsselt gespeichert wird. Damit sind die
/// Daten verschiedener Mandanten getrennt verschlüsselt, auch bei
/// Kompromittierung eines einzelnen DEK.
class TenantEncryptionService {
  TenantEncryptionService(AppConfig config, this._repository)
      : _masterCipher = FieldCipher(sha256.convert(utf8.encode(config.encryptionMasterKey)).bytes);

  final TenantEncryptionKeyRepository _repository;
  final FieldCipher _masterCipher;

  /// Erzeugt einen neuen DEK für den Mandanten und speichert ihn
  /// master-key-verschlüsselt. Wird bei der Registrierung aufgerufen.
  Future<void> provisionTenant(String tenantId) async {
    final dek = FieldCipher.generateKey();
    final wrappedKey = _masterCipher.encrypt(base64Encode(dek));
    await _repository.create(tenantId: tenantId, wrappedKey: wrappedKey);
  }

  /// Liefert den für den Mandanten zuständigen [FieldCipher] zur
  /// Ver-/Entschlüsselung einzelner Feldwerte.
  Future<FieldCipher> cipherForTenant(String tenantId) async {
    final wrappedKey = await _repository.findWrappedKey(tenantId);
    if (wrappedKey == null) {
      throw StateError('Kein Verschlüsselungs-Schlüssel für Mandant $tenantId');
    }
    final dek = base64Decode(_masterCipher.decrypt(wrappedKey));
    return FieldCipher(dek);
  }
}
