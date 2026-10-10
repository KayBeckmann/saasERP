import 'package:postgres/postgres.dart';
import '../waas_billing.dart';

enum BillingRunState {
  draft,
  approved;

  bool get visibleToCustomer => this == approved;
}

/// All writes use the locked contract row and one transaction; the unique
/// (tenant, contract, period) index is a second defence against duplicate runs.
class WaasBillingRepository {
  WaasBillingRepository(this._pool);
  final Pool<void> _pool;

  Future<void> addRevision({
    required String tenantId,
    required String contractId,
    required String actorId,
    required BillingPlan plan,
    required String description,
  }) async {
    if (description.trim().isEmpty) throw ArgumentError('description required');
    await _pool.runTx((tx) async {
      final contract = await tx.execute(
        Sql.named(
          'SELECT start_date, end_date, status FROM maintenance_contracts '
          'WHERE id = @contract AND tenant_id = @tenant FOR UPDATE',
        ),
        parameters: {'contract': contractId, 'tenant': tenantId},
      );
      if (contract.isEmpty ||
          contract.first.toColumnMap()['status'] != 'active')
        throw StateError('active contract not found');
      final start = contract.first.toColumnMap()['start_date'] as DateTime;
      final end = contract.first.toColumnMap()['end_date'] as DateTime;
      if (plan.effectiveFrom.isBefore(start) || plan.effectiveFrom.isAfter(end))
        throw ArgumentError('effective date outside contract');
      var boundary = false;
      for (var i = 0; i < 1200; i++) {
        final candidate = periodAt(start, i).$1;
        if (candidate == plan.effectiveFrom) {
          boundary = true;
          break;
        }
        if (candidate.isAfter(plan.effectiveFrom)) break;
      }
      if (!boundary)
        throw ArgumentError('revision must begin at a period boundary');
      final existing = await tx.execute(
        Sql.named(
          'SELECT 1 FROM waas_billing_runs WHERE tenant_id = @tenant AND contract_id = @contract '
          'AND period_start >= @effective LIMIT 1',
        ),
        parameters: {
          'tenant': tenantId,
          'contract': contractId,
          'effective': plan.effectiveFrom,
        },
      );
      if (existing.isNotEmpty)
        throw StateError('already billed periods cannot be repriced');
      await tx.execute(
        Sql.named(
          'INSERT INTO waas_plan_revisions '
          '(tenant_id, contract_id, effective_from, monthly_cents, vat_basis_points, description, created_by) '
          'VALUES (@tenant, @contract, @effective, @cents, @vat, @description, @actor)',
        ),
        parameters: {
          'tenant': tenantId,
          'contract': contractId,
          'effective': plan.effectiveFrom,
          'cents': plan.monthlyCents,
          'vat': plan.vatBasisPoints,
          'description': description.trim(),
          'actor': actorId,
        },
      );
    });
  }

