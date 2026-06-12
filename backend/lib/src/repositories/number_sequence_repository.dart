import 'package:postgres/postgres.dart';

/// Verwaltet mandantenfähige Nummernkreise (z. B. Kundennummern "K0001",
/// später Belegnummern für Angebote/Aufträge/Rechnungen).
class NumberSequenceRepository {
  NumberSequenceRepository(this._pool);

  final Pool<void> _pool;

  /// Reserviert und liefert die nächste formatierte Nummer für
  /// [sequenceKey] (z. B. `"customer"`) im Mandanten [tenantId].
  ///
  /// Legt den Nummernkreis beim ersten Aufruf mit [defaultPrefix]/
  /// [defaultPadWidth] an. Läuft transaktional (`SELECT ... FOR UPDATE`),
  /// sodass parallele Anfragen keine doppelten Nummern erhalten.
  Future<String> next({
    required String tenantId,
    required String sequenceKey,
    required String defaultPrefix,
    int defaultPadWidth = 4,
  }) {
    return _pool.runTx((session) async {
      await session.execute(
        Sql.named(
          'INSERT INTO number_sequences '
          '(tenant_id, sequence_key, prefix, pad_width, next_number) '
          'VALUES (@tenant_id, @sequence_key, @prefix, @pad_width, 1) '
          'ON CONFLICT (tenant_id, sequence_key) DO NOTHING',
        ),
        parameters: {
          'tenant_id': tenantId,
          'sequence_key': sequenceKey,
          'prefix': defaultPrefix,
          'pad_width': defaultPadWidth,
        },
      );

      final result = await session.execute(
        Sql.named(
          'SELECT prefix, pad_width, next_number FROM number_sequences '
          'WHERE tenant_id = @tenant_id AND sequence_key = @sequence_key '
          'FOR UPDATE',
        ),
        parameters: {'tenant_id': tenantId, 'sequence_key': sequenceKey},
      );
      final row = result.first.toColumnMap();
      final prefix = row['prefix'] as String;
      final padWidth = row['pad_width'] as int;
      final number = row['next_number'] as int;

      await session.execute(
        Sql.named(
          'UPDATE number_sequences SET next_number = next_number + 1 '
          'WHERE tenant_id = @tenant_id AND sequence_key = @sequence_key',
        ),
        parameters: {'tenant_id': tenantId, 'sequence_key': sequenceKey},
      );

      return '$prefix${number.toString().padLeft(padWidth, '0')}';
    });
  }
}
