import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'number_sequence_repository.dart';

/// Bestellungen — Positionen werden bei jedem Speichern komplett ersetzt
/// (wie bei `OrderRepository`/`order_items`).
class PurchaseOrderRepository {
  PurchaseOrderRepository(this._pool, this._numberSequences);

  final Pool<void> _pool;
  final NumberSequenceRepository _numberSequences;

  static const _columns =
      'id, tenant_id, purchase_order_number, supplier_id, order_id, project_id, status, notes, created_at';

  static const _itemColumns =
      'id, purchase_order_id, article_id, description, quantity, quantity_delivered, unit, unit_price';

  Future<PurchaseOrder> create({
    required String tenantId,
    required CreatePurchaseOrderRequest req,
  }) async {
    final purchaseOrderNumber = await _numberSequences.next(
      tenantId: tenantId,
      sequenceKey: 'purchase_order',
      defaultPrefix: 'BE',
    );

    return _pool.runTx((session) async {
      final result = await session.execute(
        Sql.named(
          'INSERT INTO purchase_orders (tenant_id, purchase_order_number, supplier_id, order_id, project_id, notes) '
          'VALUES (@tenant_id, @purchase_order_number, @supplier_id, @order_id, @project_id, @notes) '
          'RETURNING $_columns',
        ),
        parameters: {
          'tenant_id': tenantId,
          'purchase_order_number': purchaseOrderNumber,
          'supplier_id': req.supplierId,
          'order_id': req.orderId,
          'project_id': req.projectId,
          'notes': req.notes,
        },
      );
      final purchaseOrderId = result.first.toColumnMap()['id'] as String;

      await _insertItems(session, tenantId: tenantId, purchaseOrderId: purchaseOrderId, items: req.items);

      final items = await _loadItems(session, purchaseOrderId: purchaseOrderId);
      return _fromRow(result.first.toColumnMap(), items);
    });
  }

