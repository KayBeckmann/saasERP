import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// Symmetrische Verschlüsselung einzelner Feldwerte (AES-256-CBC).
///
/// Jeder Mandant erhält im Backend einen eigenen 256-Bit-Schlüssel
/// (`TenantEncryptionService`) — Daten verschiedener Mandanten sind dadurch
/// getrennt verschlüsselt, auch bei Kompromittierung eines einzelnen
/// Schlüssels.
class FieldCipher {
  FieldCipher(List<int> key32)
      : _encrypter = Encrypter(AES(Key(Uint8List.fromList(key32)), mode: AESMode.cbc));

  final Encrypter _encrypter;

  /// Erzeugt einen neuen zufälligen 256-Bit-Schlüssel.
  static List<int> generateKey() => Key.fromSecureRandom(32).bytes;

  /// Verschlüsselt [plaintext]. Format: `"<iv_base64>:<cipher_base64>"`.
  String encrypt(String plaintext) {
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Entschlüsselt einen mit [encrypt] erzeugten String.
  String decrypt(String ciphertext) {
    final parts = ciphertext.split(':');
    if (parts.length != 2) {
      throw const FormatException('Ungültiges Ciphertext-Format');
    }
    final iv = IV.fromBase64(parts[0]);
    final encrypted = Encrypted.fromBase64(parts[1]);
    return _encrypter.decrypt(encrypted, iv: iv);
  }
}
