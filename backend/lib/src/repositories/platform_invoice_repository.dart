import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'number_sequence_repository.dart';

/// Plattform-Rechnungen: saasERP rechnet sein eigenes Produkt bei seinen
/// Mandanten ab (M4 — Zahlungsabwicklung, "Eat your own dog food"). Eine
/// Rechnung je Abrechnungsperiode, mandanten-gescopt.
class PlatformInvoiceRepository {
  PlatformInvoiceRepository(this._pool, this._numberSequenceRepository);

  final Pool<void> _pool;
  final NumberSequenceRepository _numberSequenceRepository;

  static const _columns = 'id, tenant_id, subscription_id, invoice_number, period_start, period_end, '
      'amount, payment_method, status, due_date, paid_at, notes, created_at';

  Future<List<PlatformInvoice>> listForTenant(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns FROM platform_invoices '
        'WHERE tenant_id = @tenant_id '
        'ORDER BY period_start DESC',
      ),
      parameters: {'tenant_id': tenantId},
    );
    return result.map((row) => _fromRow(row.toColumnMap())).toList();
  }

  Future<PlatformInvoice?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM platform_invoices WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<PlatformInvoice> create({required String tenantId, required CreatePlatformInvoiceRequest req}) async {
    final invoiceNumber = await _numberSequenceRepository.next(
      tenantId: tenantId,
      sequenceKey: 'platform_invoice',
      defaultPrefix: 'PR',
    );
    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO platform_invoices (tenant_id, subscription_id, invoice_number, period_start, '
        'period_end, amount, payment_method, due_date, notes) '
        'VALUES (@tenant_id, @subscription_id, @invoice_number, @period_start, '
        '@period_end, @amount, @payment_method, @due_date, @notes) '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'subscription_id': req.subscriptionId,
        'invoice_number': invoiceNumber,
        'period_start': req.periodStart,
        'period_end': req.periodEnd,
        'amount': req.amount,
        'payment_method': req.paymentMethod.toJson(),
        'due_date': req.dueDate,
        'notes': req.notes,
      },
    );
    return _fromRow(result.first.toColumnMap());
  }

  /// Manuelle Zahlungserfassung: markiert eine offene/überfällige Rechnung
  /// als bezahlt — Status-Guard in der WHERE-Klausel (`status IN ('open',
  /// 'overdue')`), liefert sonst `null` (→ 404 in der Route).
  Future<PlatformInvoice?> markPaid({
    required String tenantId,
    required String id,
    required DateTime paidAt,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        "UPDATE platform_invoices SET status = 'paid', paid_at = @paid_at "
        "WHERE tenant_id = @tenant_id AND id = @id AND status IN ('open', 'overdue') "
        'RETURNING $_columns',
      ),
      parameters: {'tenant_id': tenantId, 'id': id, 'paid_at': paidAt},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  /// Überfällige Plattform-Rechnungen über alle Mandanten — Grundlage für
  /// den Mahnlauf des Plattform-Admins (analog
  /// `InvoiceRepository.listOverdue`, hier ohne Mandanten-Filter).
  Future<List<PlatformInvoice>> listOverdueAll() async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns FROM platform_invoices '
        "WHERE due_date < CURRENT_DATE AND status NOT IN ('paid', 'cancelled') "
        'ORDER BY due_date ASC',
      ),
    );
    return result.map((row) => _fromRow(row.toColumnMap())).toList();
  }

  PlatformInvoice _fromRow(Map<String, dynamic> row) => PlatformInvoice(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        subscriptionId: row['subscription_id'] as String?,
        invoiceNumber: row['invoice_number'] as String,
        periodStart: (row['period_start'] as DateTime).toUtc(),
        periodEnd: (row['period_end'] as DateTime).toUtc(),
        amount: (row['amount'] as num).toDouble(),
        paymentMethod: PaymentMethod.fromJson(row['payment_method'] as String),
        status: PlatformInvoiceStatus.fromJson(row['status'] as String),
        dueDate: (row['due_date'] as DateTime).toUtc(),
        paidAt: (row['paid_at'] as DateTime?)?.toUtc(),
        notes: row['notes'] as String?,
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
