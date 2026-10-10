import 'package:backend/src/repositories/waas_billing_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Manual pilot approval: exposes the previously generated draft to its customer.
/// Does NOT initiate an email, mandate or debit.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final auth = authenticateRequest(context);
  if (auth == null)
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  if (auth.role != UserRole.owner.toJson())
    return Response.json(statusCode: 403, body: {'error': 'forbidden'});
  final approved = await context.read<WaasBillingRepository>().approve(
    tenantId: auth.tenantId,
    invoiceId: id,
    actorId: auth.userId,
  );
  if (!approved)
    return Response.json(
      statusCode: 404,
      body: {'error': 'not_found_or_already_approved'},
    );
  return Response.json(body: {'approved': true});
}
