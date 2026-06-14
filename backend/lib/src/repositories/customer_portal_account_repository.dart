import 'dart:convert';
import 'dart:math';

import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../config.dart';

/// Internes Lese-Modell für Auth-Checks — enthält zusätzlich den
/// Passwort-Hash, der niemals nach außen (API-Response) gegeben werden darf.
class CustomerPortalAccountWithPassword {
  CustomerPortalAccountWithPassword({required this.account, required this.passwordHash});

  final CustomerPortalAccount account;
  final String passwordHash;
}

/// Verwaltet Kundenportal-Zugänge (`customer_portal_accounts`) — je
/// `Customer` höchstens ein Zugang. Anlage durch den Mandanten (Einladung),
/// Passwortvergabe durch den Endkunden über den Einladungs-Token.
class CustomerPortalAccountRepository {
  CustomerPortalAccountRepository(this._pool, this._config);

  final Pool<void> _pool;
  final AppConfig _config;

  static const _columns = 'id, tenant_id, customer_id, email, invite_token, '
      'status, invited_at, activated_at, created_at';

  static final _random = Random.secure();

  String _generateInviteToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<CustomerPortalAccount> create({
    required String tenantId,
    required String customerId,
    required String email,
  }) async {
    final inviteToken = _generateInviteToken();
    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO customer_portal_accounts (tenant_id, customer_id, email, invite_token) '
        'VALUES (@tenant_id, @customer_id, @email, @invite_token) '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'customer_id': customerId,
        'email': email,
        'invite_token': inviteToken,
      },
    );
    return _fromRow(result.first.toColumnMap(), includeInvite: true);
  }

  /// Liest einen Zugang über seine ID — für authentifizierte
  /// Kundenportal-Routen (`auth.userId` ist die Account-ID des JWT).
  Future<CustomerPortalAccount?> findById(String id) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM customer_portal_accounts WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap(), includeInvite: false);
  }

  Future<CustomerPortalAccount?> findByCustomerId({
    required String tenantId,
    required String customerId,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns FROM customer_portal_accounts '
        'WHERE tenant_id = @tenant_id AND customer_id = @customer_id',
      ),
      parameters: {'tenant_id': tenantId, 'customer_id': customerId},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap(), includeInvite: true);
  }

  /// Liest einen Zugang über seinen Einladungs-Token (öffentlicher
  /// Einladungslink, kein Tenant-Scope erforderlich).
  Future<CustomerPortalAccount?> findByInviteToken(String inviteToken) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM customer_portal_accounts WHERE invite_token = @invite_token'),
      parameters: {'invite_token': inviteToken},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap(), includeInvite: true);
  }

  /// Liest einen aktiven Zugang (Passwort bereits vergeben) für den Login
  /// (`/api/customer-auth/login`). Bei mehreren Treffern (E-Mail ist nicht
  /// global eindeutig) wird der älteste Zugang verwendet.
  Future<CustomerPortalAccountWithPassword?> findByEmail(String email) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns, password_hash FROM customer_portal_accounts '
        "WHERE lower(email) = lower(@email) AND status = 'active' "
        'ORDER BY created_at LIMIT 1',
      ),
      parameters: {'email': email},
    );
    if (result.isEmpty) return null;
    final row = result.first.toColumnMap();
    return CustomerPortalAccountWithPassword(
      account: _fromRow(row, includeInvite: false),
      passwordHash: row['password_hash'] as String,
    );
  }

  /// Vergibt das Passwort über den Einladungs-Token und aktiviert den
  /// Zugang. Gibt `null` zurück, wenn der Token unbekannt oder bereits
  /// verwendet (`status != invited`) ist.
  Future<CustomerPortalAccount?> acceptInvite({
    required String inviteToken,
    required String passwordHash,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE customer_portal_accounts '
        'SET password_hash = @password_hash, status = @status, activated_at = now() '
        "WHERE invite_token = @invite_token AND status = 'invited' "
        'RETURNING $_columns',
      ),
      parameters: {
        'invite_token': inviteToken,
        'password_hash': passwordHash,
        'status': CustomerPortalAccountStatus.active.toJson(),
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap(), includeInvite: false);
  }

  Future<bool> delete({required String tenantId, required String customerId}) async {
    final result = await _pool.execute(
      Sql.named(
        'DELETE FROM customer_portal_accounts WHERE tenant_id = @tenant_id AND customer_id = @customer_id',
      ),
      parameters: {'tenant_id': tenantId, 'customer_id': customerId},
    );
    return result.affectedRows > 0;
  }

  CustomerPortalAccount _fromRow(Map<String, dynamic> row, {required bool includeInvite}) {
    final status = CustomerPortalAccountStatus.fromJson(row['status'] as String);
    final inviteToken = row['invite_token'] as String;
    final showInvite = includeInvite && status == CustomerPortalAccountStatus.invited;
    return CustomerPortalAccount(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      customerId: row['customer_id'] as String,
      email: row['email'] as String,
      status: status,
      invitedAt: (row['invited_at'] as DateTime).toUtc(),
      activatedAt: (row['activated_at'] as DateTime?)?.toUtc(),
      createdAt: (row['created_at'] as DateTime).toUtc(),
      inviteToken: showInvite ? inviteToken : null,
      inviteUrl: showInvite ? '${_config.appKundeUrl}/invite/$inviteToken' : null,
    );
  }
}
