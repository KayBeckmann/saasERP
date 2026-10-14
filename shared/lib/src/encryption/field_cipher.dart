import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;

/// Wird geworfen, wenn eine Entschlüsselung fehlschlägt — falscher Schlüssel,
/// manipulierter Ciphertext oder falsche AAD (z. B. Ciphertext eines anderen
/// Datensatzes/Feldes untergeschoben). AEAD garantiert: Entschlüsselung
/// gelingt nur, wenn Schlüssel UND die bei [FieldCipher.encrypt] übergebene
/// `aad` exakt übereinstimmen.
class FieldDecryptionException implements Exception {
  FieldDecryptionException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'FieldDecryptionException: $message'
      '${cause != null ? ' (Ursache: $cause)' : ''}';
}

/// Authentifizierte Feldverschlüsselung (AES-256-GCM, siehe RF1 in
/// `10_Projects/saasERP/Roadmap.md`).
///
/// Ersetzt die frühere AES-256-CBC-Implementierung: CBC ohne Auth-Tag bietet
/// keine Integrität (Bit-Flipping/Padding-Oracle-Angriffe möglich). GCM ist
/// ein AEAD-Modus — jede Entschlüsselung prüft Authentizität und Integrität
/// mit; ein manipulierter oder falsch zugeordneter Ciphertext wird zuverlässig
/// abgelehnt statt (wie bei CBC) still fehlerhaften Klartext zu liefern.
///
/// Jeder verschlüsselte Wert ist zusätzlich an **Additional Authenticated
/// Data** (AAD) gebunden — typischerweise `tenant_id|table|record_id|field`
/// (siehe [AadBuilder]). Damit kann ein Ciphertext niemals in einen anderen
/// Datensatz/Feld/Mandanten "umgehängt" werden, selbst wenn der Angreifer
/// Lese-/Schreibzugriff auf die Datenbank hat: die AAD-Prüfung schlägt fehl.
///
/// Format (String): `v2:<key_version>:<nonce_base64>:<ciphertext+tag_base64>`
/// Format (Bytes): `[0x02, key_version als 4 Byte big-endian, nonce(12), ciphertext+tag]`
class FieldCipher {
  FieldCipher(List<int> key32)
      : assert(key32.length == 32, 'AES-256 benötigt einen 32-Byte-Schlüssel'),
        _encrypter = enc.Encrypter(
          enc.AES(enc.Key(Uint8List.fromList(key32)), mode: enc.AESMode.gcm),
        );

  final enc.Encrypter _encrypter;

  static const _formatVersion = 'v2';
  static const _nonceBytes = 12;
  static const _binaryFormatByte = 0x02;

  /// Erzeugt einen neuen zufälligen 256-Bit-Schlüssel.
  static List<int> generateKey() => enc.Key.fromSecureRandom(32).bytes;

  /// Verschlüsselt [plaintext]. [aad] muss bei [decrypt] identisch übergeben
  /// werden (siehe [AadBuilder.field]). [keyVersion] wird im Ciphertext
  /// mitgespeichert, damit beim Lesen die passende (ggf. ältere, nach einer
  /// Rotation retired) Schlüsselversion ermittelt werden kann.
  String encrypt(String plaintext, {required String aad, int keyVersion = 1}) {
    final iv = enc.IV.fromSecureRandom(_nonceBytes);
    final encrypted = _encrypter.encrypt(
      plaintext,
      iv: iv,
      associatedData: Uint8List.fromList(utf8.encode(aad)),
    );
    return '$_formatVersion:$keyVersion:${iv.base64}:${encrypted.base64}';
  }

  /// Entschlüsselt einen mit [encrypt] erzeugten String. Wirft
  /// [FieldDecryptionException], wenn Schlüssel, [aad] oder Ciphertext nicht
  /// zusammenpassen (inkl. jeder Manipulation).
  String decrypt(String ciphertext, {required String aad}) {
    final parts = ciphertext.split(':');
    if (parts.length != 4 || parts[0] != _formatVersion) {
      throw FieldDecryptionException(
        'Unbekanntes oder veraltetes Ciphertext-Format (erwartet "$_formatVersion:...")',
      );
    }
    final iv = enc.IV.fromBase64(parts[2]);
    final encrypted = enc.Encrypted.fromBase64(parts[3]);
    try {
      return _encrypter.decrypt(
        encrypted,
        iv: iv,
        associatedData: Uint8List.fromList(utf8.encode(aad)),
      );
    } catch (e) {
      throw FieldDecryptionException(
        'Entschlüsselung fehlgeschlagen — falscher Schlüssel, falsche AAD oder manipulierter Ciphertext',
        e,
      );
    }
  }

