import 'package:backend/src/authorization_service.dart';
import 'package:backend/src/auth_service.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';
import '../routes/api/waas/customers/[id]/mandate.dart' as mandate;
import '../routes/api/waas/invoices/[id]/submit-payment.dart' as submit;
import '../routes/api/waas/psp/webhooks/[id].dart' as webhook;

class _Context extends Mock implements RequestContext {}

class _Request extends Mock implements Request {}

class _Auth extends Mock implements AuthService {}

class _Authz extends Mock implements AuthorizationService {}

void main() {
  test(
    'owner gate rejects unauthenticated and customer tokens before PSP access',
    () async {
      final c = _Context(), r = _Request(), a = _Auth(), authz = _Authz();
      when(() => c.request).thenReturn(r);
      when(() => r.method).thenReturn(HttpMethod.post);
      when(() => r.headers).thenReturn({});
      when(() => c.read<AuthService>()).thenReturn(a);
      when(() => c.read<AuthorizationService>()).thenReturn(authz);
      // 'customer': kein user_tenant_access-Eintrag für Kundenportal-Konten
      // -> loadContext liefert null (deny-by-default), kein DB-Zugriff nötig.
      when(() => authz.loadContext(userId: any(named: 'userId'), tenantId: any(named: 'tenantId')))
          .thenAnswer((_) async => null);
      expect((await mandate.onRequest(c, 'customer')).statusCode, 401);
      expect((await submit.onRequest(c, 'invoice')).statusCode, 401);
      when(() => r.headers).thenReturn({'Authorization': 'Bearer test'});
      when(() => a.verifyToken('test')).thenReturn(
        AuthTokenPayload(
          userId: 'x',
          tenantId: 'tenant',
          email: 'test@example.invalid',
          role: 'customer',
          expiresAt: DateTime.utc(2099),
        ),
      );
      expect((await mandate.onRequest(c, 'customer')).statusCode, 403);
      expect((await submit.onRequest(c, 'invoice')).statusCode, 403);
    },
  );
  test('webhook requires signature and does not require tenant JWT', () async {
    final c = _Context(), r = _Request();
    when(() => c.request).thenReturn(r);
    when(() => r.method).thenReturn(HttpMethod.post);
    when(() => r.headers).thenReturn({});
    expect((await webhook.onRequest(c, 'merchant')).statusCode, 401);
  });
}
