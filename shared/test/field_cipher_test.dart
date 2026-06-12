import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('FieldCipher', () {
    test('encrypt() und decrypt() liefern den Klartext zurück', () {
      final cipher = FieldCipher(FieldCipher.generateKey());

      final ciphertext = cipher.encrypt('geheime Daten');

      expect(cipher.decrypt(ciphertext), 'geheime Daten');
    });

    test('zwei Schlüssel erzeugen unterschiedliche Ciphertexte', () {
      final cipherA = FieldCipher(FieldCipher.generateKey());
      final cipherB = FieldCipher(FieldCipher.generateKey());

      final ciphertextA = cipherA.encrypt('geheime Daten');
      final ciphertextB = cipherB.encrypt('geheime Daten');

      expect(ciphertextA, isNot(equals(ciphertextB)));
      expect(() => cipherB.decrypt(ciphertextA), throwsA(anything));
    });

    test('decrypt() wirft bei ungültigem Format', () {
      final cipher = FieldCipher(FieldCipher.generateKey());

      expect(() => cipher.decrypt('kein-gueltiges-format'), throwsFormatException);
    });
  });
}
