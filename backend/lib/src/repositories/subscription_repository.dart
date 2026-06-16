import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Abos der saasERP-Mandanten beim Plattform-Betreiber (M3). 1:n je Mandant —
/// Historie aus Neuabschluss/Tier-Wechsel/Kündigung; das aktuelle Abo ist das
/// mit `status: active`.
class SubscriptionRepository {
  SubscriptionRepository(this._pool);

  final Pool<void> _pool;

  static const _columns = 'id, tenant_id, tier_id, payment_rhythm, payment_method, term_months, '
      'start_date, end_date, down_payment, max_penalty, status, cancelled_at, notes, created_at';

  Future<List<Subscription>> listForTenant(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns FROM subscriptions '
        'WHERE tenant_id = @tenant_id '
        'ORDER BY created_at DESC',
      ),
      parameters: {'tenant_id': tenantId},
    );
    return result.map((row) => _fromRow(row.toColumnMap())).toList();
  }

  /// Das aktuelle Abo eines Mandanten (`status = 'active'`) — Grundlage für
  /// die Self-Service-Routen (`/api/subscription/*`). Liefert `null`, wenn
  /// (noch) kein Abo angelegt wurde.
  Future<Subscription?> findActiveForTenant(String tenantId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_columns FROM subscriptions '
        "WHERE tenant_id = @tenant_id AND status = 'active'",
      ),
      parameters: {'tenant_id': tenantId},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<Subscription?> findById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM subscriptions WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  Future<Subscription> create({required String tenantId, required CreateSubscriptionRequest req}) async {
    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO subscriptions (tenant_id, tier_id, payment_rhythm, payment_method, term_months, '
        'start_date, end_date, down_payment, max_penalty, notes) '
        'VALUES (@tenant_id, @tier_id, @payment_rhythm, @payment_method, @term_months, '
        '@start_date, @end_date, @down_payment, @max_penalty, @notes) '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'tier_id': req.tierId,
        'payment_rhythm': req.paymentRhythm.toJson(),
        'payment_method': req.paymentMethod.toJson(),
        'term_months': req.termMonths,
        'start_date': req.startDate,
        'end_date': req.endDate,
        'down_payment': req.downPayment,
        'max_penalty': req.maxPenalty,
        'notes': req.notes,
      },
    );
    return _fromRow(result.first.toColumnMap());
  }

  Future<Subscription?> update({
    required String tenantId,
    required String id,
    required UpdateSubscriptionRequest req,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE subscriptions SET tier_id = @tier_id, payment_rhythm = @payment_rhythm, '
        'payment_method = @payment_method, '
        'term_months = @term_months, start_date = @start_date, end_date = @end_date, '
        'down_payment = @down_payment, max_penalty = @max_penalty, status = @status, '
        'cancelled_at = @cancelled_at, notes = @notes '
        'WHERE tenant_id = @tenant_id AND id = @id '
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'id': id,
        'tier_id': req.tierId,
        'payment_rhythm': req.paymentRhythm.toJson(),
        'payment_method': req.paymentMethod.toJson(),
        'term_months': req.termMonths,
        'start_date': req.startDate,
        'end_date': req.endDate,
        'down_payment': req.downPayment,
        'max_penalty': req.maxPenalty,
        'status': req.status.toJson(),
        'cancelled_at': req.cancelledAt,
        'notes': req.notes,
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  /// Kündigt ein aktives Abo zum Stichtag [cancelledAt] — Status-Guard in der
  /// WHERE-Klausel: nur Abos mit `status = 'active'` werden gekündigt, sonst
  /// liefert die Query keine Zeile und die Methode `null` (→ 404 in der Route).
  Future<Subscription?> cancel({
    required String tenantId,
    required String id,
    required DateTime cancelledAt,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        "UPDATE subscriptions SET status = 'cancelled', cancelled_at = @cancelled_at "
        "WHERE tenant_id = @tenant_id AND id = @id AND status = 'active' "
        'RETURNING $_columns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'id': id,
        'cancelled_at': cancelledAt,
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  /// Tier-Wechsel (Self-Service, Up-/Downgrade): beendet das aktuelle aktive
  /// Abo (`status = 'cancelled'`, `cancelled_at = now`, ohne Vertragsstrafe —
  /// ein Tier-Wechsel ist keine Kündigung) und legt mit denselben
  /// Vertragskonditionen (Laufzeit, Zahlungsrhythmus, max. Strafe) eine neue
  /// aktive Zeile mit dem neuen Tier und frischer Laufzeit ab heute an.
  /// Liefert `null`, wenn der Mandant kein aktives Abo hat.
  Future<Subscription?> changeTier({required String tenantId, required String newTierId}) async {
    return _pool.runTx((session) async {
      final current = await session.execute(
        Sql.named(
          "SELECT $_columns FROM subscriptions WHERE tenant_id = @tenant_id AND status = 'active'",
        ),
        parameters: {'tenant_id': tenantId},
      );
      if (current.isEmpty) return null;
      final old = _fromRow(current.first.toColumnMap());

      final now = DateTime.now();
      await session.execute(
        Sql.named(
          "UPDATE subscriptions SET status = 'cancelled', cancelled_at = @cancelled_at "
          'WHERE tenant_id = @tenant_id AND id = @id',
        ),
        parameters: {'tenant_id': tenantId, 'id': old.id, 'cancelled_at': now},
      );

      final result = await session.execute(
        Sql.named(
          'INSERT INTO subscriptions (tenant_id, tier_id, payment_rhythm, payment_method, term_months, '
          'start_date, end_date, down_payment, max_penalty, notes) '
          'VALUES (@tenant_id, @tier_id, @payment_rhythm, @payment_method, @term_months, '
          '@start_date, @end_date, @down_payment, @max_penalty, @notes) '
          'RETURNING $_columns',
        ),
        parameters: {
          'tenant_id': tenantId,
          'tier_id': newTierId,
          'payment_rhythm': old.paymentRhythm.toJson(),
          'payment_method': old.paymentMethod.toJson(),
          'term_months': old.termMonths,
          'start_date': now,
          'end_date': DateTime(now.year, now.month + old.termMonths, now.day),
          'down_payment': 0,
          'max_penalty': old.maxPenalty,
          'notes': old.notes,
        },
      );
      return _fromRow(result.first.toColumnMap());
    });
  }

  Subscription _fromRow(Map<String, dynamic> row) => Subscription(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        tierId: row['tier_id'] as String?,
        paymentRhythm: PaymentRhythm.fromJson(row['payment_rhythm'] as String),
        paymentMethod: PaymentMethod.fromJson(row['payment_method'] as String),
        termMonths: row['term_months'] as int,
        startDate: (row['start_date'] as DateTime).toUtc(),
        endDate: (row['end_date'] as DateTime).toUtc(),
        downPayment: (row['down_payment'] as num).toDouble(),
        maxPenalty: (row['max_penalty'] as num).toDouble(),
        status: SubscriptionStatus.fromJson(row['status'] as String),
        cancelledAt: (row['cancelled_at'] as DateTime?)?.toUtc(),
        notes: row['notes'] as String?,
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
