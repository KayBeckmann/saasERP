import 'dart:io';
import 'package:backend/src/db.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/number_sequence_repository.dart';
import 'package:backend/src/repositories/waas_billing_repository.dart';
import 'package:backend/src/waas_billing.dart';
import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';

void main() {
  final port = int.tryParse(Platform.environment['WAAS_TEST_DB_PORT'] ?? '');
  test(
    'two-tenant invoice lifecycle: unique period, revisions, approval and tenant isolation',
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
        Future<String> insert(
          String sql,
          Map<String, dynamic> parameters,
        ) async {
          final result = await pool.execute(
            Sql.named('$sql RETURNING id'),
            parameters: parameters,
          );
          return result.first.toColumnMap()['id'] as String;
        }

        final tenant = await insert(
          'INSERT INTO tenants (name) VALUES (@name)',
          {'name': 'Tenant A'},
        );
        final other = await insert(
          'INSERT INTO tenants (name) VALUES (@name)',
          {'name': 'Tenant B'},
        );
        final customer = await insert(
          'INSERT INTO customers (tenant_id, customer_number, name) '
          'VALUES (@tenant, @number, @name)',
          {'tenant': tenant, 'number': 'K1', 'name': 'Demo'},
        );
        final contract = await insert(
          'INSERT INTO maintenance_contracts '
          '(tenant_id, customer_id, contract_number, title, term_months, start_date, end_date) '
          'VALUES (@tenant, @customer, @number, @title, 12, @start, @end)',
          {
            'tenant': tenant,
            'customer': customer,
            'number': 'W1',
            'title': 'Site Care',
            'start': DateTime.utc(2026, 1, 31),
            'end': DateTime.utc(2026, 12, 31),
          },
        );
        final actor = '00000000-0000-0000-0000-000000000001';
        final repository = WaasBillingRepository(pool);
        await repository.addRevision(
          tenantId: tenant,
          contractId: contract,
          actorId: actor,
          plan: BillingPlan(
            monthlyCents: 1999,
            vatBasisPoints: 1900,
            effectiveFrom: DateTime.utc(2026, 1, 31),
          ),
          description: 'Site Care monthly',
        );
        final first = await repository.run(
          tenantId: tenant,
          contractId: contract,
          asOf: DateTime.utc(2026, 2, 28),
        );
        expect(first, hasLength(1));
        expect(
          await repository.run(
            tenantId: tenant,
            contractId: contract,
            asOf: DateTime.utc(2026, 2, 28),
          ),
          isEmpty,
        );
        await expectLater(
          repository.run(
            tenantId: other,
            contractId: contract,
            asOf: DateTime.utc(2026, 3, 31),
          ),
          throwsStateError,
        );
        await expectLater(
          repository.addRevision(
            tenantId: other,
            contractId: contract,
            actorId: actor,
            plan: BillingPlan(
              monthlyCents: 1999,
              vatBasisPoints: 1900,
              effectiveFrom: DateTime.utc(2026, 2, 28),
            ),
            description: 'Cross-tenant',
          ),
          throwsStateError,
        );
        expect(
          await repository.approve(
            tenantId: other,
            invoiceId: first.single,
            actorId: actor,
          ),
          false,
        );
        final invoices = InvoiceRepository(
          pool,
          NumberSequenceRepository(pool),
        );
        final invoice = await invoices.findById(
          tenantId: tenant,
          id: first.single,
        );
        expect(invoice!.status.name, 'draft');
        expect(invoice.items.single.unitPrice, 19.99);
        expect(
          await invoices.listForCustomer(
            tenantId: tenant,
            customerId: customer,
          ),
          isEmpty,
        );
        expect(
          (await invoices.listForExport(
            tenantId: tenant,
          )).where((i) => i.id == first.single),
          isEmpty,
        );
        expect(
          await invoices.findPublishedById(tenantId: tenant, id: first.single),
          isNull,
        );
        expect(
          await invoices.recordDunning(
            tenantId: tenant,
            id: first.single,
            fee: 5,
          ),
          isNull,
        );
        expect(
          await invoices.delete(tenantId: tenant, id: first.single),
          false,
        );
        expect(
          await repository.approve(
            tenantId: tenant,
            invoiceId: first.single,
            actorId: actor,
          ),
          true,
        );
        expect(
          await repository.approve(
            tenantId: tenant,
            invoiceId: first.single,
            actorId: actor,
          ),
          false,
        );
        expect(
          await invoices.listForCustomer(
            tenantId: tenant,
            customerId: customer,
          ),
          hasLength(1),
        );
        expect(
          await invoices.listForCustomer(tenantId: other, customerId: customer),
          isEmpty,
        );
        expect(
          await invoices.findPublishedById(tenantId: other, id: first.single),
          isNull,
        );
        expect(
          await invoices.findPublishedById(tenantId: tenant, id: first.single),
          isNotNull,
        );
        expect(
          (await invoices.listForExport(
            tenantId: tenant,
          )).where((i) => i.id == first.single),
          hasLength(1),
        );
        await expectLater(
          repository.addRevision(
            tenantId: tenant,
            contractId: contract,
            actorId: actor,
            plan: BillingPlan(
              monthlyCents: 2000,
              vatBasisPoints: 1900,
              effectiveFrom: DateTime.utc(2026, 1, 31),
            ),
            description: 'Retroactive',
          ),
          throwsStateError,
        );
        await repository.addRevision(
          tenantId: tenant,
          contractId: contract,
          actorId: actor,
          plan: BillingPlan(
            monthlyCents: 2500,
            vatBasisPoints: 1900,
            effectiveFrom: DateTime.utc(2026, 2, 28),
          ),
          description: 'New monthly price',
        );
        final concurrent = await Future.wait([
          repository.run(
            tenantId: tenant,
            contractId: contract,
            asOf: DateTime.utc(2026, 3, 31),
          ),
          WaasBillingRepository(pool).run(
            tenantId: tenant,
            contractId: contract,
            asOf: DateTime.utc(2026, 3, 31),
          ),
        ]);
        expect(concurrent.map((batch) => batch.length), containsAll([0, 1]));
        final next = concurrent.expand((batch) => batch).single;
        expect(
          (await invoices.findById(
            tenantId: tenant,
            id: next,
          ))!.items.single.unitPrice,
          25,
        );
        expect(
          await WaasBillingRepository(pool).run(
            tenantId: tenant,
            contractId: contract,
            asOf: DateTime.utc(2026, 3, 31),
          ),
          isEmpty,
        );
        expect(
          await repository.approve(
            tenantId: other,
            invoiceId: next,
            actorId: actor,
          ),
          isFalse,
        );
        expect(
          (await invoices.findById(tenantId: tenant, id: next))!.status.name,
          'draft',
        );
        expect(
          await invoices.update(
            tenantId: tenant,
            id: next,
            req: const UpdateInvoiceRequest(
              title: 'Manipulated',
              status: InvoiceStatus.sent,
            ),
          ),
          isNull,
        );
      } finally {
        await pool.close();
      }
    },
    skip: port == null
        ? 'Set WAAS_TEST_DB_PORT for isolated PostgreSQL integration'
        : false,
  );
}
