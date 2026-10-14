import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Verwaltet, welche Mandanten ein Nutzer sehen/auswählen darf und mit
/// welcher Rolle (Roadmap M1 Tenant-Auswahl + RF2 Rollen).
class TenantAccessRepository {
  TenantAccessRepository(this._pool);

  final Pool<void> _pool;

  /// Alle Mandanten, auf die der Nutzer Zugriff hat, samt Rollenname dort
  /// (nur zur Anzeige — für Autorisierungsentscheidungen immer
  /// `AuthorizationService` verwenden, nie diesen String).
  Future<List<TenantAccess>> listForUser(String userId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT t.id, t.name, t.created_at, r.name AS role_name '
        'FROM user_tenant_access uta '
        'JOIN tenants t ON t.id = uta.tenant_id '
        'LEFT JOIN roles r ON r.id = uta.role_id '
        'WHERE uta.user_id = @user_id '
        'ORDER BY t.name',
      ),
      parameters: {'user_id': userId},
    );
    return result.map((row) {
      final map = row.toColumnMap();
      return TenantAccess(
        tenant: Tenant(
          id: map['id'] as String,
          name: map['name'] as String,
          createdAt: (map['created_at'] as DateTime).toUtc(),
        ),
        role: map['role_name'] as String? ?? 'unbekannt',
      );
    }).toList();
  }

  /// Rollenname des Nutzers im angegebenen Mandanten (nur Anzeige/JWT-
  /// Metadaten), oder `null` ohne Zugriff.
  Future<String?> roleNameForUserAndTenant({
    required String userId,
    required String tenantId,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT r.name FROM user_tenant_access uta '
        'JOIN roles r ON r.id = uta.role_id '
        'WHERE uta.user_id = @user_id AND uta.tenant_id = @tenant_id',
      ),
      parameters: {'user_id': userId, 'tenant_id': tenantId},
    );
    if (result.isEmpty) return null;
    return result.first.toColumnMap()['name'] as String;
  }

  /// Rollen-ID des Nutzers im angegebenen Mandanten — Grundlage für
  /// `AuthorizationService`. `null` ohne Zugriff.
  Future<String?> roleIdForUserAndTenant({
    required String userId,
    required String tenantId,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT role_id FROM user_tenant_access '
        'WHERE user_id = @user_id AND tenant_id = @tenant_id',
      ),
      parameters: {'user_id': userId, 'tenant_id': tenantId},
    );
    if (result.isEmpty) return null;
    return result.first.toColumnMap()['role_id'] as String?;
  }

  /// Räumt einem Nutzer Zugriff auf einen Mandanten mit einer bestimmten
  /// Rolle ein (z. B. bei Registrierung als Admin-Zugang auf den neuen
  /// Mandanten, oder beim Einladen eines Mitglieds).
  Future<void> grant({
    required String userId,
    required String tenantId,
    required String roleId,
  }) async {
    await _pool.execute(
      Sql.named(
        'INSERT INTO user_tenant_access (user_id, tenant_id, role_id) '
        'VALUES (@user_id, @tenant_id, @role_id) '
        'ON CONFLICT (user_id, tenant_id) DO UPDATE SET role_id = @role_id',
      ),
      parameters: {'user_id': userId, 'tenant_id': tenantId, 'role_id': roleId},
    );
  }

  /// Mitglieder eines Mandanten samt Rolle (Mitgliederverwaltung, RF2).
  Future<List<TenantMember>> listMembers(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT u.id AS user_id, u.email, r.id AS role_id, r.name AS role_name, uta.created_at '
        'FROM user_tenant_access uta '
        'JOIN users u ON u.id = uta.user_id '
        'JOIN roles r ON r.id = uta.role_id '
        'WHERE uta.tenant_id = @tenant_id '
        'ORDER BY uta.created_at ASC',
      ),
      parameters: {'tenant_id': tenantId},
    );
    return result.map((row) => TenantMember.fromJson(_memberRowToJson(row.toColumnMap()))).toList();
  }

  Map<String, dynamic> _memberRowToJson(Map<String, dynamic> row) => {
        'user_id': row['user_id'] as String,
        'email': row['email'] as String,
        'role_id': row['role_id'] as String,
        'role_name': row['role_name'] as String,
        'created_at': (row['created_at'] as DateTime).toUtc().toIso8601String(),
      };
}
