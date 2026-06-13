import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Stundenerfassung — Einträge je Nutzer und Arbeitstag, optional einem
/// Auftrag zugeordnet.
class TimeEntryRepository {
  TimeEntryRepository(this._pool);

  final Pool<void> _pool;

  static const _columns =
      'id, tenant_id, user_id, order_id, work_date, hours, description, created_at';

  Future<TimeEntry> create({
    required String tenantId,
    required String userId,
    required CreateTimeEntryRequest req,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO time_entries (tenant_id, user_id, order_id, work_date, hours, description) '
        'VALUES (@tenant_id, @user_id, @order_id, @work_date, @hours, @description) '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'user_id': userId,
        'order_id': req.orderId,
        'work_date': req.workDate,
        'hours': req.hours,
        'description': req.description,
      },
    );
    return _fromRow(result.first.toColumnMap());
  }

  /// Listet die Einträge des Nutzers, optional eingeschränkt auf einen
  /// Zeitraum (für die Wochenansicht: `from`/`to` jeweils inklusiv).
  Future<List<TimeEntry>> list({
    required String tenantId,
    required String userId,
    DateTime? from,
    DateTime? to,
  }) async {
    final conditions = ['tenant_id = @tenant_id', 'user_id = @user_id'];
    final parameters = <String, dynamic>{'tenant_id': tenantId, 'user_id': userId};

    if (from != null) {
      conditions.add('work_date >= @from');
      parameters['from'] = from;
    }
    if (to != null) {
      conditions.add('work_date <= @to');
      parameters['to'] = to;
    }

    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns FROM time_entries '
        'WHERE ${conditions.join(' AND ')} '
        'ORDER BY work_date, created_at',
      ),
      parameters: parameters,
    );
    return result.map((row) => _fromRow(row.toColumnMap())).toList();
  }

  Future<TimeEntry?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM time_entries WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<TimeEntry?> update({
    required String tenantId,
    required String id,
    required UpdateTimeEntryRequest req,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE time_entries SET order_id = @order_id, work_date = @work_date, '
        'hours = @hours, description = @description '
        'WHERE tenant_id = @tenant_id AND id = @id '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'id': id,
        'order_id': req.orderId,
        'work_date': req.workDate,
        'hours': req.hours,
        'description': req.description,
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM time_entries WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  TimeEntry _fromRow(Map<String, dynamic> row) => TimeEntry(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        userId: row['user_id'] as String,
        orderId: row['order_id'] as String?,
        workDate: (row['work_date'] as DateTime).toUtc(),
        hours: (row['hours'] as num).toDouble(),
        description: row['description'] as String?,
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
