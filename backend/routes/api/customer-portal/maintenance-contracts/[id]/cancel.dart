import 'package:backend/src/repositories/customer_portal_account_repository.dart';
import 'package:backend/src/repositories/maintenance_contract_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// PATCH /api/customer-portal/maintenance-contracts/<id>/cancel — Endkunde
/// kündigt einen aktiven Wartungsvertrag/Abo zum heutigen Datum.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null || auth.role != 'customer') {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final portalAccountRepository = context.read<CustomerPortalAccountRepository>();
  final account = await portalAccountRepository.findById(auth.userId);
  if (account == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final contractRepository = context.read<MaintenanceContractRepository>();
  final contract = await contractRepository.recordCustomerCancellation(
    tenantId: auth.tenantId,
    id: id,
    customerId: account.customerId,
  );
  if (contract == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  return Response.json(body: contract.toJson());
}
