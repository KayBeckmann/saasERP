import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'number_sequence_repository.dart';

/// Angebote — Positionen (Freitext, Artikel-/Produkt-Referenz, Stunden)
/// werden bei jedem Speichern komplett ersetzt (wie bei
/// `ProductRepository`/`product_components`).
class QuoteRepository {
  QuoteRepository(this._pool, this._numberSequences);

  final Pool<void> _pool;
  final NumberSequenceRepository _numberSequences;

  static const _quoteColumns =
      'id, tenant_id, quote_number, customer_id, title, status, valid_until, notes, created_at';

  static const _itemColumns =
      'id, quote_id, kind, article_id, product_id, description, quantity, unit, unit_price, vat_rate, group_label';

  Future<Quote> create({
    required String tenantId,
    required CreateQuoteRequest req,
  }) async {
    final quoteNumber = await _numberSequences.next(
      tenantId: tenantId,
      sequenceKey: 'quote',
      defaultPrefix: 'A',
    );

    return _pool.runTx((session) async {
      final result = await session.execute(
        Sql.named(
          'INSERT INTO quotes (tenant_id, quote_number, customer_id, title, valid_until, notes) '
          'VALUES (@tenant_id, @quote_number, @customer_id, @title, @valid_until, @notes) '
          'RETURNING $_quoteColumns',
        ),
        parameters: {
          'tenant_id': tenantId,
          'quote_number': quoteNumber,
          'customer_id': req.customerId,
          'title': req.title,
          'valid_until': req.validUntil,
          'notes': req.notes,
        },
      );
      final quoteId = result.first.toColumnMap()['id'] as String;

      await _insertItems(session, tenantId: tenantId, quoteId: quoteId, items: req.items);

      final items = await _loadItems(session, quoteId: quoteId);
      return _fromRow(result.first.toColumnMap(), items);
    });
  }

