import 'dart:convert';
import 'dart:io';

import 'package:backend/src/db.dart';
import 'package:backend/src/repositories/waas_invoice_document_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';

void main() {
  final port = int.tryParse(Platform.environment['WAAS_TEST_DB_PORT'] ?? '');
  test(
    'approval freezes PDF and XML and denies drafts, other tenants/customers and corrections in place',
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
        Future<String> id(String sql, Map<String, dynamic> args) async =>
            (await pool.execute(
                  Sql.named('$sql RETURNING id'),
                  parameters: args,
                )).first.toColumnMap()['id']
                as String;
        final tenantId = await id(
          'INSERT INTO tenants (name, company_address, company_tax_id) VALUES (@name, @address, @tax)',
          {'name': 'Site Studio', 'address': 'Straße 1', 'tax': 'DE123456789'},
        );
        final otherId = await id('INSERT INTO tenants (name) VALUES (@name)', {
          'name': 'Other',
        });
        final customerId = await id(
          'INSERT INTO customers (tenant_id, customer_number, name) VALUES (@tenant, @number, @name)',
          {'tenant': tenantId, 'number': 'K1', 'name': 'Website Kunde'},
        );
        final otherCustomerId = await id(
          'INSERT INTO customers (tenant_id, customer_number, name) VALUES (@tenant, @number, @name)',
          {'tenant': tenantId, 'number': 'K2', 'name': 'Fremdkunde'},
        );
        final invoiceId = await id(
          'INSERT INTO invoices (tenant_id, customer_id, invoice_number, title, due_date) VALUES (@tenant, @customer, @number, @title, @due)',
          {
            'tenant': tenantId,
            'customer': customerId,
            'number': 'R123',
            'title': 'WaaS',
            'due': DateTime.utc(2020, 2, 1),
          },
        );
        await pool.execute(
          Sql.named(
            'INSERT INTO invoice_items (tenant_id, invoice_id, description, quantity, unit_price, vat_rate, sort_order) VALUES (@tenant, @invoice, @description, 1, 20, 19, 0)',
          ),
          parameters: {
            'tenant': tenantId,
            'invoice': invoiceId,
            'description': 'Webseitenpflege',
          },
        );
        final contract = await id(
          'INSERT INTO maintenance_contracts (tenant_id, customer_id, contract_number, title, term_months, start_date, end_date) VALUES (@tenant, @customer, @number, @title, 12, @start, @end)',
          {
            'tenant': tenantId,
            'customer': customerId,
            'number': 'W1',
            'title': 'WaaS',
            'start': DateTime.utc(2026),
            'end': DateTime.utc(2026, 12, 31),
          },
        );
        final revision = await id(
          'INSERT INTO waas_plan_revisions (tenant_id, contract_id, effective_from, monthly_cents, vat_basis_points, description, created_by) VALUES (@tenant, @contract, @start, 2000, 1900, @description, @actor)',
          {
            'tenant': tenantId,
            'contract': contract,
            'start': DateTime.utc(2026),
            'description': 'WaaS',
            'actor': '00000000-0000-0000-0000-000000000001',
          },
        );
        await pool.execute(
          Sql.named(
            'INSERT INTO waas_billing_runs (tenant_id, contract_id, plan_revision_id, invoice_id, period_start, period_end) VALUES (@tenant, @contract, @revision, @invoice, @start, @end)',
          ),
          parameters: {
            'tenant': tenantId,
            'contract': contract,
            'revision': revision,
            'invoice': invoiceId,
            'start': DateTime.utc(2026),
            'end': DateTime.utc(2026, 2),
          },
        );
        final docs = WaasInvoiceDocumentRepository(pool);
        expect(
          await docs.read(
            tenantId: tenantId,
            invoiceId: invoiceId,
            customerId: customerId,
          ),
          isNull,
        );
        final invoice = Invoice.fromJson({
          'id': invoiceId,
          'tenant_id': tenantId,
          'invoice_number': 'R123',
          'customer_id': customerId,
          'title': 'WaaS',
          'status': 'sent',
          'created_at': DateTime.utc(2026).toIso8601String(),
          'due_date': '2020-02-01T00:00:00.000Z',
          'items': [
            {
              'id': '00000000-0000-0000-0000-000000000010',
              'invoice_id': invoiceId,
              'kind': 'text',
              'description': 'Webseitenpflege',
              'quantity': 1.0,
              'unit_price': 20.0,
              'vat_rate': 19.0,
            },
          ],
        });
        final tenant = Tenant(
          id: tenantId,
          name: 'Site Studio',
          createdAt: DateTime.utc(2026),
          companyAddress: 'Straße 1',
          companyTaxId: 'DE123456789',
        );
        final customer = Customer(
          id: customerId,
          tenantId: tenantId,
          customerNumber: 'K1',
          name: 'Website Kunde',
          kind: CustomerKind.business,
          address: 'Rechnungsstraße 2',
          leitwegId: '123-456',
          email: 'private@example.test',
          phone: 'SECRET-PHONE',
          notes: 'SECRET-NOTES',
          contactPerson: 'SECRET-CONTACT',
          createdAt: DateTime.utc(2026),
        );
        expect(
          await docs.approve(
            tenantId: otherId,
            invoiceId: invoiceId,
            actorId: '00000000-0000-0000-0000-000000000001',
            invoice: invoice,
            tenant: tenant,
            customer: customer,
          ),
          isFalse,
        );
        expect(
          await docs.approve(
            tenantId: tenantId,
            invoiceId: invoiceId,
            actorId: '00000000-0000-0000-0000-000000000001',
            invoice: invoice,
            tenant: tenant,
            customer: customer,
          ),
          isTrue,
        );
        final first = (await docs.read(
          tenantId: tenantId,
          invoiceId: invoiceId,
          customerId: customerId,
        ))!;
        expect(first.version, 1);
        expect(
          first.snapshot['invoice']['items'][0].keys,
          containsAll(['description', 'quantity', 'unit_price', 'vat_rate']),
        );
        expect(
          first.snapshot['invoice']['items'][0],
          isNot(containsPair('id', anything)),
        );
        expect(
          first.snapshot['invoice'],
          isNot(containsPair('dunning_level', anything)),
        );
        expect(first.pdf.sublist(0, 4), [37, 80, 68, 70]);
        expect(utf8.decode(first.xml), contains('Webseitenpflege'));
        final issuedAt = DateTime.parse(
          first.snapshot['invoice']['created_at'] as String,
        ).toUtc();
        final dueAt = DateTime.parse(
          first.snapshot['invoice']['due_date'] as String,
        ).toUtc();
        expect(
          issuedAt.difference(DateTime.now().toUtc()).inMinutes.abs(),
          lessThan(2),
        );
        expect(
          dueAt,
          DateTime.utc(
            issuedAt.year,
            issuedAt.month,
            issuedAt.day,
          ).add(const Duration(days: 14)),
        );
        final stored = (await pool.execute(
          Sql.named('SELECT created_at, due_date FROM invoices WHERE id = @id'),
          parameters: {'id': invoiceId},
        )).first.toColumnMap();
        expect((stored['created_at'] as DateTime).toUtc(), issuedAt);
        expect((stored['due_date'] as DateTime).toUtc(), dueAt);
        final savedCustomer = (first.snapshot['customer'] as Map)
            .cast<String, dynamic>();
        expect(savedCustomer, {
          'name': 'Website Kunde',
          'address': 'Rechnungsstraße 2',
          'leitweg_id': '123-456',
        });
        expect(first.snapshot['tenant'], {
          'name': 'Site Studio',
          'company_address': 'Straße 1',
          'company_tax_id': 'DE123456789',
          'company_iban': null,
        });
        expect(
          utf8.decode(first.xml),
          contains(
            '${dueAt.year}${dueAt.month.toString().padLeft(2, '0')}${dueAt.day.toString().padLeft(2, '0')}',
          ),
        );
        expect(
          await docs.approve(
            tenantId: tenantId,
            invoiceId: invoiceId,
            actorId: '00000000-0000-0000-0000-000000000001',
            invoice: invoice,
            tenant: tenant,
            customer: customer,
          ),
          isFalse,
        );
        expect(
          await docs.read(tenantId: otherId, invoiceId: invoiceId),
          isNull,
        );
        expect(
          await docs.read(
            tenantId: tenantId,
            invoiceId: invoiceId,
            customerId: otherCustomerId,
          ),
          isNull,
        );
        await pool.execute(
          Sql.named("UPDATE tenants SET name = 'Changed' WHERE id = @id"),
          parameters: {'id': tenantId},
        );
        await pool.execute(
          Sql.named("UPDATE customers SET name = 'Changed' WHERE id = @id"),
          parameters: {'id': customerId},
        );
        final again = (await docs.read(
          tenantId: tenantId,
          invoiceId: invoiceId,
        ))!;
        expect(again.pdf, first.pdf);
        expect(again.xml, first.xml);
        expect(again.snapshot, first.snapshot);
        await expectLater(
          pool.execute(
            Sql.named(
              'UPDATE invoices SET created_at = @date, due_date = @date WHERE id = @id',
            ),
            parameters: {'date': DateTime.utc(2020), 'id': invoiceId},
          ),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          pool.execute(
            Sql.named('UPDATE invoices SET created_at = @date WHERE id = @id'),
            parameters: {'date': DateTime.utc(2020), 'id': invoiceId},
          ),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          pool.execute(
            Sql.named(
              'UPDATE invoice_items SET description = @description WHERE invoice_id = @id',
            ),
            parameters: {'description': 'Tampered', 'id': invoiceId},
          ),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          pool.execute(
            Sql.named(
              'UPDATE waas_invoice_documents SET xml = @xml WHERE invoice_id = @id',
            ),
            parameters: {
              'xml': [1, 2],
              'id': invoiceId,
            },
          ),
          throwsA(isA<Exception>()),
        );
      } finally {
        await pool.close();
      }
    },
    skip: port == null ? 'Set WAAS_TEST_DB_PORT' : false,
  );
}
