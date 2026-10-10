import 'dart:io';
import 'package:backend/src/db.dart';
import 'package:backend/src/repositories/number_sequence_repository.dart';
import 'package:backend/src/repositories/order_repository.dart';
import 'package:backend/src/repositories/quote_repository.dart';
import 'package:backend/src/repositories/order_subscription_billing_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';

void main() {
  test('weekly, quarterly, semiannual and yearly anchor clipping', () {
    final start = DateTime.utc(2024, 2, 29);
    expect(
      OrderSubscriptionBillingRepository.period(start, 'weekly', 1),
      DateTime.utc(2024, 3, 7),
    );
    expect(
      OrderSubscriptionBillingRepository.period(start, 'quarterly', 1),
      DateTime.utc(2024, 5, 29),
    );
    expect(
      OrderSubscriptionBillingRepository.period(start, 'semiannual', 1),
      DateTime.utc(2024, 8, 29),
    );
    expect(
      OrderSubscriptionBillingRepository.period(start, 'yearly', 1),
      DateTime.utc(2025, 2, 28),
    );
    expect(
      OrderSubscriptionBillingRepository.period(
        DateTime.utc(2024, 1, 31),
        'monthly',
        2,
      ),
      DateTime.utc(2024, 3, 31),
    );
  });
  final port = int.tryParse(Platform.environment['WAAS_TEST_DB_PORT'] ?? '');
  test(
    'fresh-schema recurring orders: cadence, snapshots, idempotence, isolation and guards',
    () async {
      final pool = Pool<void>.withEndpoints(
        [
          Endpoint(
            host: '127.0.0.1',
            port: port!,
            database: Platform.environment['WAAS_TEST_DB_NAME']!,
            username: 'postgres',
            password: 'test_only',
          ),
        ],
        settings: const PoolSettings(
          sslMode: SslMode.disable,
          maxConnectionCount: 8,
        ),
      );
      try {
        await runMigrations(pool);
        Future<String> insert(String sql, Map<String, dynamic> args) async =>
            (await pool.execute(
                  Sql.named('$sql RETURNING id'),
                  parameters: args,
                )).first.toColumnMap()['id']
                as String;
        final tenant = await insert(
          'INSERT INTO tenants (name) VALUES (@name)',
          {'name': 'A'},
        );
        final other = await insert(
          'INSERT INTO tenants (name) VALUES (@name)',
          {'name': 'B'},
        );
        final customer = await insert(
          'INSERT INTO customers (tenant_id,customer_number,name) VALUES (@tenant, @number, @name)',
          {'tenant': tenant, 'number': 'C1', 'name': 'Client'},
        );
        final seq = NumberSequenceRepository(pool);
        final orders = OrderRepository(pool, seq);
        final quotes = QuoteRepository(pool, seq);
        final quote = await quotes.create(
          tenantId: tenant,
          req: CreateQuoteRequest(
            customerId: customer,
            title: 'Proposal',
            isSubscription: true,
            billingInterval: 'monthly',
            billingStartDate: DateTime.utc(2024, 1, 31),
          ),
        );
        expect(quote.isSubscription, true);
        expect(quote.billingStartDate, DateTime.utc(2024, 1, 31));
        final order = await orders.create(
          tenantId: tenant,
          req: CreateOrderRequest(
            customerId: customer,
            title: 'Service',
            isSubscription: true,
            billingInterval: 'monthly',
            billingStartDate: DateTime.utc(2024, 1, 31),
            items: [
              const OrderItem(
                kind: OrderItemKind.text,
                description: 'Monthly',
                unitPrice: 29,
                vatRate: 7,
                groupLabel: 'Care',
              ),
              const OrderItem(
                kind: OrderItemKind.hours,
                description: 'Hours',
                quantity: 2,
                unitPrice: 5,
              ),
            ],
          ),
        );
        expect(order.billingInterval, 'monthly');
        final billing = OrderSubscriptionBillingRepository(pool);
        expect(
          await billing.run(
            tenantId: other,
            orderId: order.id,
            asOf: DateTime.utc(2024, 3, 31),
          ),
          isEmpty,
        );
        await expectLater(
          orders.create(
            tenantId: other,
            req: CreateOrderRequest(
              customerId: customer,
              title: 'Wrong tenant',
              isSubscription: true,
              billingInterval: 'weekly',
              billingStartDate: DateTime.utc(2024, 1, 1),
            ),
          ),
          throwsArgumentError,
        );
        expect(
          await billing.run(
            tenantId: tenant,
            orderId: order.id,
            asOf: DateTime.utc(2024, 1, 30),
          ),
          isEmpty,
        );
        final ids = await billing.run(
          tenantId: tenant,
          orderId: order.id,
          asOf: DateTime.utc(2024, 3, 31),
        );
        expect(ids, hasLength(3));
        final periods = await pool.execute(
          Sql.named(
            'SELECT period_start FROM order_subscription_invoice_runs WHERE order_id=@id ORDER BY period_start',
          ),
          parameters: {'id': order.id},
        );
        expect(
          periods
              .map((r) => r.toColumnMap()['period_start'] as DateTime)
              .map((d) => d.toIso8601String().substring(0, 10))
              .toList(),
          ['2024-01-31', '2024-02-29', '2024-03-31'],
        );
        final invoiceRows = await pool.execute(
          Sql.named('SELECT status, notes FROM invoices WHERE id=@id'),
          parameters: {'id': ids.first},
        );
        expect(invoiceRows.first.toColumnMap()['status'], 'draft');
        expect(
          invoiceRows.first.toColumnMap()['notes'],
          contains('2024-01-31 bis 2024-02-28'),
        );
        await expectLater(
          pool.execute(
            Sql.named('DELETE FROM orders WHERE id=@id'),
            parameters: {'id': order.id},
          ),
          throwsA(isA<Exception>()),
        );
        final items = await pool.execute(
          Sql.named(
            'SELECT group_label, unit_price, vat_rate, order_item_id FROM invoice_items WHERE invoice_id=@id ORDER BY sort_order',
          ),
          parameters: {'id': ids.first},
        );
        expect(items, hasLength(2));
        expect(items.first.toColumnMap()['group_label'], 'Care');
        expect(items.first.toColumnMap()['unit_price'], 29.0);
        expect(items.first.toColumnMap()['vat_rate'], 7.0);
        expect(items.first.toColumnMap()['order_item_id'], isNull);
        expect(
          await billing.run(
            tenantId: tenant,
            orderId: order.id,
            asOf: DateTime.utc(2024, 3, 31),
          ),
          isEmpty,
        );
        final concurrent = await Future.wait([
          billing.run(
            tenantId: tenant,
            orderId: order.id,
            asOf: DateTime.utc(2024, 4, 30),
          ),
          billing.run(
            tenantId: tenant,
            orderId: order.id,
            asOf: DateTime.utc(2024, 4, 30),
          ),
        ]);
        expect(concurrent.expand((x) => x), hasLength(1));
        final revised = await orders.update(
          tenantId: tenant,
          id: order.id,
          req: UpdateOrderRequest(
            customerId: customer,
            title: 'Revised',
            isSubscription: true,
            billingInterval: 'quarterly',
            billingStartDate: DateTime.utc(2024, 1, 31),
            items: [
              const OrderItem(
                kind: OrderItemKind.text,
                description: 'New price',
                unitPrice: 42,
              ),
            ],
          ),
        );
        expect(revised!.billingInterval, 'quarterly');
        final future = await billing.run(
          tenantId: tenant,
          orderId: order.id,
          asOf: DateTime.utc(2024, 10, 31),
        );
        expect(future, hasLength(2));
        final old = await pool.execute(
          Sql.named('SELECT title FROM invoices WHERE id=@id'),
          parameters: {'id': ids.first},
        );
        expect(old.first.toColumnMap()['title'], 'Service');
        final newItems = await pool.execute(
          Sql.named(
            'SELECT unit_price FROM invoice_items WHERE invoice_id=@id',
          ),
          parameters: {'id': future.first},
        );
        expect(newItems.single.toColumnMap()['unit_price'], 42.0);
        await orders.update(
          tenantId: tenant,
          id: order.id,
          req: UpdateOrderRequest(
            customerId: customer,
            title: 'Service',
            status: OrderStatus.cancelled,
            isSubscription: true,
            billingInterval: 'quarterly',
            billingStartDate: DateTime.utc(2024, 1, 31),
            items: revised.items,
          ),
        );
        expect(
          await billing.run(
            tenantId: tenant,
            orderId: order.id,
            asOf: DateTime.utc(2024, 5, 31),
          ),
          isEmpty,
        );
        await expectLater(
          orders.create(
            tenantId: tenant,
            req: const CreateOrderRequest(
              title: 'Invalid',
              isSubscription: true,
              billingInterval: 'weekly',
            ),
          ),
          throwsArgumentError,
        );
      } finally {
        await pool.close();
      }
    },
    skip: port == null ? 'requires WAAS_TEST_DB_PORT' : false,
  );
}