  /// Creates completed monthly periods as drafts. No email, PSP or publication.
  /// asOf is supplied by the server route, not the client.
  Future<List<String>> run({
    required String tenantId,
    required String contractId,
    required DateTime asOf,
  }) async {
    return _pool.runTx((tx) async {
      final rows = await tx.execute(
        Sql.named(
          'SELECT customer_id, title, start_date, end_date, status '
          'FROM maintenance_contracts WHERE tenant_id = @tenant AND id = @contract FOR UPDATE',
        ),
        parameters: {'tenant': tenantId, 'contract': contractId},
      );
      if (rows.isEmpty) throw StateError('contract not found');
      final contract = rows.first.toColumnMap();
      if (contract['status'] != 'active') return <String>[];
      final start = contract['start_date'] as DateTime;
      final end = contract['end_date'] as DateTime;
      final last = duePeriod(start, asOf, end.add(const Duration(days: 1)));
      if (last == null) return <String>[];
      final revisions = await tx.execute(
        Sql.named(
          'SELECT id, effective_from, monthly_cents, vat_basis_points, description '
          'FROM waas_plan_revisions WHERE tenant_id = @tenant AND contract_id = @contract ORDER BY effective_from',
        ),
        parameters: {'tenant': tenantId, 'contract': contractId},
      );
      final created = <String>[];
      for (var i = 0; i < 1200; i++) {
        final window = periodAt(start, i);
        if (window.$2.isAfter(last.$2)) break;
        final exists = await tx.execute(
          Sql.named(
            'SELECT invoice_id FROM waas_billing_runs '
            'WHERE tenant_id = @tenant AND contract_id = @contract AND period_start = @start',
          ),
          parameters: {
            'tenant': tenantId,
            'contract': contractId,
            'start': window.$1,
          },
        );
        if (exists.isNotEmpty) continue;
        Map<String, dynamic>? revision;
        for (final row in revisions) {
          final r = row.toColumnMap();
          if ((r['effective_from'] as DateTime).isAfter(window.$1)) break;
          revision = r;
        }
        if (revision == null) continue; // no agreed price for this period
        await tx.execute(
          Sql.named(
            'INSERT INTO number_sequences '
            '(tenant_id, sequence_key, prefix, pad_width, next_number) '
            "VALUES (@tenant, 'invoice', 'R', 4, 1) ON CONFLICT (tenant_id, sequence_key) DO NOTHING",
          ),
          parameters: {'tenant': tenantId},
        );
        final sequence = await tx.execute(
          Sql.named(
            "UPDATE number_sequences SET next_number = next_number + 1 "
            "WHERE tenant_id = @tenant AND sequence_key = 'invoice' RETURNING prefix, pad_width, next_number - 1 AS number",
          ),
          parameters: {'tenant': tenantId},
        );
        final seq = sequence.first.toColumnMap();
        final number =
            '${seq['prefix']}${(seq['number'] as int).toString().padLeft(seq['pad_width'] as int, '0')}';
        final invoice = await tx.execute(
          Sql.named(
            'INSERT INTO invoices '
            '(tenant_id, invoice_number, customer_id, title, due_date) '
            'VALUES (@tenant, @number, @customer, @title, @due) RETURNING id',
          ),
          parameters: {
            'tenant': tenantId,
            'number': number,
            'customer': contract['customer_id'],
            'title': contract['title'],
            'due': window.$2.add(const Duration(days: 14)),
          },
        );
        final invoiceId = invoice.first.toColumnMap()['id'] as String;
        await tx.execute(
          Sql.named(
            'INSERT INTO invoice_items '
            '(tenant_id, invoice_id, description, quantity, unit, unit_price, vat_rate, sort_order) '
            'VALUES (@tenant, @invoice, @description, 1, @unit, @price, @vat, 0)',
          ),
          parameters: {
            'tenant': tenantId,
            'invoice': invoiceId,
            'description':
                '${revision['description']} (${window.$1.toIso8601String().substring(0, 10)} – ${window.$2.toIso8601String().substring(0, 10)})',
            'unit': 'Monat',
            'price': (revision['monthly_cents'] as int) / 100,
            'vat': (revision['vat_basis_points'] as int) / 100,
          },
        );
        await tx.execute(
          Sql.named(
            'INSERT INTO waas_billing_runs '
            '(tenant_id, contract_id, plan_revision_id, invoice_id, period_start, period_end) '
            'VALUES (@tenant, @contract, @revision, @invoice, @start, @end)',
          ),
          parameters: {
            'tenant': tenantId,
            'contract': contractId,
            'revision': revision['id'],
            'invoice': invoiceId,
            'start': window.$1,
            'end': window.$2,
          },
        );
        created.add(invoiceId);
      }
      return created;
    });
  }

  /// Explicit pilot release: still no email or debit; document appears in portal.
  Future<bool> approve({
    required String tenantId,
    required String invoiceId,
    required String actorId,
  }) async {
    return _pool.runTx((tx) async {
      final rows = await tx.execute(
        Sql.named(
          'UPDATE waas_billing_runs '
          'SET approved_by = @actor, approved_at = now() '
          'WHERE tenant_id = @tenant AND invoice_id = @invoice AND approved_at IS NULL RETURNING invoice_id',
        ),
        parameters: {
          'actor': actorId,
          'tenant': tenantId,
          'invoice': invoiceId,
        },
      );
      if (rows.isEmpty) return false;
      await tx.execute(
        Sql.named(
          "UPDATE invoices SET status = 'sent' WHERE tenant_id = @tenant AND id = @invoice AND status = 'draft'",
        ),
        parameters: {'tenant': tenantId, 'invoice': invoiceId},
      );
      return true;
    });
  }
}