  /// Anzahl offener Angebote (`draft`/`sent`) — für die Dashboard-Übersicht.
  Future<int> countOpen(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        "SELECT COUNT(*) AS count FROM quotes WHERE tenant_id = @tenant_id AND status IN ('draft', 'sent')",
      ),
      parameters: {'tenant_id': tenantId},
    );
    return (result.first.toColumnMap()['count'] as num).toInt();
  }

  Future<List<Quote>> list(String tenantId) async {
    final quoteRows = await _pool.execute(
      Sql.named('SELECT $_quoteColumns FROM quotes WHERE tenant_id = @tenant_id ORDER BY created_at DESC'),
      parameters: {'tenant_id': tenantId},
    );
    if (quoteRows.isEmpty) return [];

    final itemRows = await _pool.execute(
      Sql.named(
        'SELECT $_itemColumns FROM quote_items '
        'WHERE tenant_id = @tenant_id ORDER BY quote_id, sort_order',
      ),
      parameters: {'tenant_id': tenantId},
    );

    final itemsByQuote = <String, List<QuoteItem>>{};
    for (final row in itemRows) {
      final map = row.toColumnMap();
      final quoteId = map['quote_id'] as String;
      itemsByQuote.putIfAbsent(quoteId, () => []).add(_itemFromRow(map));
    }

    return quoteRows
        .map((row) => _fromRow(row.toColumnMap(), itemsByQuote[row.toColumnMap()['id']] ?? []))
        .toList();
  }

  /// Angebote eines bestimmten Kunden — für die Kundenportal-Übersicht
  /// (`app_kunde`).
  Future<List<Quote>> listForCustomer({required String tenantId, required String customerId}) async {
    final quoteRows = await _pool.execute(
      Sql.named(
        'SELECT $_quoteColumns FROM quotes '
        'WHERE tenant_id = @tenant_id AND customer_id = @customer_id ORDER BY created_at DESC',
      ),
      parameters: {'tenant_id': tenantId, 'customer_id': customerId},
    );
    if (quoteRows.isEmpty) return [];

    final itemRows = await _pool.execute(
      Sql.named(
        'SELECT $_itemColumns FROM quote_items '
        'WHERE tenant_id = @tenant_id ORDER BY quote_id, sort_order',
      ),
      parameters: {'tenant_id': tenantId},
    );

    final itemsByQuote = <String, List<QuoteItem>>{};
    for (final row in itemRows) {
      final map = row.toColumnMap();
      final quoteId = map['quote_id'] as String;
      itemsByQuote.putIfAbsent(quoteId, () => []).add(_itemFromRow(map));
    }

    return quoteRows
        .map((row) => _fromRow(row.toColumnMap(), itemsByQuote[row.toColumnMap()['id']] ?? []))
        .toList();
  }

  Future<Quote?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_quoteColumns FROM quotes WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;

    final items = await _loadItems(_pool, quoteId: id);
    return _fromRow(result.first.toColumnMap(), items);
  }

  Future<Quote?> update({
    required String tenantId,
    required String id,
    required UpdateQuoteRequest req,
  }) async {
    return _pool.runTx((session) async {
      final result = await session.execute(
        Sql.named(
          'UPDATE quotes SET customer_id = @customer_id, title = @title, status = @status, '
          'valid_until = @valid_until, notes = @notes '
          'WHERE tenant_id = @tenant_id AND id = @id '
          'RETURNING $_quoteColumns',
        ),
        parameters: {
          'tenant_id': tenantId,
          'id': id,
          'customer_id': req.customerId,
          'title': req.title,
          'status': req.status.toJson(),
          'valid_until': req.validUntil,
          'notes': req.notes,
        },
      );
      if (result.isEmpty) return null;

      await session.execute(
        Sql.named('DELETE FROM quote_items WHERE quote_id = @quote_id'),
        parameters: {'quote_id': id},
      );
      await _insertItems(session, tenantId: tenantId, quoteId: id, items: req.items);

      final items = await _loadItems(session, quoteId: id);
      return _fromRow(result.first.toColumnMap(), items);
    });
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM quotes WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  Future<void> _insertItems(
    Session session, {
    required String tenantId,
    required String quoteId,
    required List<QuoteItem> items,
  }) async {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await session.execute(
        Sql.named(
          'INSERT INTO quote_items '
          '(tenant_id, quote_id, kind, article_id, product_id, description, quantity, unit, unit_price, vat_rate, group_label, sort_order) '
          'VALUES (@tenant_id, @quote_id, @kind, @article_id, @product_id, @description, @quantity, @unit, @unit_price, @vat_rate, @group_label, @sort_order)',
        ),
        parameters: {
          'tenant_id': tenantId,
          'quote_id': quoteId,
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

  Future<List<QuoteItem>> _loadItems(Session session, {required String quoteId}) async {
    final result = await session.execute(
      Sql.named('SELECT $_itemColumns FROM quote_items WHERE quote_id = @quote_id ORDER BY sort_order'),
      parameters: {'quote_id': quoteId},
    );
    return result.map((row) => _itemFromRow(row.toColumnMap())).toList();
  }

  QuoteItem _itemFromRow(Map<String, dynamic> row) => QuoteItem(
        id: row['id'] as String,
        kind: QuoteItemKind.fromJson(row['kind'] as String),
        articleId: row['article_id'] as String?,
        productId: row['product_id'] as String?,
        description: row['description'] as String,
        quantity: (row['quantity'] as num).toDouble(),
        unit: row['unit'] as String?,
        unitPrice: (row['unit_price'] as num).toDouble(),
        vatRate: (row['vat_rate'] as num).toDouble(),
        groupLabel: row['group_label'] as String?,
      );

  Quote _fromRow(Map<String, dynamic> row, List<QuoteItem> items) => Quote(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        quoteNumber: row['quote_number'] as String,
        customerId: row['customer_id'] as String?,
        title: row['title'] as String,
        status: QuoteStatus.fromJson(row['status'] as String),
        validUntil: (row['valid_until'] as DateTime?)?.toUtc(),
        notes: row['notes'] as String?,
        createdAt: (row['created_at'] as DateTime).toUtc(),
        items: items,
      );
}
