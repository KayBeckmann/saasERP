import 'package:backend/src/repositories/dashboard_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/dashboard/summary — Kennzahlen für die Dashboard-Übersicht
/// (offene Belege je Typ, überfällige Rechnungen, Monatsstunden des
/// angemeldeten Nutzers).
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final summary = await context.read<DashboardRepository>().summary(
        tenantId: auth.tenantId,
        userId: auth.userId,
      );
  return Response.json(body: summary.toJson());
}
