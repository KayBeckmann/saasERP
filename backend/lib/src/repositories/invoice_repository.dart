import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'number_sequence_repository.dart';

/// Rechnungen — Positionen (Freitext, Artikel-/Produkt-Referenz, Stunden,
/// inkl. Gruppen-Label) werden bei jedem Speichern komplett ersetzt (wie
/// bei `OrderRepository`/`order_items`).
class InvoiceRepository {
  InvoiceRepository(this._pool, this._numberSequences);

  final Pool<void> _pool;
  final NumberSequenceRepository _numberSequences;

  static const _invoiceColumns =
      'id, tenant_id, invoice_number, order_id, customer_id, title, status, due_date, notes, created_at, '
      'invoice_type, prior_invoiced_total, dunning_level, dunning_fee_total, last_dunned_at';

  static const _itemColumns = 'id, invoice_id, kind, article_id, product_id, description, quantity, unit, '
      'unit_price, vat_rate, group_label, order_item_id';

  Future<Invoice> create({
    required String tenantId,
    required CreateInvoiceRequest req,
    String? orderId,
  }) async {
    final invoiceNumber = await _numberSequences.next(
      tenantId: tenantId,
      sequenceKey: 'invoice',
      defaultPrefix: 'R',
    );

    return _pool.runTx((session) async {
      final result = await session.execute(
        Sql.named(
          'INSERT INTO invoices (tenant_id, invoice_number, order_id, customer_id, title, due_date, notes, '
          'invoice_type, prior_invoiced_total) '
          'VALUES (@tenant_id, @invoice_number, @order_id, @customer_id, @title, @due_date, @notes, '
          '@invoice_type, @prior_invoiced_total) '
          'RETURNING $_invoiceColumns',
        ),
        parameters: {
          'tenant_id': tenantId,
          'invoice_number': invoiceNumber,
          'order_id': orderId,
          'customer_id': req.customerId,
          'title': req.title,
          'due_date': req.dueDate,
          'notes': req.notes,
          'invoice_type': req.invoiceType.toJson(),
          'prior_invoiced_total': req.priorInvoicedTotal,
        },
      );
      final invoiceId = result.first.toColumnMap()['id'] as String;

      await _insertItems(session, tenantId: tenantId, invoiceId: invoiceId, items: req.items);

      final items = await _loadItems(session, invoiceId: invoiceId);
      return _fromRow(result.first.toColumnMap(), items);
    });
  }

  Future<List<Invoice>> list(String tenantId) async {
    final invoiceRows = await _pool.execute(
      Sql.named('SELECT $_invoiceColumns FROM invoices WHERE tenant_id = @tenant_id ORDER BY created_at DESC'),
      parameters: {'tenant_id': tenantId},
    );
    if (invoiceRows.isEmpty) return [];

    final itemRows = await _pool.execute(
      Sql.named(
        'SELECT $_itemColumns FROM invoice_items '
        'WHERE tenant_id = @tenant_id ORDER BY invoice_id, sort_order',
      ),
      parameters: {'tenant_id': tenantId},
    );

    final itemsByInvoice = <String, List<InvoiceItem>>{};
    for (final row in itemRows) {
      final map = row.toColumnMap();
      final invoiceId = map['invoice_id'] as String;
      itemsByInvoice.putIfAbsent(invoiceId, () => []).add(_itemFromRow(map));
    }

    return invoiceRows
        .map((row) => _fromRow(row.toColumnMap(), itemsByInvoice[row.toColumnMap()['id']] ?? []))
        .toList();
  }

  Future<Invoice?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_invoiceColumns FROM invoices WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;

