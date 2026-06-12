import 'package:backend/src/repositories/tenant_access_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/me/tenants — Mandanten, auf die der eingeloggte Nutzer Zugriff
/// hat. Grundlage für die Mandanten-/Tenant-Auswahl bei Nutzern mit
/// mehreren Zugängen (z. B. Berater).
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final tenantAccessRepository = context.read<TenantAccessRepository>();
  final tenants = await tenantAccessRepository.listForUser(auth.userId);

  return Response.json(
    body: {'tenants': tenants.map((t) => t.toJson()).toList()},
  );
}
