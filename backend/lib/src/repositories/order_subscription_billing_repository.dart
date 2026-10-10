import 'dart:io';
import 'package:postgres/postgres.dart';

/// Draft-only recurring billing, independent of maintenance/WaaS.
class OrderSubscriptionBillingRepository {
  OrderSubscriptionBillingRepository(this.pool);
  final Pool<void> pool;

  static DateTime period(DateTime start, String interval, int index) {
    final anchor = DateTime.utc(start.year, start.month, start.day);
    if (interval == 'weekly') return anchor.add(Duration(days: index * 7));
    final months = switch (interval) {
      'monthly' => 1,
      'quarterly' => 3,
      'semiannual' => 6,
      'yearly' => 12,
      _ => throw ArgumentError.value(interval, 'interval'),
    };
    final first = DateTime.utc(anchor.year, anchor.month + index * months);
    final next = DateTime.utc(first.year, first.month + 1, 0);
    return DateTime.utc(
      first.year,
      first.month,
      anchor.day <= next.day ? anchor.day : next.day,
    );
  }

  /// Rechecks an order under a row lock. Number allocation, invoice/items and
  /// period claim all commit or roll back together. Other workers block here.
  Future<List<String>> run({
    required String tenantId,
    required String orderId,
    required DateTime asOf,
  }) => pool.runTx((tx) async {
    final rows = await tx.execute(
      Sql.named(
        'SELECT * FROM orders WHERE tenant_id=@tenant AND id=@id FOR UPDATE',
      ),
      parameters: {'tenant': tenantId, 'id': orderId},
    );
    if (rows.isEmpty) return <String>[];
    final order = rows.first.toColumnMap();
    if (order['is_subscription'] != true ||
        !const ['open', 'in_progress'].contains(order['status']) ||
        order['customer_id'] == null ||
        order['billing_start_date'] == null)
      return <String>[];
    final items = await tx.execute(
      Sql.named(
        'SELECT * FROM order_items WHERE tenant_id=@tenant AND order_id=@id ORDER BY sort_order',
      ),
      parameters: {'tenant': tenantId, 'id': orderId},
    );
    if (items.isEmpty) return <String>[];
    final existing = await tx.execute(
      Sql.named(
        'SELECT period_start FROM order_subscription_invoice_runs WHERE order_id=@id ORDER BY period_start DESC LIMIT 1',
      ),
      parameters: {'id': orderId},
    );
    final latest = existing.isEmpty
        ? null
        : existing.first.toColumnMap()['period_start'] as DateTime;
    final start = order['billing_start_date'] as DateTime;
    final today = DateTime.utc(asOf.year, asOf.month, asOf.day);
    final created = <String>[];
    // Hard cap protects the server from runaway loops on corrupt ancient dates.
    for (var i = 0; i < 10000; i++) {
      final day = period(start, order['billing_interval'] as String, i);
      if (day.isAfter(today)) break;
      if (latest != null && !day.isAfter(latest)) continue;
      final exists = await tx.execute(
        Sql.named(
          'SELECT 1 FROM order_subscription_invoice_runs WHERE order_id=@id AND period_start=@day',
        ),
        parameters: {'id': orderId, 'day': day},
      );
      if (exists.isNotEmpty) continue;
      await tx.execute(
        Sql.named(
          "INSERT INTO number_sequences (tenant_id,sequence_key,prefix,pad_width,next_number) VALUES (@tenant,'invoice','R',4,1) ON CONFLICT (tenant_id,sequence_key) DO NOTHING",
        ),
        parameters: {'tenant': tenantId},
      );
      final sequence = await tx.execute(
        Sql.named(
          "UPDATE number_sequences SET next_number=next_number+1 WHERE tenant_id=@tenant AND sequence_key='invoice' RETURNING prefix,pad_width,next_number-1 AS number",
        ),
        parameters: {'tenant': tenantId},
      );
      final seq = sequence.first.toColumnMap();
      final number =
          '${seq['prefix']}${(seq['number'] as int).toString().padLeft(seq['pad_width'] as int, '0')}';
      final periodEnd = period(
        start,
        order['billing_interval'] as String,
        i + 1,
      ).subtract(const Duration(days: 1));
      String date(DateTime value) => value.toIso8601String().substring(0, 10);
      final originalNotes = (order['notes'] as String?)?.trim() ?? '';
      final periodNotes =
          'Abrechnungszeitraum: ${date(day)} bis ${date(periodEnd)}';
      final invoice = await tx.execute(
        Sql.named(
          "INSERT INTO invoices (tenant_id,invoice_number,order_id,customer_id,title,status,notes) VALUES (@tenant,@number,@order,@customer,@title,'draft',@notes) RETURNING id",
        ),
        parameters: {
          'tenant': tenantId,
          'number': number,
          'order': orderId,
          'customer': order['customer_id'],
          'title': order['title'],
          'notes': originalNotes.isEmpty
              ? periodNotes
              : '$periodNotes\n$originalNotes',
        },
      );
      final id = invoice.first.toColumnMap()['id'] as String;
      for (final row in items) {
        final item = row.toColumnMap();
        await tx.execute(
          Sql.named(
            'INSERT INTO invoice_items (tenant_id,invoice_id,kind,article_id,product_id,description,quantity,unit,unit_price,vat_rate,group_label,sort_order) VALUES (@tenant,@invoice,@kind,@article,@product,@description,@quantity,@unit,@price,@vat,@group,@sort)',
          ),
          parameters: {
            'tenant': tenantId,
            'invoice': id,
            'kind': item['kind'],
            'article': item['article_id'],
            'product': item['product_id'],
            'description': item['description'],
            'quantity': item['quantity'],
            'unit': item['unit'],
            'price': item['unit_price'],
            'vat': item['vat_rate'],
            'group': item['group_label'],
            'sort': item['sort_order'],
          },
        );
      }
      await tx.execute(
        Sql.named(
          'INSERT INTO order_subscription_invoice_runs (tenant_id,order_id,period_start,invoice_id) VALUES (@tenant,@order,@day,@invoice)',
        ),
        parameters: {
          'tenant': tenantId,
          'order': orderId,
          'day': day,
          'invoice': id,
        },
      );
      created.add(id);
    }
    return created;
  });

  Future<void> runDue({DateTime? asOf}) async {
    final rows = await pool.execute(
      Sql.named(
        "SELECT tenant_id,id FROM orders WHERE is_subscription=true AND status IN ('open','in_progress') AND billing_start_date<=@today",
      ),
      parameters: {'today': asOf ?? DateTime.now().toUtc()},
    );
    for (final row in rows) {
      final map = row.toColumnMap();
      try {
        await run(
          tenantId: map['tenant_id'] as String,
          orderId: map['id'] as String,
          asOf: asOf ?? DateTime.now().toUtc(),
        );
      } catch (error, stack) {
        stderr.writeln(
          'Subscription billing failed for ${map['id']}: $error\n$stack',
        );
      }
    }
  }
}