    final items = await _loadItems(_pool, invoiceId: id);
    return _fromRow(result.first.toColumnMap(), items);
  }

  Future<Invoice?> update({
    required String tenantId,
    required String id,
    required UpdateInvoiceRequest req,
  }) async {
    return _pool.runTx((session) async {
      final result = await session.execute(
        Sql.named(
          'UPDATE invoices SET customer_id = @customer_id, title = @title, status = @status, '
          'due_date = @due_date, notes = @notes, invoice_type = @invoice_type, '
          'prior_invoiced_total = @prior_invoiced_total '
          'WHERE tenant_id = @tenant_id AND id = @id '
          'RETURNING $_invoiceColumns',
        ),
        parameters: {
          'tenant_id': tenantId,
          'id': id,
          'customer_id': req.customerId,
          'title': req.title,
          'status': req.status.toJson(),
          'due_date': req.dueDate,
          'notes': req.notes,
          'invoice_type': req.invoiceType.toJson(),
          'prior_invoiced_total': req.priorInvoicedTotal,
        },
      );
      if (result.isEmpty) return null;

      await session.execute(
        Sql.named('DELETE FROM invoice_items WHERE invoice_id = @invoice_id'),
        parameters: {'invoice_id': id},
      );
      await _insertItems(session, tenantId: tenantId, invoiceId: id, items: req.items);

      final items = await _loadItems(session, invoiceId: id);
      return _fromRow(result.first.toColumnMap(), items);
    });
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM invoices WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  Future<void> _insertItems(
    Session session, {
    required String tenantId,
    required String invoiceId,
    required List<InvoiceItem> items,
  }) async {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await session.execute(
        Sql.named(
          'INSERT INTO invoice_items '
          '(tenant_id, invoice_id, kind, article_id, product_id, description, quantity, unit, unit_price, vat_rate, group_label, order_item_id, sort_order) '
          'VALUES (@tenant_id, @invoice_id, @kind, @article_id, @product_id, @description, @quantity, @unit, @unit_price, @vat_rate, @group_label, @order_item_id, @sort_order)',
        ),
        parameters: {
          'tenant_id': tenantId,
          'invoice_id': invoiceId,
          'kind': item.kind.toJson(),
          'article_id': item.articleId,
          'product_id': item.productId,
          'description': item.description,
          'quantity': item.quantity,
          'unit': item.unit,
          'unit_price': item.unitPrice,
          'vat_rate': item.vatRate,
          'group_label': item.groupLabel,
          'order_item_id': item.orderItemId,
          'sort_order': i,
        },
      );
    }
  }

  Future<List<InvoiceItem>> _loadItems(Session session, {required String invoiceId}) async {
    final result = await session.execute(
      Sql.named('SELECT $_itemColumns FROM invoice_items WHERE invoice_id = @invoice_id ORDER BY sort_order'),
      parameters: {'invoice_id': invoiceId},
    );
    return result.map((row) => _itemFromRow(row.toColumnMap())).toList();
  }

  InvoiceItem _itemFromRow(Map<String, dynamic> row) => InvoiceItem(
        id: row['id'] as String,
        kind: InvoiceItemKind.fromJson(row['kind'] as String),
        articleId: row['article_id'] as String?,
        productId: row['product_id'] as String?,
        description: row['description'] as String,
        quantity: (row['quantity'] as num).toDouble(),
        unit: row['unit'] as String?,
        unitPrice: (row['unit_price'] as num).toDouble(),
        vatRate: (row['vat_rate'] as num).toDouble(),
        groupLabel: row['group_label'] as String?,
        orderItemId: row['order_item_id'] as String?,
      );

  Invoice _fromRow(Map<String, dynamic> row, List<InvoiceItem> items) => Invoice(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        invoiceNumber: row['invoice_number'] as String,
        orderId: row['order_id'] as String?,
        customerId: row['customer_id'] as String?,
        title: row['title'] as String,
        status: InvoiceStatus.fromJson(row['status'] as String),
        dueDate: (row['due_date'] as DateTime?)?.toUtc(),
        notes: row['notes'] as String?,
        createdAt: (row['created_at'] as DateTime).toUtc(),
        items: items,
        invoiceType: InvoiceType.fromJson(row['invoice_type'] as String),
        priorInvoicedTotal: (row['prior_invoiced_total'] as num?)?.toDouble(),
        dunningLevel: (row['dunning_level'] as num).toInt(),
        dunningFeeTotal: (row['dunning_fee_total'] as num).toDouble(),
        lastDunnedAt: (row['last_dunned_at'] as DateTime?)?.toUtc(),
      );

  /// IDs der Auftragspositionen, die bereits über eine nicht-stornierte
  /// Rechnung dieses Auftrags abgerechnet wurden (Doppelabrechnungsschutz
  /// für Teil-/Abschlags-/Schlussrechnungen).
  Future<Set<String>> invoicedOrderItemIds({required String tenantId, required String orderId}) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT ii.order_item_id FROM invoice_items ii '
        'JOIN invoices i ON i.id = ii.invoice_id '
        "WHERE i.tenant_id = @tenant_id AND i.order_id = @order_id AND i.status != 'cancelled' "
        'AND ii.order_item_id IS NOT NULL',
      ),
      parameters: {'tenant_id': tenantId, 'order_id': orderId},
    );
    return result.map((row) => row.toColumnMap()['order_item_id'] as String).toSet();
  }

  /// Summe der Bruttobeträge aller nicht-stornierten Rechnungen eines
  /// Auftrags — Basis für `prior_invoiced_total` einer Schlussrechnung.
  Future<double> sumInvoicedGrossForOrder({required String tenantId, required String orderId}) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT COALESCE(SUM(ii.quantity * ii.unit_price * (1 + ii.vat_rate / 100.0)), 0) AS total '
        'FROM invoice_items ii '
        'JOIN invoices i ON i.id = ii.invoice_id '
        "WHERE i.tenant_id = @tenant_id AND i.order_id = @order_id AND i.status != 'cancelled'",
      ),
      parameters: {'tenant_id': tenantId, 'order_id': orderId},
    );
    return (result.first.toColumnMap()['total'] as num).toDouble();
  }

  /// Netto-Summe aller Rechnungspositionen von Rechnungen, die aus Aufträgen
  /// dieses Projekts erzeugt wurden — Einnahmen-Seite der
  /// Projekt-Gewinn/Verlust-Übersicht.
  Future<double> sumNetForProject({required String tenantId, required String projectId}) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT COALESCE(SUM(ii.quantity * ii.unit_price), 0) AS total '
        'FROM invoice_items ii '
        'JOIN invoices i ON i.id = ii.invoice_id '
        'JOIN orders o ON o.id = i.order_id '
        "WHERE i.tenant_id = @tenant_id AND o.project_id = @project_id AND i.status != 'cancelled'",
      ),
      parameters: {'tenant_id': tenantId, 'project_id': projectId},
    );
    return (result.first.toColumnMap()['total'] as num).toDouble();
  }

  /// Überfällige Rechnungen eines Mandanten: `due_date` liegt in der
  /// Vergangenheit, Status ist weder `paid` noch `cancelled`. Grundlage für
  /// den Mahnlauf.
  Future<List<Invoice>> listOverdue(String tenantId) async {
    final invoiceRows = await _pool.execute(
      Sql.named(
        'SELECT $_invoiceColumns FROM invoices '
        "WHERE tenant_id = @tenant_id AND due_date < CURRENT_DATE AND status NOT IN ('paid', 'cancelled') "
        'ORDER BY due_date ASC',
      ),
      parameters: {'tenant_id': tenantId},
    );
    if (invoiceRows.isEmpty) return [];

    final itemRows = await _pool.execute(
      Sql.named(
        'SELECT $_itemColumns FROM invoice_items '
        'WHERE tenant_id = @tenant_id ORDER BY invoice_id, sort_order',
      ),
      parameters: {'tenant_id': tenantId},
    );

    final itemsByInvoice = <String, List<InvoiceItem>>{};
    for (final row in itemRows) {
      final map = row.toColumnMap();
      final invoiceId = map['invoice_id'] as String;
      itemsByInvoice.putIfAbsent(invoiceId, () => []).add(_itemFromRow(map));
    }

    return invoiceRows
        .map((row) => _fromRow(row.toColumnMap(), itemsByInvoice[row.toColumnMap()['id']] ?? []))
        .toList();
  }

  /// Erhöht die Mahnstufe einer Rechnung um eine Stufe (max. 3), addiert die
  /// übergebene Mahngebühr auf [Invoice.dunningFeeTotal] und setzt
  /// [Invoice.lastDunnedAt] auf den aktuellen Zeitpunkt.
  Future<Invoice?> recordDunning({
    required String tenantId,
    required String id,
    required double fee,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE invoices SET '
        'dunning_level = LEAST(dunning_level + 1, 3), '
        'dunning_fee_total = dunning_fee_total + @fee, '
        'last_dunned_at = now() '
        'WHERE tenant_id = @tenant_id AND id = @id '
        'RETURNING $_invoiceColumns',
      ),
      parameters: {'tenant_id': tenantId, 'id': id, 'fee': fee},
    );
    if (result.isEmpty) return null;

    final items = await _loadItems(_pool, invoiceId: id);
    return _fromRow(result.first.toColumnMap(), items);
  }
}
