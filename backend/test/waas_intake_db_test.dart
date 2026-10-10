import 'dart:io';
import 'dart:typed_data';
import 'package:backend/src/db.dart';
import 'package:backend/src/repositories/waas_intake_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

void main() {
  final port = int.tryParse(Platform.environment['WAAS_TEST_DB_PORT'] ?? '');
  test(
    'manual email import is isolated, idempotent, quarantined and audited without downstream effects',
    () async {
      final pool = Pool<void>.withEndpoints([
        Endpoint(
          host: '127.0.0.1',
          port: port!,
          database: Platform.environment['WAAS_TEST_DB_NAME']!,
          username: 'postgres',
          password: 'test_only',
        ),
      ], settings: const PoolSettings(sslMode: SslMode.disable));
      try {
        await runMigrations(pool);
        await runMigrations(pool);
        Future<String> add(String sql, Map<String, dynamic> p) async =>
            (await pool.execute(
                  Sql.named('$sql RETURNING id'),
                  parameters: p,
                )).first.toColumnMap()['id']
                as String;
        final a = await add('INSERT INTO tenants (name) VALUES (@name)', {
          'name': 'A',
        });
        final b = await add('INSERT INTO tenants (name) VALUES (@name)', {
          'name': 'B',
        });
        final ca = await add(
          'INSERT INTO customers (tenant_id,customer_number,name) VALUES (@t,\'1\',\'Customer A\')',
          {'t': a},
        );
        final cb = await add(
          'INSERT INTO customers (tenant_id,customer_number,name) VALUES (@t,\'1\',\'Customer B\')',
          {'t': b},
        );
        final repo = WaasIntakeRepository(pool);
        final raw = Uint8List.fromList(
          'From: forged@example.invalid\r\nSubject: Hello\r\n\r\nPlease change site'
              .codeUnits,
        );
        final pdf = Uint8List.fromList('%PDF-1.4\nnot scanned'.codeUnits);
        Future<String> ingest(
          String tenant,
          String mailbox,
          String uid,
          Uint8List bytes,
        ) => repo.importMessage(
          tenantId: tenant,
          actorId: '00000000-0000-0000-0000-000000000001',
          mailbox: mailbox,
          messageKey: uid,
          rawMessage: bytes,
          instruction: 'Change site',
          claimedFrom: 'forged@example.invalid',
          claimedSubject: 'Hello',
          pdf: pdf,
          pdfName: '../../invoice.pdf',
        );
        final id = await ingest(a, 'pilot', 'uid-1', raw);
        expect(await ingest(a, 'pilot', 'uid-1', raw), id);
        await expectLater(
          ingest(a, 'pilot', 'uid-1', Uint8List.fromList([1])),
          throwsStateError,
        );
        expect(await ingest(a, 'other-mailbox', 'uid-1', raw), isNot(id));
        expect(await ingest(b, 'pilot', 'uid-1', raw), isNot(id));
        expect(await repo.list(tenantId: b), hasLength(1));
        expect(await repo.list(tenantId: a), hasLength(2));
        expect(await repo.raw(tenantId: b, id: id), isNull);
        expect(await repo.attachment(tenantId: b, id: id), isNull);
        expect(await repo.raw(tenantId: a, id: id), raw);
        expect(await repo.attachment(tenantId: a, id: id), pdf);
        await expectLater(
          repo.associate(
            tenantId: a,
            id: id,
            customerId: cb,
            actorId: '00000000-0000-0000-0000-000000000001',
            verificationNote: 'Called known contact',
          ),
          throwsStateError,
        );
        await expectLater(
          repo.associate(
            tenantId: a,
            id: id,
            customerId: ca,
            actorId: '00000000-0000-0000-0000-000000000001',
            verificationNote: ' ',
          ),
          throwsArgumentError,
        );
        await repo.associate(
          tenantId: a,
          id: id,
          customerId: ca,
          actorId: '00000000-0000-0000-0000-000000000001',
          verificationNote: 'Called known contact',
        );
        await repo.markReviewed(
          tenantId: a,
          id: id,
          actorId: '00000000-0000-0000-0000-000000000001',
          decisionNote: 'Handle manually',
        );
        expect(
          (await repo.list(
            tenantId: a,
          )).firstWhere((item) => item['id'] == id)['status'],
          'reviewed',
        );
        expect(
          (await pool.execute(
            Sql.named(
              'SELECT action FROM waas_intake_audit WHERE tenant_id=@t AND request_id=@id ORDER BY created_at',
            ),
            parameters: {'t': a, 'id': id},
          )).map((r) => r[0]),
          ['imported', 'associated', 'reviewed'],
        );
        for (final table in [
          'invoices',
          'orders',
          'waas_psp_payments',
          'documents',
        ]) {
          expect(
            (await pool.execute(
              Sql.named('SELECT count(*) FROM $table WHERE tenant_id=@t'),
              parameters: {'t': a},
            )).first[0],
            0,
            reason: table,
          );
        }
      } finally {
        await pool.close();
      }
    },
    skip: port == null ? 'WAAS_TEST_DB_PORT required' : false,
  );
}
