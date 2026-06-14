import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'number_sequence_repository.dart';

/// Wartungsverträge/Abos zwischen Mandant und Endkunde — eigenständige
/// Entität auf Ebene Mandant ↔ Endkunde (siehe [MaintenanceContract]).
/// `contractNumber` wird über den Nummernkreis "maintenance_contract"
/// (Prefix "W") vergeben.
class MaintenanceContractRepository {
  MaintenanceContractRepository(this._pool, this._numberSequences);

  final Pool<void> _pool;
  final NumberSequenceRepository _numberSequences;

  static const _columns = 'id, tenant_id, customer_id, contract_number, title, term_months, '
      'start_date, end_date, notice_period_months, max_penalty, status, cancelled_at, notes, created_at';

  Future<MaintenanceContract> create({
    required String tenantId,
    required CreateMaintenanceContractRequest req,
  }) async {
    final contractNumber = await _numberSequences.next(
      tenantId: tenantId,
      sequenceKey: 'maintenance_contract',
      defaultPrefix: 'W',
    );

    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO maintenance_contracts '
        '(tenant_id, customer_id, contract_number, title, term_months, start_date, end_date, '
        'notice_period_months, max_penalty, notes) '
        'VALUES (@tenant_id, @customer_id, @contract_number, @title, @term_months, @start_date, @end_date, '
        '@notice_period_months, @max_penalty, @notes) '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'customer_id': req.customerId,
        'contract_number': contractNumber,
        'title': req.title,
        'term_months': req.termMonths,
        'start_date': req.startDate,
        'end_date': req.endDate,
        'notice_period_months': req.noticePeriodMonths,
        'max_penalty': req.maxPenalty,
        'notes': req.notes,
      },
    );
    return _fromRow(result.first.toColumnMap());
  }

  Future<List<MaintenanceContract>> list(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns FROM maintenance_contracts WHERE tenant_id = @tenant_id ORDER BY created_at DESC',
      ),
      parameters: {'tenant_id': tenantId},
    );
    return result.map((row) => _fromRow(row.toColumnMap())).toList();
  }

  /// Wartungsverträge/Abos eines bestimmten Kunden — für die
  /// Kundenportal-Übersicht (`app_kunde`).
  Future<List<MaintenanceContract>> listForCustomer({required String tenantId, required String customerId}) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns FROM maintenance_contracts '
        'WHERE tenant_id = @tenant_id AND customer_id = @customer_id ORDER BY created_at DESC',
      ),
      parameters: {'tenant_id': tenantId, 'customer_id': customerId},
    );
    return result.map((row) => _fromRow(row.toColumnMap())).toList();
  }

  Future<MaintenanceContract?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM maintenance_contracts WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  /// Endkunde kündigt einen aktiven Wartungsvertrag im Kundenportal —
  /// `cancelled_at` wird auf das heutige Datum gesetzt. Liefert `null`, falls
  /// kein aktiver Vertrag mit dieser ID für diesen Kunden existiert (falscher
  /// Mandant/Kunde, unbekannte ID oder bereits gekündigt).
  Future<MaintenanceContract?> recordCustomerCancellation({
    required String tenantId,
    required String id,
    required String customerId,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE maintenance_contracts SET status = @status, cancelled_at = @cancelled_at '
        "WHERE tenant_id = @tenant_id AND id = @id AND customer_id = @customer_id AND status = 'active' "
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'id': id,
        'customer_id': customerId,
        'status': MaintenanceContractStatus.cancelled.toJson(),
        'cancelled_at': DateTime.now(),
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<MaintenanceContract?> update({
    required String tenantId,
    required String id,
    required UpdateMaintenanceContractRequest req,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE maintenance_contracts SET customer_id = @customer_id, title = @title, '
        'term_months = @term_months, start_date = @start_date, end_date = @end_date, '
        'notice_period_months = @notice_period_months, max_penalty = @max_penalty, '
        'status = @status, cancelled_at = @cancelled_at, notes = @notes '
        'WHERE tenant_id = @tenant_id AND id = @id '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'id': id,
        'customer_id': req.customerId,
        'title': req.title,
        'term_months': req.termMonths,
        'start_date': req.startDate,
        'end_date': req.endDate,
        'notice_period_months': req.noticePeriodMonths,
        'max_penalty': req.maxPenalty,
        'status': req.status.toJson(),
        'cancelled_at': req.cancelledAt,
        'notes': req.notes,
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM maintenance_contracts WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  MaintenanceContract _fromRow(Map<String, dynamic> row) => MaintenanceContract(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        customerId: row['customer_id'] as String,
        contractNumber: row['contract_number'] as String,
        title: row['title'] as String,
        termMonths: row['term_months'] as int,
        startDate: row['start_date'] as DateTime,
        endDate: row['end_date'] as DateTime,
        noticePeriodMonths: row['notice_period_months'] as int,
        maxPenalty: (row['max_penalty'] as num).toDouble(),
        status: MaintenanceContractStatus.fromJson(row['status'] as String),
        cancelledAt: row['cancelled_at'] as DateTime?,
        notes: row['notes'] as String?,
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
