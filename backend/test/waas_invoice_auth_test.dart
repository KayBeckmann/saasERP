import 'package:backend/src/authorization_service.dart';
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

class _Authz extends Mock implements AuthorizationService {}

void main() {
  test(
    'WaaS mutations reject customer and a permission-less "Nur Lesen" role before touching the DB',
    () async {
      final context = _Context();
      final request = _Request();
      final auth = _Auth();
      final authz = _Authz();
      when(() => context.request).thenReturn(request);
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.headers).thenReturn({'Authorization': 'Bearer test'});
      when(() => context.read<AuthService>()).thenReturn(auth);
      when(() => context.read<AuthorizationService>()).thenReturn(authz);
      // 'customer': kein user_tenant_access-Eintrag existiert für
      // Kundenportal-Konten -> loadContext liefert null (deny-by-default).
      // 'Nur Lesen': echte Rolle ohne waas-Berechtigungen.
      for (final (role, authzContext) in [
        ('customer', null),
        (
          'Nur Lesen',
          const AuthorizationContext(
            userId: 'user',
            tenantId: 'tenant',
            roleId: 'role-nur-lesen',
            roleName: 'Nur Lesen',
            isAdminRole: false,
            permissions: {'waas:view'},
          ),
        ),
      ]) {
        when(() => auth.verifyToken('test')).thenReturn(
          AuthTokenPayload(
            userId: 'user',
            tenantId: 'tenant',
            email: 'user@example.test',
            role: role,
            expiresAt: DateTime.utc(2099),
          ),
        );
        when(() => authz.loadContext(userId: any(named: 'userId'), tenantId: any(named: 'tenantId')))
            .thenAnswer((_) async => authzContext);
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
