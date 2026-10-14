import 'package:backend/src/repositories/subscription_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/subscription — das aktuelle Abo des eigenen Mandanten
/// (Self-Service, M3). Nur für den Owner.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final auth = await requirePermission(context, module: PermissionModule.tenantConfig, action: PermissionAction.view);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  final subscriptionRepository = context.read<SubscriptionRepository>();
  final subscription = await subscriptionRepository.findActiveForTenant(payload.tenantId);
  if (subscription == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  return Response.json(body: subscription.toJson());
}
