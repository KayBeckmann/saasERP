import 'dart:convert';
import 'package:backend/src/waas_psp.dart';
import 'package:test/test.dart';

void main() {
  test(
    'fake hosted flow and authenticated event require merchant-scoped secret',
    () {
      final fake = FakeWaasPsp({
        'merchant-a': 'test-secret-a',
        'merchant-b': 'test-secret-b',
      });
      final flow = fake.hostedMandate(
        merchantAlias: 'merchant-a',
        requestId: 'request-1',
      );
      expect(flow.url.host, 'sandbox.invalid');
      expect(flow.providerReference, isNotEmpty);
      final raw = utf8.encode(
        jsonEncode({
          'id': 'event-1',
          'merchant': 'merchant-a',
          'type': 'mandate.active',
          'mandate': flow.providerReference,
        }),
      );
      final signed = fake.signForTest(
        'merchant-a',
        raw,
        DateTime.now().toUtc(),
      );
      expect(fake.verify('merchant-a', raw, signed).id, 'event-1');
      expect(
        () => fake.verify('merchant-b', raw, signed),
        throwsFormatException,
      );
      expect(
        () => fake.verify('merchant-a', utf8.encode('{}'), signed),
        throwsFormatException,
      );
      expect(
        () => fake.verify(
          'merchant-a',
          raw,
          fake.signForTest(
            'merchant-a',
            raw,
            DateTime.now().toUtc().subtract(const Duration(minutes: 6)),
          ),
        ),
        throwsFormatException,
      );
    },
  );
}
