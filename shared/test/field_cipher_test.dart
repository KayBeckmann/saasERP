import 'dart:convert';

import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('FieldCipher (AES-256-GCM, AEAD)', () {
    const aad = 'tenant-a|customers|record-1|email';

    test('encrypt() und decrypt() liefern den Klartext zurück', () {
      final cipher = FieldCipher(FieldCipher.generateKey());

      final ciphertext = cipher.encrypt('geheime Daten', aad: aad);

      expect(cipher.decrypt(ciphertext, aad: aad), 'geheime Daten');
    });

    test('leerer Klartext rundet korrekt', () {
      final cipher = FieldCipher(FieldCipher.generateKey());
      final ciphertext = cipher.encrypt('', aad: aad);
      expect(cipher.decrypt(ciphertext, aad: aad), '');
    });

    test('zwei Verschlüsselungen desselben Klartexts ergeben unterschiedliche Ciphertexte (zufälliger Nonce)', () {
      final cipher = FieldCipher(FieldCipher.generateKey());
      final a = cipher.encrypt('geheime Daten', aad: aad);
      final b = cipher.encrypt('geheime Daten', aad: aad);
      expect(a, isNot(equals(b)));
    });

    test('zwei Schlüssel erzeugen unterschiedliche Ciphertexte, fremder Schlüssel kann nicht entschlüsseln', () {
      final cipherA = FieldCipher(FieldCipher.generateKey());
      final cipherB = FieldCipher(FieldCipher.generateKey());

      final ciphertextA = cipherA.encrypt('geheime Daten', aad: aad);
      final ciphertextB = cipherB.encrypt('geheime Daten', aad: aad);

      expect(ciphertextA, isNot(equals(ciphertextB)));
      expect(
        () => cipherB.decrypt(ciphertextA, aad: aad),
        throwsA(isA<FieldDecryptionException>()),
      );
    });

    test('falsche AAD wird abgelehnt (AEAD-Bindung) — verhindert Ciphertext-Umhängen', () {
      final cipher = FieldCipher(FieldCipher.generateKey());
      final ciphertext = cipher.encrypt('geheime Daten', aad: aad);

      expect(
        () => cipher.decrypt(ciphertext, aad: 'tenant-a|customers|record-2|email'),
        throwsA(isA<FieldDecryptionException>()),
      );
    });

    test('manipulierter Ciphertext wird abgelehnt (Integrität/Authentizität)', () {
      final cipher = FieldCipher(FieldCipher.generateKey());
      final ciphertext = cipher.encrypt('geheime Daten', aad: aad);
      final parts = ciphertext.split(':');
      // Letztes Zeichen des Ciphertext-Teils kippen -> Auth-Tag passt nicht mehr.
      final tampered = parts[3].substring(0, parts[3].length - 1) +
          (parts[3][parts[3].length - 1] == 'A' ? 'B' : 'A');
      final tamperedCiphertext = '${parts[0]}:${parts[1]}:${parts[2]}:$tampered';

      expect(
        () => cipher.decrypt(tamperedCiphertext, aad: aad),
        throwsA(isA<FieldDecryptionException>()),
      );
    });

    test('decrypt() wirft bei ungültigem/altem Format (z. B. altes v1-CBC-Format)', () {
      final cipher = FieldCipher(FieldCipher.generateKey());

      expect(
        () => cipher.decrypt('kein-gueltiges-format', aad: aad),
        throwsA(isA<FieldDecryptionException>()),
      );
      expect(
        () => cipher.decrypt('iv-base64:cipher-base64', aad: aad), // altes v1-Format (2 Teile)
        throwsA(isA<FieldDecryptionException>()),
      );
    });

    test('Schlüsselversion wird im Ciphertext mitgeführt und ist auslesbar', () {
      final cipher = FieldCipher(FieldCipher.generateKey());
      final ciphertext = cipher.encrypt('geheime Daten', aad: aad, keyVersion: 3);

      expect(FieldCipher.keyVersionOf(ciphertext), 3);
      expect(cipher.decrypt(ciphertext, aad: aad), 'geheime Daten');
    });

    test('generateKey() liefert 32 Byte (AES-256)', () {
      expect(FieldCipher.generateKey(), hasLength(32));
    });
  });

  group('FieldCipher — binäre Variante (z. B. Dokumenteninhalte)', () {
    const aad = 'tenant-a|documents|doc-1|content';

    test('encryptBytes() und decryptBytes() liefern die Originalbytes zurück', () {
      final cipher = FieldCipher(FieldCipher.generateKey());
      final original = utf8.encode('Binärer Dateiinhalt öäü 🎉');

      final ciphertext = cipher.encryptBytes(original, aad: aad);
      final decrypted = cipher.decryptBytes(ciphertext, aad: aad);

      expect(decrypted, equals(original));
    });

    test('großer Binärinhalt rundet korrekt', () {
      final cipher = FieldCipher(FieldCipher.generateKey());
      final original = List<int>.generate(500000, (i) => i % 256);

      final ciphertext = cipher.encryptBytes(original, aad: aad);
      final decrypted = cipher.decryptBytes(ciphertext, aad: aad);

      expect(decrypted, equals(original));
    });

    test('manipulierter Binär-Ciphertext wird abgelehnt', () {
      final cipher = FieldCipher(FieldCipher.generateKey());
      final ciphertext = cipher.encryptBytes(utf8.encode('Inhalt'), aad: aad);
      final tampered = List<int>.from(ciphertext);
      tampered[tampered.length - 1] ^= 0xFF;

      expect(
        () => cipher.decryptBytes(tampered, aad: aad),
        throwsA(isA<FieldDecryptionException>()),
      );
    });

    test('falsche AAD wird bei Binärdaten abgelehnt', () {
      final cipher = FieldCipher(FieldCipher.generateKey());
      final ciphertext = cipher.encryptBytes(utf8.encode('Inhalt'), aad: aad);

      expect(
        () => cipher.decryptBytes(ciphertext, aad: 'tenant-a|documents|doc-2|content'),
        throwsA(isA<FieldDecryptionException>()),
      );
    });

    test('Schlüsselversion wird im Binär-Ciphertext mitgeführt', () {
      final cipher = FieldCipher(FieldCipher.generateKey());
      final ciphertext = cipher.encryptBytes(utf8.encode('Inhalt'), aad: aad, keyVersion: 7);

      expect(FieldCipher.keyVersionOfBytes(ciphertext), 7);
    });
  });

  group('AadBuilder', () {
    test('field() liefert deterministische, eindeutige Zeichenkette', () {
      final a = AadBuilder.field(tenantId: 't1', table: 'customers', recordId: 'r1', field: 'email');
      final b = AadBuilder.field(tenantId: 't1', table: 'customers', recordId: 'r1', field: 'email');
      final c = AadBuilder.field(tenantId: 't1', table: 'customers', recordId: 'r2', field: 'email');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('tenantDek() bindet Mandant und Schlüsselversion', () {
      final v1 = AadBuilder.tenantDek(tenantId: 't1', keyVersion: 1);
      final v2 = AadBuilder.tenantDek(tenantId: 't1', keyVersion: 2);
      expect(v1, isNot(equals(v2)));
    });
  });
}
