import 'package:backend/src/repositories/subscription_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/subscription/cancellation-preview?date=YYYY-MM-DD — berechnet
/// Restlaufzeit und Vertragsstrafe für ein Kündigungsdatum, ohne das Abo zu
/// kündigen (transparente Vorschau vor der Bestätigung, M3 Self-Service).
/// `date` ist optional, Default: heute. Nur für den Owner.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }
  if (auth.role != UserRole.owner.toJson()) {
    return Response.json(statusCode: 403, body: {'error': 'forbidden'});
  }

  final dateParam = context.request.uri.queryParameters['date'];
  DateTime date;
  try {
    date = dateParam != null ? DateTime.parse(dateParam) : DateTime.now();
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_date'});
  }

  final subscriptionRepository = context.read<SubscriptionRepository>();
  final subscription = await subscriptionRepository.findActiveForTenant(auth.tenantId);
  if (subscription == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final statement = SubscriptionCancellationStatement(
    subscription: subscription,
    remainingMonths: subscription.remainingMonths(date),
    penalty: subscription.penaltyAt(date),
  );
  return Response.json(body: statement.toJson());
}
