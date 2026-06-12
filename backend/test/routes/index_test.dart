import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  group('GET /', () {
    test('responds with a 200 health-check JSON.', () {
      final context = _MockRequestContext();
      final response = route.onRequest(context);
      expect(response.statusCode, equals(HttpStatus.ok));
      expect(
        response.json(),
        completion(equals({'service': 'saasERP backend', 'status': 'ok'})),
      );
    });
  });
}
