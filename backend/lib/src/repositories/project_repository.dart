import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'number_sequence_repository.dart';

/// Projekte — bündeln optional mehrere Aufträge, Bestellungen und
/// Stundenerfassungen (Verhältnis Projekt ↔ Auftrag ist 1:n).
/// `projectNumber` wird über den Nummernkreis "project" (Prefix "P") vergeben.
class ProjectRepository {
  ProjectRepository(this._pool, this._numberSequences);

  final Pool<void> _pool;
  final NumberSequenceRepository _numberSequences;

  static const _columns = 'id, tenant_id, project_number, name, customer_id, status, notes, created_at';

  Future<Project> create({
    required String tenantId,
    required CreateProjectRequest req,
  }) async {
    final projectNumber = await _numberSequences.next(
      tenantId: tenantId,
      sequenceKey: 'project',
      defaultPrefix: 'P',
    );

    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO projects (tenant_id, project_number, name, customer_id, notes) '
        'VALUES (@tenant_id, @project_number, @name, @customer_id, @notes) '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'project_number': projectNumber,
        'name': req.name,
        'customer_id': req.customerId,
        'notes': req.notes,
      },
    );
    return _fromRow(result.first.toColumnMap());
  }

  Future<List<Project>> list(String tenantId) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM projects WHERE tenant_id = @tenant_id ORDER BY created_at DESC'),
      parameters: {'tenant_id': tenantId},
    );
    return result.map((row) => _fromRow(row.toColumnMap())).toList();
  }

  Future<Project?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM projects WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<Project?> update({
    required String tenantId,
    required String id,
    required UpdateProjectRequest req,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE projects SET name = @name, customer_id = @customer_id, status = @status, notes = @notes '
        'WHERE tenant_id = @tenant_id AND id = @id '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'id': id,
        'name': req.name,
        'customer_id': req.customerId,
        'status': req.status.toJson(),
        'notes': req.notes,
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<bool> delete({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('DELETE FROM projects WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  /// Netto-Summe aller Positionen von Bestellungen, die [projectId]
  /// zugeordnet sind — Ausgaben-Seite der Gewinn/Verlust-Übersicht.
  Future<double> sumPurchaseExpenses({required String tenantId, required String projectId}) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT COALESCE(SUM(poi.quantity * poi.unit_price), 0) AS total '
        'FROM purchase_order_items poi '
        'JOIN purchase_orders po ON po.id = poi.purchase_order_id '
        'WHERE po.tenant_id = @tenant_id AND po.project_id = @project_id',
      ),
      parameters: {'tenant_id': tenantId, 'project_id': projectId},
    );
    return (result.first.toColumnMap()['total'] as num).toDouble();
  }

  /// Summe der erfassten Stunden, die [projectId] zugeordnet sind — Basis
  /// für die Stundenkosten der Gewinn/Verlust-Übersicht.
  Future<double> sumLaborHours({required String tenantId, required String projectId}) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT COALESCE(SUM(hours), 0) AS total FROM time_entries '
        'WHERE tenant_id = @tenant_id AND project_id = @project_id',
      ),
      parameters: {'tenant_id': tenantId, 'project_id': projectId},
    );
    return (result.first.toColumnMap()['total'] as num).toDouble();
  }

  Project _fromRow(Map<String, dynamic> row) => Project(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        projectNumber: row['project_number'] as String,
        name: row['name'] as String,
        customerId: row['customer_id'] as String?,
        status: ProjectStatus.fromJson(row['status'] as String),
        notes: row['notes'] as String?,
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
