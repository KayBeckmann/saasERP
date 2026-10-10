import 'dart:convert';
import 'dart:io';
import 'package:backend/src/db.dart';
import 'package:backend/src/waas_psp.dart';
import 'package:backend/src/repositories/waas_payment_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

void main() {
  final port = int.tryParse(Platform.environment['WAAS_TEST_DB_PORT'] ?? '');
  test(
    'fresh-schema merchant isolation, hosted mandate, signed replay and payment reconciliation',
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
        Future<String> add(String sql, Map<String, dynamic> params) async =>
            (await pool.execute(
                  Sql.named('$sql RETURNING id'),
                  parameters: params,
                )).first.toColumnMap()['id']
                as String;
        final tenant = await add('INSERT INTO tenants (name) VALUES (@name)', {
          'name': 'A',
        });
        final other = await add('INSERT INTO tenants (name) VALUES (@name)', {
          'name': 'B',
        });
        final customer = await add(
          'INSERT INTO customers (tenant_id, customer_number, name) VALUES (@t, @n, @name)',
          {'t': tenant, 'n': '1', 'name': 'A customer'},
        );
        final otherCustomer = await add(
          'INSERT INTO customers (tenant_id, customer_number, name) VALUES (@t, @n, @name)',
          {'t': other, 'n': '1', 'name': 'B customer'},
        );
        final invoice = await add(
          "INSERT INTO invoices (tenant_id, customer_id, invoice_number, title, status) VALUES (@t, @c, 'A1', 'Site', 'sent')",
          {'t': tenant, 'c': customer},
        );
        final otherInvoice = await add(
          "INSERT INTO invoices (tenant_id, customer_id, invoice_number, title, status) VALUES (@t, @c, 'B1', 'Site', 'sent')",
          {'t': other, 'c': otherCustomer},
        );
        await pool.execute(
          Sql.named(
            "INSERT INTO invoice_items (tenant_id,invoice_id,description,quantity,unit_price,vat_rate) VALUES (@t,@i,'Site',1,10,19)",
          ),
          parameters: {'t': tenant, 'i': invoice},
        );
        // Durable issuance gate, not a client-supplied 'sent' status.
        final contract = await add(
          "INSERT INTO maintenance_contracts (tenant_id, customer_id, contract_number, title, term_months, start_date, end_date) VALUES (@t,@c,'A1','Site',12,'2026-01-01','2026-12-31')",
          {'t': tenant, 'c': customer},
        );
        final revision = await add(
          "INSERT INTO waas_plan_revisions (tenant_id, contract_id, effective_from, monthly_cents, vat_basis_points, description, created_by) VALUES (@t,@contract,'2026-01-01',1000,1900,'Site','00000000-0000-0000-0000-000000000001')",
          {'t': tenant, 'contract': contract},
        );
        await pool.execute(
          Sql.named(
            "INSERT INTO waas_billing_runs (tenant_id,contract_id,plan_revision_id,invoice_id,period_start,period_end,approved_at) VALUES (@t,@contract,@revision,@invoice,'2026-01-01','2026-02-01',now())",
          ),
          parameters: {
            't': tenant,
            'contract': contract,
            'revision': revision,
            'invoice': invoice,
          },
        );
        final merchant = await add(
          "INSERT INTO waas_psp_merchants (tenant_id, provider, credential_alias) VALUES (@t,'fake',@alias)",
          {'t': tenant, 'alias': 'a'},
        );
        await add(
          "INSERT INTO waas_psp_merchants (tenant_id, provider, credential_alias) VALUES (@t,'fake',@alias)",
          {'t': other, 'alias': 'b'},
        );
        final fake = FakeWaasPsp({'a': 'secret-a', 'b': 'secret-b'});
        final repo = WaasPaymentRepository(pool, fake);
        await expectLater(
          repo.startMandate(tenantId: other, customerId: customer),
          throwsStateError,
        );
        final mandate = await repo.startMandate(
          tenantId: tenant,
          customerId: customer,
        );
        expect(mandate.url.host, 'sandbox.invalid');
        expect(mandate.status, 'pending');
        expect(
          await repo.startMandate(tenantId: tenant, customerId: customer),
          equals(mandate),
        );
        await expectLater(
          repo.submit(
            tenantId: tenant,
            customerId: customer,
            invoiceId: otherInvoice,
            mandateId: mandate.id,
            amountCents: 1190,
          ),
          throwsStateError,
        );
        await expectLater(
          repo.submit(
            tenantId: other,
            customerId: otherCustomer,
            invoiceId: invoice,
            mandateId: mandate.id,
            amountCents: 1190,
          ),
          throwsStateError,
        );
        await expectLater(
          repo.submit(
            tenantId: tenant,
            customerId: customer,
            invoiceId: invoice,
            mandateId: mandate.id,
            amountCents: 1190,
          ),
          throwsStateError,
        );
        var seq = 0;
        Future<String> event(
          String type, {
          String? payment,
          String? mandateRef,
          String? alias,
        }) async {
          final raw = utf8.encode(
            jsonEncode({
              'id': 'evt-${++seq}',
              'merchant': 'a',
              'type': type,
              'mandate': mandateRef ?? mandate.providerReference,
              if (payment != null) 'payment': payment,
          if (payment != null) 'invoice': invoice,
          if (payment != null) 'customer': customer,
          if (payment != null) 'amount_cents': 1190,
            }),
          );
          final sig = fake.signForTest(
            alias ?? 'a',
            raw,
            DateTime.now().toUtc(),
          );
          return repo.processWebhook(
            merchantId: merchant,
            rawBody: raw,
            signature: sig,
          );
        }

        expect(await event('mandate.active'), 'applied');
        expect(
          (await repo.startMandate(
            tenantId: tenant,
            customerId: customer,
          )).status,
          'active',
        );
        await expectLater(
          repo.submit(tenantId: tenant, customerId: customer, invoiceId: invoice, mandateId: mandate.id, amountCents: 1190),
          throwsStateError,
        ); // status + approval timestamp alone are not an issued document
        await pool.execute(Sql.named("INSERT INTO waas_invoice_documents (invoice_id,tenant_id,customer_id,snapshot,pdf,xml) VALUES (@i,@t,@c,'{}',@pdf,@xml)"),parameters:{'i':invoice,'t':tenant,'c':customer,'pdf':[1],'xml':[1]});
        await expectLater(repo.submit(tenantId: tenant, customerId: customer, invoiceId: invoice, mandateId: mandate.id, amountCents: 1000), throwsStateError);
        final payment = await repo.submit(
          tenantId: tenant,
          customerId: customer,
          invoiceId: invoice,
          mandateId: mandate.id,
          amountCents: 1190,
        );
        expect(payment.status, 'submitted');
        expect(
          await repo.submit(
            tenantId: tenant,
            customerId: customer,
            invoiceId: invoice,
            mandateId: mandate.id,
            amountCents: 1190,
          ),
          equals(payment),
        );
        expect(
          (await pool.execute(
            Sql.named('SELECT status FROM invoices WHERE id=@i'),
            parameters: {'i': invoice},
          )).first[0],
          'sent',
        );
        for (final mismatch in [
          {'customer': otherCustomer, 'invoice': invoice, 'amount_cents': 1190},
          {'customer': customer, 'invoice': otherInvoice, 'amount_cents': 1190},
          {'customer': customer, 'invoice': invoice, 'amount_cents': 1191},
        ]) {
          final raw = utf8.encode(jsonEncode({
            'id': 'mismatch-${mismatch.values.join('-')}',
            'merchant': 'a', 'type': 'payment.settled',
            'mandate': mandate.providerReference, 'payment': payment.providerReference,
            ...mismatch,
          }));
          await expectLater(repo.processWebhook(merchantId: merchant, rawBody: raw, signature: fake.signForTest('a', raw, DateTime.now().toUtc())), throwsStateError);
        }
        final wrong = utf8.encode(
          jsonEncode({
            'id': 'wrong',
            'merchant': 'a',
            'type': 'payment.settled',
            'mandate': mandate.providerReference,
            'payment': payment.providerReference,
            'invoice': invoice,
            'customer': customer,
            'amount_cents': 1190,
          }),
        );
        await expectLater(
          repo.processWebhook(
            merchantId: merchant,
            rawBody: wrong,
            signature: fake.signForTest('b', wrong, DateTime.now().toUtc()),
          ),
          throwsFormatException,
        );
        await expectLater(
          event(
            'payment.settled',
            payment: payment.providerReference,
            mandateRef: 'wrong',
          ),
          throwsStateError,
        );
        final settled = utf8.encode(
          jsonEncode({
            'id': 'settle',
            'merchant': 'a',
            'type': 'payment.settled',
            'mandate': mandate.providerReference,
            'payment': payment.providerReference,
            'invoice': invoice,
            'customer': customer,
            'amount_cents': 1190,
          }),
        );
        final signature = fake.signForTest(
          'a',
          settled,
          DateTime.now().toUtc(),
        );
        expect(
          await repo.processWebhook(
            merchantId: merchant,
            rawBody: settled,
            signature: signature,
          ),
          'applied',
        );
        expect(
          await repo.processWebhook(
            merchantId: merchant,
            rawBody: settled,
            signature: signature,
          ),
          'duplicate',
        );
        final collision = utf8.encode(
          jsonEncode({
            'id': 'settle',
            'merchant': 'a',
            'type': 'payment.failed',
            'mandate': mandate.providerReference,
            'payment': payment.providerReference,
            'invoice': invoice,
            'customer': customer,
            'amount_cents': 1190,
          }),
        );
        await expectLater(
          repo.processWebhook(
            merchantId: merchant,
            rawBody: collision,
            signature: fake.signForTest('a', collision, DateTime.now().toUtc()),
          ),
          throwsStateError,
        );
        expect(
          (await pool.execute(
            Sql.named('SELECT status FROM invoices WHERE id=@i'),
            parameters: {'i': invoice},
          )).first[0],
          'paid',
        );
        expect(
          await event('payment.returned', payment: payment.providerReference),
          'applied',
        );
        expect(
          (await pool.execute(
            Sql.named('SELECT status FROM invoices WHERE id=@i'),
            parameters: {'i': invoice},
          )).first[0],
          'sent',
        );
        expect(
          await event('payment.settled', payment: payment.providerReference),
          'ignored',
        );
        expect(await event('mandate.revoked'), 'applied');
        await expectLater(
          repo.submit(
            tenantId: tenant,
            customerId: customer,
            invoiceId: invoice,
            mandateId: mandate.id,
            amountCents: 1190,
          ),
          throwsStateError,
        );
        final audit = await pool.execute(
          Sql.named(
            'SELECT event_type FROM waas_psp_events WHERE merchant_id=@m ORDER BY created_at',
          ),
          parameters: {'m': merchant},
        );
        expect(audit.length, 5);
      } finally {
        await pool.close();
      }
    },
    skip: port == null
        ? 'Set WAAS_TEST_DB_PORT for isolated PostgreSQL'
        : false,
  );
}
