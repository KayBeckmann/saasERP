import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/project_repository.dart';
import 'package:backend/src/repositories/project_transaction_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/projects/<id>/profit-loss — Gewinn/Verlust-Übersicht des
/// Projekts: Einnahmen aus Rechnungen verknüpfter Aufträge plus sonstige
/// Einnahmen, Ausgaben aus zugeordneten Bestellungen plus sonstige Ausgaben,
/// sowie Stundenkosten (erfasste Stunden × hinterlegter Stundensatz).
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final projectRepository = context.read<ProjectRepository>();
  final project = await projectRepository.findById(tenantId: auth.tenantId, id: id);
  if (project == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final invoiceRepository = context.read<InvoiceRepository>();
  final projectTransactionRepository = context.read<ProjectTransactionRepository>();
  final tenantRepository = context.read<TenantRepository>();

  final tenant = await tenantRepository.findById(auth.tenantId);
  final hourlyRate = tenant?.defaultHourlyRate ?? 0;

  final invoicedIncome = await invoiceRepository.sumNetForProject(tenantId: auth.tenantId, projectId: id);
  final otherIncome = await projectTransactionRepository.sumByKind(
    tenantId: auth.tenantId,
    projectId: id,
    kind: ProjectTransactionKind.income,
  );
  final purchaseExpenses = await projectRepository.sumPurchaseExpenses(tenantId: auth.tenantId, projectId: id);
  final otherExpenses = await projectTransactionRepository.sumByKind(
    tenantId: auth.tenantId,
    projectId: id,
    kind: ProjectTransactionKind.expense,
  );
  final laborHours = await projectRepository.sumLaborHours(tenantId: auth.tenantId, projectId: id);

  final profitLoss = ProjectProfitLoss(
    invoicedIncome: invoicedIncome,
    otherIncome: otherIncome,
    purchaseExpenses: purchaseExpenses,
    otherExpenses: otherExpenses,
    laborHours: laborHours,
    hourlyRate: hourlyRate,
  );

  return Response.json(body: profitLoss.toJson());
}
