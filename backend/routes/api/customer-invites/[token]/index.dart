import 'package:backend/src/repositories/customer_portal_account_repository.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/customer-invites/<token> — öffentliche Vorschau eines
/// Einladungslinks (für die Anzeige in der Kunden-App vor Passwortvergabe).
Future<Response> onRequest(RequestContext context, String token) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final portalAccountRepository = context.read<CustomerPortalAccountRepository>();
  final customerRepository = context.read<CustomerRepository>();
  final tenantRepository = context.read<TenantRepository>();

  final account = await portalAccountRepository.findByInviteToken(token);
  if (account == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final customer = await customerRepository.findById(tenantId: account.tenantId, id: account.customerId);
  final tenant = await tenantRepository.findById(account.tenantId);
  if (customer == null || tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final preview = CustomerInvitePreview(
    tenantName: tenant.name,
    customerName: customer.name,
    email: account.email,
    status: account.status,
  );
  return Response.json(body: preview.toJson());
}
