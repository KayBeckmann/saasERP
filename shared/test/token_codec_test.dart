import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('TokenCodec', () {
    final codec = TokenCodec('test-secret');

    test('issue() und verify() liefern dieselben Claims zurück', () {
      final token = codec.issue(
        userId: 'user-1',
        tenantId: 'tenant-1',
        email: 'owner@example.com',
        role: 'owner',
      );

      final payload = codec.verify(token);

      expect(payload.userId, 'user-1');
      expect(payload.tenantId, 'tenant-1');
      expect(payload.email, 'owner@example.com');
      expect(payload.role, 'owner');
      expect(payload.isExpired, isFalse);
    });

    test('decodeUnverified() liest Claims ohne Secret', () {
      final token = codec.issue(
        userId: 'user-2',
        tenantId: 'tenant-2',
        email: 'employee@example.com',
        role: 'employee',
      );

      final payload = TokenCodec.decodeUnverified(token);

      expect(payload.userId, 'user-2');
      expect(payload.tenantId, 'tenant-2');
      expect(payload.isExpired, isFalse);
    });

    test('verify() wirft bei abgelaufenem Token', () {
      final token = codec.issue(
        userId: 'user-3',
        tenantId: 'tenant-3',
        email: 'expired@example.com',
        role: 'owner',
        validFor: const Duration(seconds: -1),
      );

      expect(() => codec.verify(token), throwsA(isA<JWTExpiredException>()));
    });
  });
}
