import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Die wirksame Berechtigungslage eines Nutzers in einem Mandanten zum
/// Zeitpunkt der Anfrage — immer frisch aus der DB gelesen (siehe
/// [AuthorizationService.loadContext]), nie aus dem JWT übernommen. Das
/// macht Rollenwechsel "sofort wirksam" (Roadmap RF2), ohne Session-
/// Versionierung/Invalidierung im Token zu brauchen.
class AuthorizationContext {
  const AuthorizationContext({
    required this.userId,
    required this.tenantId,
    required this.roleId,
    required this.roleName,
    required this.isAdminRole,
    required this.permissions,
  });

  final String userId;
  final String tenantId;
  final String roleId;
  final String roleName;
  final bool isAdminRole;
  final Set<String> permissions; // "module:action"

  bool can(String module, String action) =>
      isAdminRole || permissions.contains('$module:$action');
}

/// Prüft modul-/aktionsbezogene Rechte vor jedem Datenzugriff (RF2: "Backend
/// autorisiert vor jeder Entschlüsselung"). Deny-by-default: ohne
/// Mandantenzugriff oder ohne passende `role_permissions`-Zeile wird
/// abgelehnt.
class AuthorizationService {
  AuthorizationService(this._pool);

  final Pool<void> _pool;

  Future<AuthorizationContext?> loadContext({
    required String userId,
    required String tenantId,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT r.id AS role_id, r.name AS role_name, r.is_admin_role '
        'FROM user_tenant_access uta '
        'JOIN roles r ON r.id = uta.role_id '
        'WHERE uta.user_id = @user_id AND uta.tenant_id = @tenant_id',
      ),
      parameters: {'user_id': userId, 'tenant_id': tenantId},
    );
    if (result.isEmpty) return null;
    final row = result.first.toColumnMap();
    final roleId = row['role_id'] as String;
    final isAdminRole = row['is_admin_role'] as bool;

    // Admin-Rollen brauchen keine role_permissions-Zeilen geladen zu werden
    // (can() gibt für is_admin_role immer true zurück) — spart eine Abfrage
    // für den häufigen Fall des Mandanten-Owners.
    Set<String> permissions = const {};
    if (!isAdminRole) {
      final permRows = await _pool.execute(
        Sql.named('SELECT module, action FROM role_permissions WHERE role_id = @role_id'),
        parameters: {'role_id': roleId},
      );
      permissions = permRows
          .map((r) => r.toColumnMap())
          .map((m) => '${m['module']}:${m['action']}')
          .toSet();
    }

    return AuthorizationContext(
      userId: userId,
      tenantId: tenantId,
      roleId: roleId,
      roleName: row['role_name'] as String,
      isAdminRole: isAdminRole,
      permissions: permissions,
    );
  }
}
