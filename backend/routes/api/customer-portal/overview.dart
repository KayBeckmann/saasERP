import 'package:backend/src/repositories/customer_portal_account_repository.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/maintenance_contract_repository.dart';
import 'package:backend/src/repositories/quote_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/customer-portal/overview — Übersicht des eingeloggten Endkunden
/// (`app_kunde`): eigene Angebote, Rechnungen und Wartungsverträge/Abos.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
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

  final quoteRepository = context.read<QuoteRepository>();
  final invoiceRepository = context.read<InvoiceRepository>();
  final maintenanceContractRepository = context.read<MaintenanceContractRepository>();

  final overview = CustomerPortalOverview(
    quotes: await quoteRepository.listForCustomer(tenantId: auth.tenantId, customerId: account.customerId),
    invoices: await invoiceRepository.listForCustomer(tenantId: auth.tenantId, customerId: account.customerId),
    maintenanceContracts: await maintenanceContractRepository.listForCustomer(
      tenantId: auth.tenantId,
      customerId: account.customerId,
    ),
  );
  return Response.json(body: overview.toJson());
}
