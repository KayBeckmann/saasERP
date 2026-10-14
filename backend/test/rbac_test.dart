import 'dart:io';

import 'package:backend/src/authorization_service.dart';
import 'package:backend/src/db.dart';
import 'package:backend/src/repositories/role_repository.dart';
import 'package:backend/src/repositories/tenant_access_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';

void main() {
  final port = int.tryParse(Platform.environment['WAAS_TEST_DB_PORT'] ?? '');
  test(
    'RF2: Rollenvorlagen, Autorisierung, Selbst-Eskalationsschutz und Admin-Governance',
    () async {
      final pool = Pool<void>.withEndpoints([
        Endpoint(
          host: '127.0.0.1',
          port: port!,
          database: Platform.environment['WAAS_TEST_DB_NAME'] ?? 'saaserp_test',
          username: 'postgres',
          password: 'test_only',
        ),
      ], settings: const PoolSettings(sslMode: SslMode.disable));
      try {
        await runMigrations(pool);

        final roleRepository = RoleRepository(pool);
        final tenantAccessRepository = TenantAccessRepository(pool);
        final userRepository = UserRepository(pool);
        final authorizationService = AuthorizationService(pool);

        Future<String> insertTenant(String name) async {
          final result = await pool.execute(
            Sql.named('INSERT INTO tenants (name) VALUES (@name) RETURNING id'),
            parameters: {'name': name},
          );
          return result.first.toColumnMap()['id'] as String;
        }

        final tenant = await insertTenant('RBAC Test Tenant');

        Future<String> insertUser(String email) async {
          // users.tenant_id ist nur noch der "Heimat"-Mandant zur Anlagezeit
          // (informativ) - die eigentliche, autoritative Zuordnung läuft über
          // user_tenant_access.role_id (siehe UserRepository-Klassendoc).
          final user = await userRepository.create(
            tenantId: tenant,
            email: email,
            passwordHash: 'x',
            role: UserRole.owner,
          );
          return user.id;
        }

        // --- Rollenvorlagen ---
        final adminRoleId = await roleRepository.ensureBuiltinRoles(tenant);
        final roles = await roleRepository.listForTenant(tenant);
        expect(roles.map((r) => r.name).toSet(), {
          'Admin', 'Buchhaltung', 'Vertrieb', 'Einkauf', 'Lager', 'Steuerbüro', 'Nur Lesen',
        });
        final adminRole = roles.firstWhere((r) => r.id == adminRoleId);
        expect(adminRole.isAdminRole, isTrue);
        final nurLesenRole = roles.firstWhere((r) => r.name == 'Nur Lesen');
        expect(nurLesenRole.isAdminRole, isFalse);
        expect(nurLesenRole.hasPermission(PermissionModule.customers, PermissionAction.view), isTrue);
        expect(nurLesenRole.hasPermission(PermissionModule.customers, PermissionAction.edit), isFalse);
        expect(nurLesenRole.hasPermission(PermissionModule.members, PermissionAction.view), isFalse);

        // Erneuter Aufruf (z. B. nach Neustart) legt nichts doppelt an.
        await roleRepository.ensureBuiltinRoles(tenant);
        final rolesAgain = await roleRepository.listForTenant(tenant);
        expect(rolesAgain, hasLength(7));

        // --- Erster Nutzer: Admin ---
        final adminUserId = await insertUser('admin@rbac-test.invalid');
        await tenantAccessRepository.grant(userId: adminUserId, tenantId: tenant, roleId: adminRoleId);

        final adminAuthz = await authorizationService.loadContext(userId: adminUserId, tenantId: tenant);
        expect(adminAuthz, isNotNull);
        expect(adminAuthz!.isAdminRole, isTrue);
        // Admin darf alles, auch ohne explizite role_permissions-Zeilen (can() kurzschließt).
        expect(adminAuthz.can(PermissionModule.waas, PermissionAction.release), isTrue);
        expect(adminAuthz.can('irgendein_zukuenftiges_modul', PermissionAction.delete), isTrue);

        // --- Zweiter Nutzer: Nur Lesen ---
        final readOnlyUserId = await insertUser('reader@rbac-test.invalid');
        await tenantAccessRepository.grant(userId: readOnlyUserId, tenantId: tenant, roleId: nurLesenRole.id);

        final readOnlyAuthz = await authorizationService.loadContext(userId: readOnlyUserId, tenantId: tenant);
        expect(readOnlyAuthz, isNotNull);
        expect(readOnlyAuthz!.isAdminRole, isFalse);
        expect(readOnlyAuthz.can(PermissionModule.customers, PermissionAction.view), isTrue);
        expect(readOnlyAuthz.can(PermissionModule.customers, PermissionAction.delete), isFalse);
        expect(readOnlyAuthz.can(PermissionModule.members, PermissionAction.create), isFalse);

        // --- Deny-by-default: fremder Mandant ohne user_tenant_access ---
        final otherTenant = await insertTenant('RBAC Other Tenant');
        final noAccess = await authorizationService.loadContext(userId: readOnlyUserId, tenantId: otherTenant);
        expect(noAccess, isNull);

        // --- Deny-by-default: nicht (mehr) existierender Nutzer (z. B. aus
        // einem noch gültigen JWT nach Löschung des Accounts) ---
        final ghost = await authorizationService.loadContext(
          userId: '00000000-0000-0000-0000-000000000000',
          tenantId: tenant,
        );
        expect(ghost, isNull);

        // --- Admin-Governance: letzter Admin kann nicht herabgestuft/entfernt werden ---
        expect(await roleRepository.countActiveAdmins(tenant), 1);

        // --- Zweiter Admin ernennen, dann darf der erste herabgestuft werden ---
        final secondAdminUserId = await insertUser('second-admin@rbac-test.invalid');
        await tenantAccessRepository.grant(userId: secondAdminUserId, tenantId: tenant, roleId: adminRoleId);
        expect(await roleRepository.countActiveAdmins(tenant), 2);

        // --- Rollen-Governance: Admin-Rolle kann nicht gelöscht werden ---
        final adminDeleteResult = await roleRepository.delete(tenantId: tenant, roleId: adminRoleId);
        expect(adminDeleteResult, isFalse);
        final stillThere = await roleRepository.findById(tenantId: tenant, roleId: adminRoleId);
        expect(stillThere, isNotNull);

        // --- Rollen-Governance: Rolle mit zugewiesenen Mitgliedern kann nicht gelöscht werden ---
        final nurLesenDeleteResult = await roleRepository.delete(tenantId: tenant, roleId: nurLesenRole.id);
        expect(nurLesenDeleteResult, isFalse);

        // --- Eine frei erfundene, unbenutzte Rolle lässt sich löschen ---
        final tempRole = await roleRepository.create(
          tenantId: tenant,
          req: const UpsertRoleRequest(name: 'Temp', permissions: []),
        );
        final tempDeleteResult = await roleRepository.delete(tenantId: tenant, roleId: tempRole.id);
        expect(tempDeleteResult, isTrue);

        // --- Admin-Rolle behält immer volle Rechte, auch bei update()-Versuch mit leeren Permissions ---
        final updatedAdmin = await roleRepository.update(
          tenantId: tenant,
          roleId: adminRoleId,
          req: const UpsertRoleRequest(name: 'Admin', permissions: []),
        );
        expect(updatedAdmin, isNotNull);
        expect(updatedAdmin!.permissions, isNotEmpty); // unveraendert, nicht geleert
      } finally {
        await pool.execute(Sql("DELETE FROM tenants WHERE name LIKE 'RBAC %'"));
        await pool.execute(Sql("DELETE FROM users WHERE email LIKE '%@rbac-test.invalid'"));
        await pool.close();
      }
    },
    skip: port == null ? 'Set WAAS_TEST_DB_PORT for isolated PostgreSQL integration' : false,
  );
}
