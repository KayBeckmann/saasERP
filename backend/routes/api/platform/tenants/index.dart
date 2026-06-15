import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/platform/tenants — alle Mandanten (Plattform-Admin).
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null || !auth.isPlatformAdmin) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final tenantRepository = context.read<TenantRepository>();
  final tenants = await tenantRepository.listAll();
  return Response.json(body: {'tenants': tenants.map((t) => t.toJson()).toList()});
}
