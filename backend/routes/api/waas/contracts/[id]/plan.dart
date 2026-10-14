import 'dart:convert';
import 'package:backend/src/repositories/waas_billing_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:backend/src/waas_billing.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Owner-only price revision; only future unbilled period boundaries accepted.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final auth = await requirePermission(context, module: PermissionModule.waas, action: PermissionAction.edit);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;
  try {
    final body =
        jsonDecode(await context.request.body()) as Map<String, dynamic>;
    final date = DateTime.parse(body['effective_from'] as String);
    final plan = BillingPlan(
      monthlyCents: body['monthly_cents'] as int,
      vatBasisPoints: body['vat_basis_points'] as int,
      effectiveFrom: date,
    );
    await context.read<WaasBillingRepository>().addRevision(
      tenantId: payload.tenantId,
      contractId: id,
      actorId: payload.userId,
      plan: plan,
      description: body['description'] as String,
    );
    return Response.json(statusCode: 201, body: {'created': true});
  } on StateError catch (_) {
    return Response.json(
      statusCode: 409,
      body: {'error': 'contract_or_period_conflict'},
    );
  } on Exception catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'invalid_plan'});
  }
}
