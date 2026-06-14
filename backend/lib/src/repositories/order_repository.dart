import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'number_sequence_repository.dart';

/// Aufträge — Positionen (Freitext, Artikel-/Produkt-Referenz, Stunden,
/// inkl. Gruppen-Label) werden bei jedem Speichern komplett ersetzt (wie
/// bei `QuoteRepository`/`quote_items`).
class OrderRepository {
  OrderRepository(this._pool, this._numberSequences);

  final Pool<void> _pool;
  final NumberSequenceRepository _numberSequences;

  static const _orderColumns =
      'id, tenant_id, order_number, quote_id, customer_id, project_id, title, status, notes, created_at';

  static const _itemColumns =
      'id, order_id, kind, article_id, product_id, description, quantity, unit, unit_price, vat_rate, group_label';

  Future<Order> create({
    required String tenantId,
    required CreateOrderRequest req,
    String? quoteId,
  }) async {
    final orderNumber = await _numberSequences.next(
      tenantId: tenantId,
      sequenceKey: 'order',
      defaultPrefix: 'AU',
    );

    return _pool.runTx((session) async {
      final result = await session.execute(
        Sql.named(
          'INSERT INTO orders (tenant_id, order_number, quote_id, customer_id, project_id, title, notes) '
          'VALUES (@tenant_id, @order_number, @quote_id, @customer_id, @project_id, @title, @notes) '
          'RETURNING $_orderColumns',
        ),
        parameters: {
          'tenant_id': tenantId,
          'order_number': orderNumber,
          'quote_id': quoteId,
          'customer_id': req.customerId,
          'project_id': req.projectId,
          'title': req.title,
          'notes': req.notes,
        },
      );
      final orderId = result.first.toColumnMap()['id'] as String;

      await _insertItems(session, tenantId: tenantId, orderId: orderId, items: req.items);

      final items = await _loadItems(session, orderId: orderId);
      return _fromRow(result.first.toColumnMap(), items);
    });
  }

  Future<List<Order>> list(String tenantId) async {
    final orderRows = await _pool.execute(
      Sql.named('SELECT $_orderColumns FROM orders WHERE tenant_id = @tenant_id ORDER BY created_at DESC'),
      parameters: {'tenant_id': tenantId},
    );
    if (orderRows.isEmpty) return [];

    final itemRows = await _pool.execute(
      Sql.named(
        'SELECT $_itemColumns FROM order_items '
        'WHERE tenant_id = @tenant_id ORDER BY order_id, sort_order',
      ),
      parameters: {'tenant_id': tenantId},
    );

    final itemsByOrder = <String, List<OrderItem>>{};
    for (final row in itemRows) {
      final map = row.toColumnMap();
      final orderId = map['order_id'] as String;
      itemsByOrder.putIfAbsent(orderId, () => []).add(_itemFromRow(map));
    }

    return orderRows
        .map((row) => _fromRow(row.toColumnMap(), itemsByOrder[row.toColumnMap()['id']] ?? []))
        .toList();
  }

  Future<Order?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_orderColumns FROM orders WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;

    final items = await _loadItems(_pool, orderId: id);
    return _fromRow(result.first.toColumnMap(), items);
  }

  Future<Order?> update({
    required String tenantId,
    required String id,
    required UpdateOrderRequest req,
  }) async {
    return _pool.runTx((session) async {
      final result = await session.execute(
        Sql.named(
          'UPDATE orders SET customer_id = @customer_id, project_id = @project_id, title = @title, '
          'status = @status, notes = @notes '
          'WHERE tenant_id = @tenant_id AND id = @id '
          'RETURNING $_orderColumns',
        ),
        parameters: {
          'tenant_id': tenantId,
          'id': id,
          'customer_id': req.customerId,
          'project_id': req.projectId,
          'title': req.title,
          'status': req.status.toJson(),
          'notes': req.notes,
        },
      );
      if (result.isEmpty) return null;

      await session.execute(
        Sql.named('DELETE FROM order_items WHERE order_id = @order_id'),
        parameters: {'order_id': id},
      );
      await _insertItems(session, tenantId: tenantId, orderId: id, items: req.items);

      final items = await _loadItems(session, orderId: id);
      return _fromRow(result.first.toColumnMap(), items);
    });
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM orders WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  Future<void> _insertItems(
    Session session, {
    required String tenantId,
    required String orderId,
    required List<OrderItem> items,
  }) async {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await session.execute(
        Sql.named(
          'INSERT INTO order_items '
          '(tenant_id, order_id, kind, article_id, product_id, description, quantity, unit, unit_price, vat_rate, group_label, sort_order) '
          'VALUES (@tenant_id, @order_id, @kind, @article_id, @product_id, @description, @quantity, @unit, @unit_price, @vat_rate, @group_label, @sort_order)',
        ),
        parameters: {
          'tenant_id': tenantId,
          'order_id': orderId,
          'kind': item.kind.toJson(),
          'article_id': item.articleId,
          'product_id': item.productId,
          'description': item.description,
          'quantity': item.quantity,
          'unit': item.unit,
          'unit_price': item.unitPrice,
          'vat_rate': item.vatRate,
          'group_label': item.groupLabel,
          'sort_order': i,
        },
      );
    }
  }

  Future<List<OrderItem>> _loadItems(Session session, {required String orderId}) async {
    final result = await session.execute(
      Sql.named('SELECT $_itemColumns FROM order_items WHERE order_id = @order_id ORDER BY sort_order'),
      parameters: {'order_id': orderId},
    );
    return result.map((row) => _itemFromRow(row.toColumnMap())).toList();
  }

  OrderItem _itemFromRow(Map<String, dynamic> row) => OrderItem(
        id: row['id'] as String,
        kind: OrderItemKind.fromJson(row['kind'] as String),
        articleId: row['article_id'] as String?,
        productId: row['product_id'] as String?,
        description: row['description'] as String,
        quantity: (row['quantity'] as num).toDouble(),
        unit: row['unit'] as String?,
        unitPrice: (row['unit_price'] as num).toDouble(),
        vatRate: (row['vat_rate'] as num).toDouble(),
        groupLabel: row['group_label'] as String?,
      );

  Order _fromRow(Map<String, dynamic> row, List<OrderItem> items) => Order(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        orderNumber: row['order_number'] as String,
        quoteId: row['quote_id'] as String?,
        customerId: row['customer_id'] as String?,
        projectId: row['project_id'] as String?,
        title: row['title'] as String,
        status: OrderStatus.fromJson(row['status'] as String),
        notes: row['notes'] as String?,
        createdAt: (row['created_at'] as DateTime).toUtc(),
        items: items,
      );
}
