import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Internes Lese-Modell für Auth-Checks — enthält zusätzlich den Passwort-Hash,
/// der niemals nach außen (API-Response) gegeben werden darf.
class UserWithPassword {
  UserWithPassword({required this.user, required this.passwordHash});

  final AppUser user;
  final String passwordHash;
}

class UserRepository {
  UserRepository(this._pool);

  final Pool<void> _pool;

  static const _columns = 'id, tenant_id, email, role, created_at, is_platform_admin';

  Future<AppUser> create({
    required String tenantId,
    required String email,
    required String passwordHash,
    required UserRole role,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO users (tenant_id, email, password_hash, role) '
        'VALUES (@tenant_id, @email, @password_hash, @role) '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'email': email,
        'password_hash': passwordHash,
        'role': role.toJson(),
      },
    );
    return _userFromRow(result.first.toColumnMap());
  }

  Future<UserWithPassword?> findByEmail(String email) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns, password_hash '
        'FROM users WHERE lower(email) = lower(@email)',
      ),
      parameters: {'email': email},
    );
    if (result.isEmpty) return null;
    final row = result.first.toColumnMap();
    return UserWithPassword(
      user: _userFromRow(row),
      passwordHash: row['password_hash'] as String,
    );
  }

  Future<AppUser?> findById(String id) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns '
        'FROM users WHERE id = @id',
      ),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return _userFromRow(result.first.toColumnMap());
  }

  /// Alle Benutzer eines Mandanten (via user_tenant_access), geordnet nach Erstelldatum.
  Future<List<AppUser>> listForTenant(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT u.id, u.tenant_id, u.email, uta.role, u.created_at, u.is_platform_admin '
        'FROM users u '
        'JOIN user_tenant_access uta ON uta.user_id = u.id '
        'WHERE uta.tenant_id = @tenant_id '
        'ORDER BY u.created_at ASC',
      ),
      parameters: {'tenant_id': tenantId},
    );
    return result.map((r) => _userFromRow(r.toColumnMap())).toList();
  }

  /// Aktualisiert den Passwort-Hash eines Benutzers.
  Future<void> updatePassword({
    required String userId,
    required String newPasswordHash,
  }) async {
    await _pool.execute(
      Sql.named(
        'UPDATE users SET password_hash = @hash WHERE id = @id',
      ),
      parameters: {'id': userId, 'hash': newPasswordHash},
    );
  }

  /// Entfernt einen Benutzer aus einem Mandanten (user_tenant_access löschen).
  /// Gibt `true` zurück wenn die Zeile existiert hat, sonst `false`.
  Future<bool> removeFromTenant({
    required String userId,
    required String tenantId,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'DELETE FROM user_tenant_access '
        'WHERE user_id = @user_id AND tenant_id = @tenant_id '
        'RETURNING user_id',
      ),
      parameters: {'user_id': userId, 'tenant_id': tenantId},
    );
    return result.isNotEmpty;
  }

  /// E-Mail-Adresse des Inhabers (`role = 'owner'`) eines Mandanten — für
  /// Benachrichtigungen über Status-Änderungen (z. B. Kundenentscheidung zu
  /// einem Angebot). `null`, falls kein Owner-Zugang existiert.
  Future<String?> findOwnerEmail(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT u.email FROM users u '
        'JOIN user_tenant_access uta ON uta.user_id = u.id '
        "WHERE uta.tenant_id = @tenant_id AND uta.role = 'owner' "
        'ORDER BY u.created_at ASC LIMIT 1',
      ),
      parameters: {'tenant_id': tenantId},
    );
    if (result.isEmpty) return null;
    return result.first.toColumnMap()['email'] as String;
  }

  AppUser _userFromRow(Map<String, dynamic> row) => AppUser(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        email: row['email'] as String,
        role: UserRole.fromJson(row['role'] as String),
        createdAt: (row['created_at'] as DateTime).toUtc(),
        isPlatformAdmin: row['is_platform_admin'] as bool? ?? false,
      );
}
