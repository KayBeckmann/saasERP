import 'package:backend/src/authorization_service.dart';
import 'package:backend/src/auth_service.dart';
import 'package:backend/src/repositories/waas_intake_repository.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';
import '../routes/api/waas/intake/index.dart' as intake;
import '../routes/api/waas/intake/[id]/associate.dart' as associate;
import '../routes/api/waas/intake/[id]/review.dart' as review;
import '../routes/api/waas/intake/[id]/attachment.dart' as attachment;
import '../routes/api/waas/intake/[id]/raw.dart' as raw;

class _Context extends Mock implements RequestContext {}

class _Request extends Mock implements Request {}

class _Auth extends Mock implements AuthService {}

class _Authz extends Mock implements AuthorizationService {}

class _Repo extends Mock implements WaasIntakeRepository {}

void main() {
  test('admin can read serializable queue metadata', () async {
    final c = _Context(), r = _Request(), a = _Auth(), authz = _Authz(), repo = _Repo();
    when(() => c.request).thenReturn(r);
    when(() => r.method).thenReturn(HttpMethod.get);
    when(() => r.headers).thenReturn({'Authorization': 'Bearer test'});
    when(() => c.read<AuthService>()).thenReturn(a);
    when(() => c.read<AuthorizationService>()).thenReturn(authz);
    when(() => a.verifyToken('test')).thenReturn(
      AuthTokenPayload(
        userId: 'x',
        tenantId: 'tenant',
        email: 'a@b.invalid',
        role: 'Admin',
        expiresAt: DateTime.utc(2099),
      ),
    );
    when(() => authz.loadContext(userId: any(named: 'userId'), tenantId: any(named: 'tenantId')))
        .thenAnswer(
      (_) async => const AuthorizationContext(
        userId: 'x',
        tenantId: 'tenant',
        roleId: 'role-admin',
        roleName: 'Admin',
        isAdminRole: true,
        permissions: {},
      ),
    );
    when(() => c.read<WaasIntakeRepository>()).thenReturn(repo);
    when(() => repo.list(tenantId: 'tenant')).thenAnswer(
      (_) async => [
        {'id': 'a', 'created_at': DateTime.utc(2026)},
      ],
    );
    final response = await intake.onRequest(c);
    expect(response.statusCode, 200);
    expect(await response.body(), contains('2026-01-01'));
  });
  test(
    'email intake routes refuse unauthenticated, customer and non-admin staff tokens before accessing storage',
    () async {
      final c = _Context(), r = _Request(), a = _Auth(), authz = _Authz();
      when(() => c.request).thenReturn(r);
      when(() => r.method).thenReturn(HttpMethod.get);
      when(() => r.headers).thenReturn({});
      when(() => c.read<AuthService>()).thenReturn(a);
      when(() => c.read<AuthorizationService>()).thenReturn(authz);
      expect((await intake.onRequest(c)).statusCode, 401);
      expect((await attachment.onRequest(c, 'id')).statusCode, 401);
      expect((await raw.onRequest(c, 'id')).statusCode, 401);
      when(() => r.method).thenReturn(HttpMethod.post);
      expect((await associate.onRequest(c, 'id')).statusCode, 401);
      expect((await review.onRequest(c, 'id')).statusCode, 401);
      when(() => r.headers).thenReturn({'Authorization': 'Bearer test'});
      when(() => a.verifyToken('test')).thenReturn(
        AuthTokenPayload(
          userId: 'x',
          tenantId: 'tenant',
          email: 'a@b.invalid',
          role: 'customer',
          expiresAt: DateTime.utc(2099),
        ),
      );
      // 'customer': kein user_tenant_access-Eintrag für Kundenportal-Konten
      // -> loadContext liefert null (deny-by-default).
      when(() => authz.loadContext(userId: any(named: 'userId'), tenantId: any(named: 'tenantId')))
          .thenAnswer((_) async => null);
      expect((await intake.onRequest(c)).statusCode, 403);
      expect((await associate.onRequest(c, 'id')).statusCode, 403);
      expect((await review.onRequest(c, 'id')).statusCode, 403);
      when(() => r.method).thenReturn(HttpMethod.get);
      expect((await attachment.onRequest(c, 'id')).statusCode, 403);
      expect((await raw.onRequest(c, 'id')).statusCode, 403);
      // Echte Mandanten-Rolle ohne Admin-Status ('Nur Lesen' mit waas:view):
      // Intake bleibt trotz vorhandener waas-Berechtigung Admin-exklusiv.
      when(() => a.verifyToken('test')).thenReturn(
        AuthTokenPayload(
          userId: 'x',
          tenantId: 'tenant',
          email: 'a@b.invalid',
          role: 'Nur Lesen',
          expiresAt: DateTime.utc(2099),
        ),
      );
      when(() => authz.loadContext(userId: any(named: 'userId'), tenantId: any(named: 'tenantId')))
          .thenAnswer(
        (_) async => const AuthorizationContext(
          userId: 'x',
          tenantId: 'tenant',
          roleId: 'role-nur-lesen',
          roleName: 'Nur Lesen',
          isAdminRole: false,
          permissions: {'waas:view'},
        ),
      );
      expect((await attachment.onRequest(c, 'id')).statusCode, 403);
      expect((await raw.onRequest(c, 'id')).statusCode, 403);
      when(() => r.method).thenReturn(HttpMethod.post);
      expect((await associate.onRequest(c, 'id')).statusCode, 403);
      expect((await review.onRequest(c, 'id')).statusCode, 403);
    },
  );
}
