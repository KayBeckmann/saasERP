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
        'RETURNING id, tenant_id, email, role, created_at',
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
        'SELECT id, tenant_id, email, role, created_at, password_hash '
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
        'SELECT id, tenant_id, email, role, created_at '
        'FROM users WHERE id = @id',
      ),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return _userFromRow(result.first.toColumnMap());
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
      );
}
