import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:uuid/uuid.dart';

import '../role_templates.dart';

/// Verwaltet mandantenfähige Rollen und ihre Berechtigungen (RF2).
class RoleRepository {
  RoleRepository(this._pool);

  final Pool<void> _pool;
  static const _uuid = Uuid();

  /// Legt die eingebauten Rollenvorlagen für einen neuen Mandanten an
  /// (idempotent — `ON CONFLICT DO NOTHING` auf den eindeutigen
  /// `(tenant_id, name)`). Wird bei der Registrierung aufgerufen. Gibt die
  /// ID der Admin-Rolle zurück (für die Zuweisung an den Owner).
  Future<String> ensureBuiltinRoles(String tenantId) async {
    String? adminRoleId;
    for (final template in builtinRoleTemplates) {
      final roleId = _uuid.v4();
      final result = await _pool.execute(
        Sql.named(
          'INSERT INTO roles (id, tenant_id, name, is_builtin, is_admin_role) '
          'VALUES (@id, @tenant_id, @name, TRUE, @is_admin_role) '
          'ON CONFLICT (tenant_id, name) DO UPDATE SET name = EXCLUDED.name '
          'RETURNING id, is_admin_role',
        ),
        parameters: {
          'id': roleId,
          'tenant_id': tenantId,
          'name': template.name,
          'is_admin_role': template.isAdminRole,
        },
      );
      final row = result.first.toColumnMap();
      final actualId = row['id'] as String;
      if (row['is_admin_role'] as bool) adminRoleId = actualId;

      // Berechtigungen nur setzen, wenn die Rolle gerade NEU angelegt wurde
      // (actualId == roleId bedeutet: kein Konflikt, frischer Insert) —
      // bei einer bereits bestehenden Rolle bleiben ggf. vom Mandanten-Admin
      // angepasste Berechtigungen unangetastet ("anpassbare Rollen").
      if (actualId == roleId) {
        for (final permission in template.permissions) {
          await _pool.execute(
            Sql.named(
              'INSERT INTO role_permissions (role_id, module, action) '
              'VALUES (@role_id, @module, @action) ON CONFLICT DO NOTHING',
            ),
            parameters: {'role_id': actualId, 'module': permission.module, 'action': permission.action},
          );
        }
      }
    }
    if (adminRoleId == null) {
      // Admin-Rolle existierte schon vor diesem Aufruf (z. B. erneuter
      // Login-Seed-Lauf) — ID separat nachschlagen.
      final result = await _pool.execute(
        Sql.named(
          "SELECT id FROM roles WHERE tenant_id = @tenant_id AND is_admin_role = TRUE LIMIT 1",
        ),
        parameters: {'tenant_id': tenantId},
      );
      adminRoleId = result.first.toColumnMap()['id'] as String;
    }
    return adminRoleId;
  }

  Future<List<Role>> listForTenant(String tenantId) async {
    final roleRows = await _pool.execute(
      Sql.named(
        'SELECT id, tenant_id, name, is_builtin, is_admin_role, created_at '
        'FROM roles WHERE tenant_id = @tenant_id ORDER BY is_admin_role DESC, name',
      ),
      parameters: {'tenant_id': tenantId},
    );
    final roles = <Role>[];
    for (final row in roleRows) {
      final map = row.toColumnMap();
      final roleId = map['id'] as String;
      final permissions = await _permissionsForRole(roleId);
      roles.add(_roleFromRow(map, permissions));
    }
    return roles;
  }