  /// Liest die im Ciphertext (siehe [encrypt]) gespeicherte Schlüsselversion,
  /// ohne zu entschlüsseln — wird genutzt, um vor dem eigentlichen Decrypt
  /// die passende (ggf. retired) Tenant-Schlüsselversion nachzuschlagen.
  static int keyVersionOf(String ciphertext) {
    final parts = ciphertext.split(':');
    if (parts.length != 4 || parts[0] != _formatVersion) {
      throw FieldDecryptionException(
        'Unbekanntes oder veraltetes Ciphertext-Format (erwartet "$_formatVersion:...")',
      );
    }
    final version = int.tryParse(parts[1]);
    if (version == null) {
      throw FieldDecryptionException('Ungültige Schlüsselversion im Ciphertext');
    }
    return version;
  }

  /// Binäre Variante für BYTEA-Spalten (z. B. Dokumenteninhalte) — kein
  /// Base64-Overhead, das Ergebnis wird direkt in der BYTEA-Spalte abgelegt.
  Uint8List encryptBytes(List<int> plaintext, {required String aad, int keyVersion = 1}) {
    final iv = enc.IV.fromSecureRandom(_nonceBytes);
    final encrypted = _encrypter.encryptBytes(
      plaintext,
      iv: iv,
      associatedData: Uint8List.fromList(utf8.encode(aad)),
    );
    final versionBytes = ByteData(4)..setUint32(0, keyVersion, Endian.big);
    return Uint8List.fromList([
      _binaryFormatByte,
      ...versionBytes.buffer.asUint8List(),
      ...iv.bytes,
      ...encrypted.bytes,
    ]);
  }

  /// Entschlüsselt einen mit [encryptBytes] erzeugten Byte-String.
  Uint8List decryptBytes(List<int> data, {required String aad}) {
    const headerLength = 1 + 4 + _nonceBytes;
    if (data.length <= headerLength || data[0] != _binaryFormatByte) {
      throw FieldDecryptionException('Unbekanntes oder veraltetes Binär-Ciphertext-Format');
    }
    final iv = enc.IV(Uint8List.fromList(data.sublist(5, headerLength)));
    final cipherBytes = data.sublist(headerLength);
    try {
      final decrypted = _encrypter.decryptBytes(
        enc.Encrypted(Uint8List.fromList(cipherBytes)),
        iv: iv,
        associatedData: Uint8List.fromList(utf8.encode(aad)),
      );
      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw FieldDecryptionException(
        'Entschlüsselung fehlgeschlagen — falscher Schlüssel, falsche AAD oder manipulierter Ciphertext',
        e,
      );
    }
  }

  /// Liest die im Binär-Ciphertext gespeicherte Schlüsselversion.
  static int keyVersionOfBytes(List<int> data) {
    const headerLength = 1 + 4 + _nonceBytes;
    if (data.length <= headerLength || data[0] != _binaryFormatByte) {
      throw FieldDecryptionException('Unbekanntes oder veraltetes Binär-Ciphertext-Format');
    }
    final versionBytes = Uint8List.fromList(data.sublist(1, 5));
    return ByteData.sublistView(versionBytes).getUint32(0, Endian.big);
  }
}

/// Baut die kanonische AAD-Zeichenkette für Feldverschlüsselung —
/// `tenant_id|table|record_id|field`. Immer dieselbe Konstruktion auf
/// Schreib- und Leseseite verwenden, sonst schlägt die Entschlüsselung
/// (gewollt) fehl. `record_id` muss daher VOR dem Verschlüsseln feststehen
/// (siehe `IdGenerator`/`package:uuid` in den Repositories — nicht erst die
/// von Postgres per `DEFAULT gen_random_uuid()` erzeugte ID abwarten).
class AadBuilder {
  const AadBuilder._();

  static String field({
    required String tenantId,
    required String table,
    required String recordId,
    required String field,
  }) =>
      '$tenantId|$table|$recordId|$field';

  /// AAD für das Wrapping eines Tenant-DEK unter dem Master-Key (KEK) —
  /// bindet den gewrappten Schlüssel an Mandant und Version, damit ein
  /// gewrappter DEK nicht einem anderen Mandanten oder einer anderen
  /// Version untergeschoben werden kann.
  static String tenantDek({required String tenantId, required int keyVersion}) =>
      'tenant_dek|$tenantId|v$keyVersion';
}