  /// Anzahl offener Bestellungen (`open`/`ordered`/`partially_delivered`) —
  /// für die Dashboard-Übersicht.
  Future<int> countOpen(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT COUNT(*) AS count FROM purchase_orders WHERE tenant_id = @tenant_id '
        "AND status IN ('open', 'ordered', 'partially_delivered')",
      ),
      parameters: {'tenant_id': tenantId},
    );
    return (result.first.toColumnMap()['count'] as num).toInt();
  }

  Future<List<PurchaseOrder>> list(String tenantId) async {
    final orderRows = await _pool.execute(
      Sql.named('SELECT $_columns FROM purchase_orders WHERE tenant_id = @tenant_id ORDER BY created_at DESC'),
      parameters: {'tenant_id': tenantId},
    );
    if (orderRows.isEmpty) return [];

    final itemRows = await _pool.execute(
      Sql.named(
        'SELECT $_itemColumns FROM purchase_order_items '
        'WHERE tenant_id = @tenant_id ORDER BY purchase_order_id, sort_order',
      ),
      parameters: {'tenant_id': tenantId},
    );
    final sourceRows = await _pool.execute(
      Sql.named(
        'SELECT purchase_order_item_id, order_id, order_item_id, group_label, quantity '
        'FROM purchase_order_item_sources WHERE tenant_id = @tenant_id',
      ),
      parameters: {'tenant_id': tenantId},
    );
    final sourcesByItemId = <String, List<PurchaseOrderItemSource>>{};
    for (final row in sourceRows) {
      final map = row.toColumnMap();
      sourcesByItemId.putIfAbsent(map['purchase_order_item_id'] as String, () => []).add(
            PurchaseOrderItemSource(
              orderId: map['order_id'] as String?,
              orderItemId: map['order_item_id'] as String?,
              groupLabel: map['group_label'] as String?,
              quantity: (map['quantity'] as num).toDouble(),
            ),
          );
    }

    final itemsByOrder = <String, List<PurchaseOrderItem>>{};
    for (final row in itemRows) {
      final map = row.toColumnMap();
      final purchaseOrderId = map['purchase_order_id'] as String;
      itemsByOrder.putIfAbsent(purchaseOrderId, () => []).add(_itemFromRow(map, sourcesByItemId));
    }

    return orderRows
        .map((row) => _fromRow(row.toColumnMap(), itemsByOrder[row.toColumnMap()['id']] ?? []))
        .toList();
  }

  Future<PurchaseOrder?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM purchase_orders WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;

    final items = await _loadItems(_pool, purchaseOrderId: id);
    return _fromRow(result.first.toColumnMap(), items);
  }

  Future<PurchaseOrder?> update({
    required String tenantId,
    required String id,
    required UpdatePurchaseOrderRequest req,
  }) async {
    return _pool.runTx((session) async {
      final result = await session.execute(
        Sql.named(
          'UPDATE purchase_orders SET supplier_id = @supplier_id, project_id = @project_id, '
          'status = @status, notes = @notes '
          'WHERE tenant_id = @tenant_id AND id = @id '
          'RETURNING $_columns',
        ),
        parameters: {
          'tenant_id': tenantId,
          'id': id,
          'supplier_id': req.supplierId,
          'project_id': req.projectId,
          'status': req.status.toJson(),
          'notes': req.notes,
        },
      );
      if (result.isEmpty) return null;

      // Quellverweise (Raumgruppen-Rückverfolgung) bleiben erhalten, wenn
      // eine bestehende Position ohne explizit mitgeschickte sources
      // aktualisiert wird — der Editor in der UI kennt sources nicht und
      // würde sie sonst bei jeder normalen Bearbeitung stillschweigend
      // löschen. Nur wirklich neue Positionen oder ein explizit
      // mitgeschicktes sources starten ohne/mit den neuen Werten.
      final existingSourcesByItemId = await _loadSourcesByItemId(session, purchaseOrderId: id);

      await session.execute(
        Sql.named('DELETE FROM purchase_order_items WHERE purchase_order_id = @purchase_order_id'),
        parameters: {'purchase_order_id': id},
      );
      final itemsWithPreservedSources = [
        for (final item in req.items)
          if (item.id != null && item.sources.isEmpty && existingSourcesByItemId.containsKey(item.id))
            PurchaseOrderItem(
              id: item.id,
              articleId: item.articleId,
              description: item.description,
              quantity: item.quantity,
              quantityDelivered: item.quantityDelivered,
              unit: item.unit,
              unitPrice: item.unitPrice,
              sources: existingSourcesByItemId[item.id]!,
            )
          else
            item,
      ];
      await _insertItems(session, tenantId: tenantId, purchaseOrderId: id, items: itemsWithPreservedSources);

      final items = await _loadItems(session, purchaseOrderId: id);
      return _fromRow(result.first.toColumnMap(), items);
    });
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM purchase_orders WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  /// Erfasst einen Wareneingang: addiert je Position die gelieferte Menge
  /// zu `quantity_delivered` und berechnet den neuen Status der Bestellung
  /// (`fully_delivered`, wenn alle Positionen vollständig geliefert sind,
  /// `partially_delivered`, wenn mindestens eine Position teilweise/ganz
  /// geliefert wurde, sonst unverändert).
  Future<PurchaseOrder?> receive({
    required String tenantId,
    required String id,
    required ReceivePurchaseOrderRequest req,
  }) async {
    return _pool.runTx((session) async {
      final orderResult = await session.execute(
        Sql.named('SELECT $_columns FROM purchase_orders WHERE tenant_id = @tenant_id AND id = @id'),
        parameters: {'tenant_id': tenantId, 'id': id},
      );
      if (orderResult.isEmpty) return null;

      for (final item in req.items) {
        if (item.delivered == 0) continue;

        final itemResult = await session.execute(
          Sql.named(
            'UPDATE purchase_order_items SET quantity_delivered = quantity_delivered + @delivered '
            'WHERE tenant_id = @tenant_id AND id = @id AND purchase_order_id = @purchase_order_id '
            'RETURNING article_id',
          ),
          parameters: {
            'tenant_id': tenantId,
            'id': item.id,
            'purchase_order_id': id,
            'delivered': item.delivered,
          },
        );
        if (itemResult.isEmpty) continue;

        // Wareneingang bucht den Lagerbestand des Artikels direkt zu.
        final articleId = itemResult.first.toColumnMap()['article_id'] as String?;
        if (articleId != null) {
          await session.execute(
            Sql.named(
              'UPDATE articles SET stock_quantity = stock_quantity + @delivered '
              'WHERE tenant_id = @tenant_id AND id = @article_id',
            ),
            parameters: {'tenant_id': tenantId, 'article_id': articleId, 'delivered': item.delivered},
          );
        }
      }

      final items = await _loadItems(session, purchaseOrderId: id);
      final allDelivered = items.isNotEmpty && items.every((item) => item.isFullyDelivered);
      final anyDelivered = items.any((item) => item.quantityDelivered > 0);
      final newStatus = allDelivered
          ? PurchaseOrderStatus.fullyDelivered
          : anyDelivered
              ? PurchaseOrderStatus.partiallyDelivered
              : PurchaseOrderStatus.fromJson(orderResult.first.toColumnMap()['status'] as String);

      final result = await session.execute(
        Sql.named(
          'UPDATE purchase_orders SET status = @status '
          'WHERE tenant_id = @tenant_id AND id = @id '
          'RETURNING $_columns',
        ),
        parameters: {'tenant_id': tenantId, 'id': id, 'status': newStatus.toJson()},
      );

      return _fromRow(result.first.toColumnMap(), items);
    });
  }

  Future<void> _insertItems(
    Session session, {
    required String tenantId,
    required String purchaseOrderId,
    required List<PurchaseOrderItem> items,
  }) async {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final result = await session.execute(
        Sql.named(
          'INSERT INTO purchase_order_items '
          '(tenant_id, purchase_order_id, article_id, description, quantity, quantity_delivered, unit, unit_price, sort_order) '
          'VALUES (@tenant_id, @purchase_order_id, @article_id, @description, @quantity, @quantity_delivered, @unit, @unit_price, @sort_order) '
          'RETURNING id',
        ),
        parameters: {
          'tenant_id': tenantId,
          'purchase_order_id': purchaseOrderId,
          'article_id': item.articleId,
          'description': item.description,
          'quantity': item.quantity,
          'quantity_delivered': item.quantityDelivered,
          'unit': item.unit,
          'unit_price': item.unitPrice,
          'sort_order': i,
        },
      );
      final itemId = result.first.toColumnMap()['id'] as String;
      for (final source in item.sources) {
        await session.execute(
          Sql.named(
            'INSERT INTO purchase_order_item_sources '
            '(tenant_id, purchase_order_item_id, order_id, order_item_id, group_label, quantity) '
            'VALUES (@tenant_id, @purchase_order_item_id, @order_id, @order_item_id, @group_label, @quantity)',
          ),
          parameters: {
            'tenant_id': tenantId,
            'purchase_order_item_id': itemId,
            'order_id': source.orderId,
            'order_item_id': source.orderItemId,
            'group_label': source.groupLabel,
            'quantity': source.quantity,
          },
        );
      }
    }
  }

  Future<List<PurchaseOrderItem>> _loadItems(Session session, {required String purchaseOrderId}) async {
    final result = await session.execute(
      Sql.named(
        'SELECT $_itemColumns FROM purchase_order_items '
        'WHERE purchase_order_id = @purchase_order_id ORDER BY sort_order',
      ),
      parameters: {'purchase_order_id': purchaseOrderId},
    );
    final sourcesByItemId = await _loadSourcesByItemId(session, purchaseOrderId: purchaseOrderId);
    return result
        .map((row) => _itemFromRow(row.toColumnMap(), sourcesByItemId))
        .toList();
  }

  /// Lädt alle Quellverweise einer Bestellung, gruppiert nach
  /// Bestellpositions-ID — Hilfsmethode für [_loadItems] und für den
  /// Sources-Erhalt in [update].
  Future<Map<String, List<PurchaseOrderItemSource>>> _loadSourcesByItemId(
    Session session, {
    required String purchaseOrderId,
  }) async {
    final result = await session.execute(
      Sql.named(
        'SELECT src.purchase_order_item_id, src.order_id, src.order_item_id, src.group_label, src.quantity '
        'FROM purchase_order_item_sources src '
        'JOIN purchase_order_items poi ON poi.id = src.purchase_order_item_id '
        'WHERE poi.purchase_order_id = @purchase_order_id',
      ),
      parameters: {'purchase_order_id': purchaseOrderId},
    );
    final sourcesByItemId = <String, List<PurchaseOrderItemSource>>{};
    for (final row in result) {
      final map = row.toColumnMap();
      final itemId = map['purchase_order_item_id'] as String;
      sourcesByItemId.putIfAbsent(itemId, () => []).add(
            PurchaseOrderItemSource(
              orderId: map['order_id'] as String?,
              orderItemId: map['order_item_id'] as String?,
              groupLabel: map['group_label'] as String?,
              quantity: (map['quantity'] as num).toDouble(),
            ),
          );
    }
    return sourcesByItemId;
  }

  /// Summe bereits in (beliebigen, nicht gelöschten) Bestellungen
  /// erfasster Mengen je Artikel für einen Auftrag — Grundlage der
  /// Idempotenzprüfung im Bestellvorschlag (verhindert Doppelbestellung
  /// bei wiederholtem Abruf/Sync-Retry).
  Future<Map<String, double>> sumOrderedQuantitiesForOrder({
    required String tenantId,
    required String orderId,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT poi.article_id, SUM(src.quantity) AS total '
        'FROM purchase_order_item_sources src '
        'JOIN purchase_order_items poi ON poi.id = src.purchase_order_item_id '
        'WHERE src.tenant_id = @tenant_id AND src.order_id = @order_id AND poi.article_id IS NOT NULL '
        'GROUP BY poi.article_id',
      ),
      parameters: {'tenant_id': tenantId, 'order_id': orderId},
    );
    return {
      for (final row in result)
        row.toColumnMap()['article_id'] as String: (row.toColumnMap()['total'] as num).toDouble(),
    };
  }

  PurchaseOrderItem _itemFromRow(
    Map<String, dynamic> row, [
    Map<String, List<PurchaseOrderItemSource>>? sourcesByItemId,
  ]) =>
      PurchaseOrderItem(
        id: row['id'] as String,
        articleId: row['article_id'] as String?,
        description: row['description'] as String,
        quantity: (row['quantity'] as num).toDouble(),
        quantityDelivered: (row['quantity_delivered'] as num).toDouble(),
        unit: row['unit'] as String?,
        unitPrice: (row['unit_price'] as num).toDouble(),
        sources: sourcesByItemId?[row['id'] as String] ?? const [],
      );

  PurchaseOrder _fromRow(Map<String, dynamic> row, List<PurchaseOrderItem> items) => PurchaseOrder(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        purchaseOrderNumber: row['purchase_order_number'] as String,
        supplierId: row['supplier_id'] as String?,
        orderId: row['order_id'] as String?,
        projectId: row['project_id'] as String?,
        status: PurchaseOrderStatus.fromJson(row['status'] as String),
        notes: row['notes'] as String?,
        createdAt: (row['created_at'] as DateTime).toUtc(),
        items: items,
      );
}