  Future<Role?> findById({required String tenantId, required String roleId}) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT id, tenant_id, name, is_builtin, is_admin_role, created_at '
        'FROM roles WHERE tenant_id = @tenant_id AND id = @id',
      ),
      parameters: {'tenant_id': tenantId, 'id': roleId},
    );
    if (result.isEmpty) return null;
    final permissions = await _permissionsForRole(roleId);
    return _roleFromRow(result.first.toColumnMap(), permissions);
  }

  Future<Role> create({required String tenantId, required UpsertRoleRequest req}) async {
    final roleId = _uuid.v4();
    await _pool.execute(
      Sql.named(
        'INSERT INTO roles (id, tenant_id, name, is_builtin, is_admin_role) '
        'VALUES (@id, @tenant_id, @name, FALSE, FALSE)',
      ),
      parameters: {'id': roleId, 'tenant_id': tenantId, 'name': req.name},
    );
    await _setPermissions(roleId, req.permissions);
    return (await findById(tenantId: tenantId, roleId: roleId))!;
  }

  /// Aktualisiert Name/Berechtigungen einer Rolle. Die Admin-Rolle kann
  /// umbenannt, aber ihre Berechtigungen können nicht auf "nicht alles"
  /// reduziert werden (Governance — sonst könnte ein Admin sich selbst oder
  /// alle Admins aussperren).
  Future<Role?> update({
    required String tenantId,
    required String roleId,
    required UpsertRoleRequest req,
  }) async {
    final existing = await findById(tenantId: tenantId, roleId: roleId);
    if (existing == null) return null;
    await _pool.execute(
      Sql.named('UPDATE roles SET name = @name WHERE id = @id AND tenant_id = @tenant_id'),
      parameters: {'id': roleId, 'tenant_id': tenantId, 'name': req.name},
    );
    if (existing.isAdminRole) {
      // Admin-Rolle behält immer volle Rechte — siehe Klassendoc.
      return existing;
    }
    await _setPermissions(roleId, req.permissions);
    return (await findById(tenantId: tenantId, roleId: roleId))!;
  }

  /// Löscht eine anpassbare Rolle. Schlägt fehl (gibt `false` zurück), wenn
  /// die Rolle die Admin-Rolle ist oder noch Mitglieder zugewiesen sind
  /// (verhindert verwaiste Mitgliedschaften).
  Future<bool> delete({required String tenantId, required String roleId}) async {
    final role = await findById(tenantId: tenantId, roleId: roleId);
    if (role == null || role.isAdminRole) return false;
    final inUse = await _pool.execute(
      Sql.named('SELECT 1 FROM user_tenant_access WHERE role_id = @role_id LIMIT 1'),
      parameters: {'role_id': roleId},
    );
    if (inUse.isNotEmpty) return false;
    await _pool.execute(
      Sql.named('DELETE FROM roles WHERE id = @id AND tenant_id = @tenant_id'),
      parameters: {'id': roleId, 'tenant_id': tenantId},
    );
    return true;
  }

  Future<int> countActiveAdmins(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT COUNT(*) AS n FROM user_tenant_access uta '
        'JOIN roles r ON r.id = uta.role_id '
        'WHERE uta.tenant_id = @tenant_id AND r.is_admin_role = TRUE',
      ),
      parameters: {'tenant_id': tenantId},
    );
    return result.first.toColumnMap()['n'] as int;
  }

  Future<List<RolePermission>> _permissionsForRole(String roleId) async {
    final result = await _pool.execute(
      Sql.named('SELECT module, action FROM role_permissions WHERE role_id = @role_id'),
      parameters: {'role_id': roleId},
    );
    return result
        .map((r) => r.toColumnMap())
        .map((m) => RolePermission(module: m['module'] as String, action: m['action'] as String))
        .toList();
  }

  Future<void> _setPermissions(String roleId, List<RolePermission> permissions) async {
    await _pool.execute(
      Sql.named('DELETE FROM role_permissions WHERE role_id = @role_id'),
      parameters: {'role_id': roleId},
    );
    for (final permission in permissions) {
      await _pool.execute(
        Sql.named(
          'INSERT INTO role_permissions (role_id, module, action) VALUES (@role_id, @module, @action)',
        ),
        parameters: {'role_id': roleId, 'module': permission.module, 'action': permission.action},
      );
    }
  }

  Role _roleFromRow(Map<String, dynamic> row, List<RolePermission> permissions) => Role(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        name: row['name'] as String,
        isBuiltin: row['is_builtin'] as bool,
        isAdminRole: row['is_admin_role'] as bool,
        createdAt: (row['created_at'] as DateTime).toUtc(),
        permissions: permissions,
      );
}
