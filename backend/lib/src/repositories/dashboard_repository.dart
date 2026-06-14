import 'package:saaserp_shared/saaserp_shared.dart';

import 'invoice_repository.dart';
import 'order_repository.dart';
import 'purchase_order_repository.dart';
import 'quote_repository.dart';
import 'time_entry_repository.dart';

/// Aggregiert Kennzahlen aus den übrigen Repositories zu einer
/// [DashboardSummary] — bewusst ohne eigene Tabelle, analog zur
/// Gewinn/Verlust-Aggregation in `ProjectRepository`/`InvoiceRepository`.
class DashboardRepository {
  DashboardRepository(
    this._quoteRepository,
    this._orderRepository,
    this._purchaseOrderRepository,
    this._invoiceRepository,
    this._timeEntryRepository,
  );

  final QuoteRepository _quoteRepository;
  final OrderRepository _orderRepository;
  final PurchaseOrderRepository _purchaseOrderRepository;
  final InvoiceRepository _invoiceRepository;
  final TimeEntryRepository _timeEntryRepository;

  Future<DashboardSummary> summary({required String tenantId, required String userId}) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    final overdueInvoices = await _invoiceRepository.listOverdue(tenantId);
    final overdueTotal = overdueInvoices.fold<double>(0, (sum, invoice) => sum + invoice.totalDue);

    return DashboardSummary(
      openQuotes: await _quoteRepository.countOpen(tenantId),
      openOrders: await _orderRepository.countOpen(tenantId),
      openPurchaseOrders: await _purchaseOrderRepository.countOpen(tenantId),
      openInvoices: await _invoiceRepository.countOpen(tenantId),
      overdueInvoicesCount: overdueInvoices.length,
      overdueInvoicesTotal: overdueTotal,
      monthlyHours: await _timeEntryRepository.sumHours(
        tenantId: tenantId,
        userId: userId,
        from: monthStart,
        to: monthEnd,
      ),
    );
  }
}
