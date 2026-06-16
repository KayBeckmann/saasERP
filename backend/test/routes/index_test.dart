import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../../routes/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockPool extends Mock implements Pool<void> {}

class _MockResult extends Mock implements Result {}

class _MockResultRow extends Mock implements ResultRow {}

void main() {
  group('GET /', () {
    test('responds with a 200 health-check JSON when DB is reachable.', () async {
      final context = _MockRequestContext();
      final pool = _MockPool();
      final resultRow = _MockResultRow();
      final result = _MockResult();

      when(() => result.isEmpty).thenReturn(false);
      when(() => result.iterator).thenReturn([resultRow].iterator);
      when(() => pool.execute(any())).thenAnswer((_) async => result);
      when(() => context.read<Pool<void>>()).thenReturn(pool);

      final response = await route.onRequest(context);
      expect(response.statusCode, equals(HttpStatus.ok));

      final body = await response.json() as Map<String, dynamic>;
      expect(body['service'], equals('saasERP backend'));
      expect(body['status'], equals('ok'));
      expect(body['db'], equals('ok'));
      expect(body.containsKey('timestamp'), isTrue);
    });
  });
}
