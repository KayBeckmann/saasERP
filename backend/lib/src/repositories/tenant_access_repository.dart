import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Verwaltet, welche Mandanten ein Nutzer sehen/auswählen darf
/// (Mandanten-/Tenant-Auswahl, Roadmap M1).
class TenantAccessRepository {
  TenantAccessRepository(this._pool);

  final Pool<void> _pool;

  /// Alle Mandanten, auf die der Nutzer Zugriff hat, samt Rolle dort.
  Future<List<TenantAccess>> listForUser(String userId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT t.id, t.name, t.created_at, uta.role '
        'FROM user_tenant_access uta '
        'JOIN tenants t ON t.id = uta.tenant_id '
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
        role: map['role'] as String,
      );
    }).toList();
  }

  /// Rolle des Nutzers im angegebenen Mandanten, oder `null` ohne Zugriff.
  Future<String?> roleForUserAndTenant({
    required String userId,
    required String tenantId,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT role FROM user_tenant_access '
        'WHERE user_id = @user_id AND tenant_id = @tenant_id',
      ),
      parameters: {'user_id': userId, 'tenant_id': tenantId},
    );
    if (result.isEmpty) return null;
    return result.first.toColumnMap()['role'] as String;
  }

  /// Räumt einem Nutzer Zugriff auf einen Mandanten ein (z. B. bei
  /// Registrierung als Owner-Zugang auf den neuen Mandanten).
  Future<void> grant({
    required String userId,
    required String tenantId,
    required String role,
  }) async {
    await _pool.execute(
      Sql.named(
        'INSERT INTO user_tenant_access (user_id, tenant_id, role) '
        'VALUES (@user_id, @tenant_id, @role) '
        'ON CONFLICT (user_id, tenant_id) DO UPDATE SET role = @role',
      ),
      parameters: {'user_id': userId, 'tenant_id': tenantId, 'role': role},
    );
  }
}
