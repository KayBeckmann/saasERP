import 'package:backend/src/auth_service.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';

import '../routes/api/invoices/_middleware.dart' as invoices;
import '../routes/api/waas/contracts/[id]/plan.dart' as plan;
import '../routes/api/waas/contracts/[id]/run.dart' as run;
import '../routes/api/waas/invoices/[id]/approve.dart' as approve;
import '../routes/api/customer-portal/invoices/[id]/xml.dart' as portalXml;

class _Context extends Mock implements RequestContext {}

class _Request extends Mock implements Request {}

class _Auth extends Mock implements AuthService {}

void main() {
  test(
    'WaaS mutations reject customer and employee roles before touching the DB',
    () async {
      final context = _Context();
      final request = _Request();
      final auth = _Auth();
      when(() => context.request).thenReturn(request);
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.headers).thenReturn({'Authorization': 'Bearer test'});
      when(() => context.read<AuthService>()).thenReturn(auth);
      for (final role in ['customer', UserRole.employee.toJson()]) {
        when(() => auth.verifyToken('test')).thenReturn(
          AuthTokenPayload(
            userId: 'user',
            tenantId: 'tenant',
            email: 'user@example.test',
            role: role,
            expiresAt: DateTime.utc(2099),
          ),
        );
        expect((await plan.onRequest(context, 'contract')).statusCode, 403);
        expect((await run.onRequest(context, 'contract')).statusCode, 403);
        expect((await approve.onRequest(context, 'invoice')).statusCode, 403);
      }
    },
  );

  test(
    'portal XML rejects unauthenticated and staff tokens before database access',
    () async {
      final context = _Context();
      final request = _Request();
      final auth = _Auth();
      when(() => context.request).thenReturn(request);
      when(() => request.method).thenReturn(HttpMethod.get);
      when(() => request.headers).thenReturn({});
      when(() => context.read<AuthService>()).thenReturn(auth);
      expect((await portalXml.onRequest(context, 'invoice')).statusCode, 401);
      when(() => request.headers).thenReturn({'Authorization': 'Bearer test'});
      when(() => auth.verifyToken('test')).thenReturn(
        AuthTokenPayload(
          userId: 'owner',
          tenantId: 'tenant',
          email: 'owner@example.test',
          role: UserRole.owner.toJson(),
          expiresAt: DateTime.utc(2099),
        ),
      );
      expect((await portalXml.onRequest(context, 'invoice')).statusCode, 401);
    },
  );

  test(
    'customer JWT cannot enter generic invoice list, PDF, XML or mutation routes',
    () async {
      final context = _Context();
      final request = _Request();
      final auth = _Auth();
      when(() => context.request).thenReturn(request);
      when(() => request.headers).thenReturn({'Authorization': 'Bearer test'});
      when(() => context.read<AuthService>()).thenReturn(auth);
      when(() => auth.verifyToken('test')).thenReturn(
        AuthTokenPayload(
          userId: 'customer',
          tenantId: 'tenant',
          email: 'customer@example.test',
          role: 'customer',
          expiresAt: DateTime.utc(2099),
        ),
      );
      var called = false;
      final handler = invoices.middleware((_) async {
        called = true;
        return Response();
      });
      final response = await handler(context);
      expect(response.statusCode, 403);
      expect(called, isFalse);
      when(() => auth.verifyToken('test')).thenReturn(
        AuthTokenPayload(
          userId: 'owner',
          tenantId: 'tenant',
          email: 'owner@example.test',
          role: UserRole.owner.toJson(),
          expiresAt: DateTime.utc(2099),
        ),
      );
      expect((await handler(context)).statusCode, 200);
      expect(called, isTrue);
    },
  );
}
