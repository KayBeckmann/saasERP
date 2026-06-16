import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

/// GET /api/platform/metrics — Plattform-Kennzahlen für den Plattform-Admin
/// (M6 — Monitoring). Liefert tenant_count, active_subscriptions,
/// open_platform_invoices (Anzahl + Summe) und overdue_platform_invoices.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null || !auth.isPlatformAdmin) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final pool = context.read<Pool<void>>();

  final results = await Future.wait([
    pool.execute('SELECT COUNT(*) FROM tenants'),
    pool.execute("SELECT COUNT(*) FROM subscriptions WHERE status = 'active'"),
    pool.execute("SELECT COUNT(*), COALESCE(SUM(amount), 0) FROM platform_invoices WHERE status = 'open'"),
    pool.execute(
      "SELECT COUNT(*) FROM platform_invoices WHERE due_date < CURRENT_DATE AND status NOT IN ('paid', 'cancelled')",
    ),
  ]);

  final tenantCount = (results[0].first[0] as num?)?.toInt() ?? 0;
  final activeSubscriptions = (results[1].first[0] as num?)?.toInt() ?? 0;
  final openInvoiceRow = results[2].first;
  final openInvoiceCount = (openInvoiceRow[0] as num?)?.toInt() ?? 0;
  final openInvoiceTotal = (openInvoiceRow[1] as num?)?.toDouble() ?? 0.0;
  final overdueCount = (results[3].first[0] as num?)?.toInt() ?? 0;

  return Response.json(body: {
    'tenant_count': tenantCount,
    'active_subscriptions': activeSubscriptions,
    'open_platform_invoices': openInvoiceCount,
    'open_platform_invoices_total': openInvoiceTotal,
    'overdue_platform_invoices': overdueCount,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  });
}
