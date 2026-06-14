import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Sonstige Einnahmen/Ausgaben eines Projekts ohne eigenen Beleg (z. B.
/// Zuschüsse, Spesen) — fließen in die Gewinn/Verlust-Übersicht ein.
class ProjectTransactionRepository {
  ProjectTransactionRepository(this._pool);

  final Pool<void> _pool;

  static const _columns =
      'id, tenant_id, project_id, kind, description, amount, transaction_date, created_at';

  Future<ProjectTransaction> create({
    required String tenantId,
    required String projectId,
    required CreateProjectTransactionRequest req,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO project_transactions (tenant_id, project_id, kind, description, amount, transaction_date) '
        'VALUES (@tenant_id, @project_id, @kind, @description, @amount, @transaction_date) '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'project_id': projectId,
        'kind': req.kind.toJson(),
        'description': req.description,
        'amount': req.amount,
        'transaction_date': req.transactionDate,
      },
    );
    return _fromRow(result.first.toColumnMap());
  }

  Future<List<ProjectTransaction>> list({required String tenantId, required String projectId}) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns FROM project_transactions '
        'WHERE tenant_id = @tenant_id AND project_id = @project_id '
        'ORDER BY transaction_date DESC, created_at DESC',
      ),
      parameters: {'tenant_id': tenantId, 'project_id': projectId},
    );
    return result.map((row) => _fromRow(row.toColumnMap())).toList();
  }

  Future<ProjectTransaction?> update({
    required String tenantId,
    required String projectId,
    required String id,
    required UpdateProjectTransactionRequest req,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE project_transactions SET kind = @kind, description = @description, '
        'amount = @amount, transaction_date = @transaction_date '
        'WHERE tenant_id = @tenant_id AND project_id = @project_id AND id = @id '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'project_id': projectId,
        'id': id,
        'kind': req.kind.toJson(),
        'description': req.description,
        'amount': req.amount,
        'transaction_date': req.transactionDate,
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<bool> delete({required String tenantId, required String projectId, required String id}) async {
    final result = await _pool.execute(
      Sql.named(
        'DELETE FROM project_transactions '
        'WHERE tenant_id = @tenant_id AND project_id = @project_id AND id = @id',
      ),
      parameters: {'tenant_id': tenantId, 'project_id': projectId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  /// Summe der Beträge eines Projekts für [kind] (income/expense) — Basis
  /// für die "sonstigen Einnahmen/Ausgaben" der Gewinn/Verlust-Übersicht.
  Future<double> sumByKind({
    required String tenantId,
    required String projectId,
    required ProjectTransactionKind kind,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM project_transactions '
        'WHERE tenant_id = @tenant_id AND project_id = @project_id AND kind = @kind',
      ),
      parameters: {'tenant_id': tenantId, 'project_id': projectId, 'kind': kind.toJson()},
    );
    return (result.first.toColumnMap()['total'] as num).toDouble();
  }

  ProjectTransaction _fromRow(Map<String, dynamic> row) => ProjectTransaction(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        projectId: row['project_id'] as String,
        kind: ProjectTransactionKind.fromJson(row['kind'] as String),
        description: row['description'] as String,
        amount: (row['amount'] as num).toDouble(),
        transactionDate: (row['transaction_date'] as DateTime).toUtc(),
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
