import 'package:backend/src/repositories/dashboard_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/dashboard/summary — Kennzahlen für die Dashboard-Übersicht
/// (offene Belege je Typ, überfällige Rechnungen, Monatsstunden des
/// angemeldeten Nutzers).
Future<Response> onRequest(RequestContext context) async {
  final auth = await requirePermission(context, module: PermissionModule.dashboard, action: PermissionAction.view);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final summary = await context.read<DashboardRepository>().summary(
        tenantId: payload.tenantId,
        userId: payload.userId,
      );
  return Response.json(body: summary.toJson());
}
