import 'dart:io';

import 'package:backend/src/config.dart';
import 'package:backend/src/db.dart';
import 'package:backend/src/purchase_proposal_service.dart';
import 'package:backend/src/repositories/article_repository.dart';
import 'package:backend/src/repositories/number_sequence_repository.dart';
import 'package:backend/src/repositories/order_repository.dart';
import 'package:backend/src/repositories/product_repository.dart';
import 'package:backend/src/repositories/purchase_order_repository.dart';
import 'package:backend/src/repositories/supplier_repository.dart';
import 'package:backend/src/repositories/tenant_encryption_key_repository.dart';
import 'package:backend/src/tenant_encryption_service.dart';
import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';

void main() {
  final port = int.tryParse(Platform.environment['WAAS_TEST_DB_PORT'] ?? '');
  test(
    'Bestellvorschlag: Mehr-Lieferanten-Splitting, Raumgruppen-Rückverfolgung, '
    'Idempotenz bei wiederholtem Abruf/Entwurfsanlage',
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

        final numberSequences = NumberSequenceRepository(pool);
        final orderRepository = OrderRepository(pool, numberSequences);
        final articleRepository = ArticleRepository(pool);
        final productRepository = ProductRepository(pool);
        final tenantEncryptionService = TenantEncryptionService(
          AppConfig.fromEnvironment(),
          TenantEncryptionKeyRepository(pool),
        );
        final supplierRepository = SupplierRepository(pool, tenantEncryptionService);
        final purchaseOrderRepository = PurchaseOrderRepository(pool, numberSequences);
        final proposalService = PurchaseProposalService(
          orderRepository,
          productRepository,
          articleRepository,
          supplierRepository,
          purchaseOrderRepository,
        );

        Future<String> insertTenant(String name) async {
          final result = await pool.execute(
            Sql.named('INSERT INTO tenants (name) VALUES (@name) RETURNING id'),
            parameters: {'name': name},
          );
          final id = result.first.toColumnMap()['id'] as String;
          await tenantEncryptionService.provisionTenant(id);
          return id;
        }

        final tenant = await insertTenant('Proposal Test Tenant');

        final customerResult = await pool.execute(
          Sql.named(
            'INSERT INTO customers (tenant_id, customer_number, name) VALUES (@tenant, @number, @name) RETURNING id',
          ),
          parameters: {'tenant': tenant, 'number': 'K1', 'name': 'Testkunde'},
        );
        final customerId = customerResult.first.toColumnMap()['id'] as String;

        final supplierA = await supplierRepository.create(
          tenantId: tenant,
          req: const CreateSupplierRequest(name: 'Elektro-Großhandel A'),
        );
        final supplierB = await supplierRepository.create(
          tenantId: tenant,
          req: const CreateSupplierRequest(name: 'Elektro-Großhandel B'),
        );

        final steckdose = await articleRepository.create(
          tenantId: tenant,
          req: CreateArticleRequest(
            name: 'Steckdose',
            unit: 'Stk',
            purchasePrice: 2.5,
            stockQuantity: 5,
            defaultSupplierId: supplierA.id,
          ),
        );
        final schalter = await articleRepository.create(
          tenantId: tenant,
          req: CreateArticleRequest(
            name: 'Schalter',
            unit: 'Stk',
            purchasePrice: 4,
            defaultSupplierId: supplierB.id,
          ),
        );
        final kabel = await articleRepository.create(
          tenantId: tenant,
          req: const CreateArticleRequest(
            name: 'Kabel NYM-J 3x1,5',
            unit: 'm',
            purchasePrice: 1,
            stockQuantity: 100,
          ),
        );

        // Auftrag mit zwei Raumgruppen, die sich denselben Artikel teilen
        // (Steckdose), plus einer vollständig durch Lagerbestand gedeckten
        // Position (Kabel) — die darf im Vorschlag nicht auftauchen.
        final order = await orderRepository.create(
          tenantId: tenant,
          req: CreateOrderRequest(
            customerId: customerId,
            title: 'Elektroinstallation Neubau',
            items: [
              OrderItem(
                kind: OrderItemKind.article,
                articleId: steckdose.id,
                description: 'Steckdose',
                quantity: 10,
                groupLabel: 'Bad',
              ),
              OrderItem(
                kind: OrderItemKind.article,
                articleId: steckdose.id,
                description: 'Steckdose',
                quantity: 8,
                groupLabel: 'Küche',
              ),
              OrderItem(
                kind: OrderItemKind.article,
                articleId: schalter.id,
                description: 'Schalter',
                quantity: 3,
                groupLabel: 'Bad',
              ),
              OrderItem(
                kind: OrderItemKind.article,
                articleId: kabel.id,
                description: 'Kabel',
                quantity: 50,
              ),
            ],
          ),
        );

        // --- Erster Vorschlag: zwei Lieferantengruppen, Kabel fehlt ---
        final firstProposal = await proposalService.buildProposal(tenantId: tenant, orderId: order.id);
        expect(firstProposal, isNotNull);
        expect(firstProposal!.map((g) => g.supplierId).toSet(), {supplierA.id, supplierB.id});

        final steckdoseGroup = firstProposal.firstWhere((g) => g.supplierId == supplierA.id);
        expect(steckdoseGroup.items, hasLength(1));
        final steckdoseItem = steckdoseGroup.items.single;
        expect(steckdoseItem.requiredQuantity, 18); // 10 (Bad) + 8 (Küche)
        expect(steckdoseItem.stockQuantity, 5);
        expect(steckdoseItem.alreadyOrderedQuantity, 0);
        expect(steckdoseItem.orderQuantity, 13); // 18 - 5
        expect(
          steckdoseItem.sources.map((s) => (s.groupLabel, s.quantity)).toSet(),
          {('Bad', 10.0), ('Küche', 8.0)},
        );

        final schalterGroup = firstProposal.firstWhere((g) => g.supplierId == supplierB.id);
        final schalterItem = schalterGroup.items.single;
        expect(schalterItem.requiredQuantity, 3);
        expect(schalterItem.orderQuantity, 3);

        // Kabel ist durch Lagerbestand vollständig gedeckt (100 >= 50) und
        // darf in keiner Gruppe auftauchen.
        for (final group in firstProposal) {
          expect(group.items.any((i) => i.articleId == kabel.id), isFalse);
        }

        // --- Entwürfe anlegen: ein Entwurf pro Lieferant ---
        final createdOrders =
            await proposalService.createDraftsFromProposal(tenantId: tenant, orderId: order.id);
        expect(createdOrders, isNotNull);
        expect(createdOrders!, hasLength(2));
        expect(createdOrders.map((po) => po.supplierId).toSet(), {supplierA.id, supplierB.id});

        final steckdosePo = createdOrders.firstWhere((po) => po.supplierId == supplierA.id);
        expect(steckdosePo.status, PurchaseOrderStatus.open);
        expect(steckdosePo.orderId, order.id);
        expect(steckdosePo.items, hasLength(1));
        expect(steckdosePo.items.single.quantity, 13);

        // Rundtrip über die DB: Quellverweise bleiben erhalten (zwei
        // Raumgruppen-Beiträge für dieselbe zusammengefasste Position).
        final reloaded = await purchaseOrderRepository.findById(tenantId: tenant, id: steckdosePo.id);
        expect(reloaded, isNotNull);
        expect(reloaded!.items.single.sources, hasLength(2));
        expect(
          reloaded.items.single.sources.map((s) => (s.groupLabel, s.quantity)).toSet(),
          {('Bad', 10.0), ('Küche', 8.0)},
        );
        expect(reloaded.items.single.sources.every((s) => s.orderId == order.id), isTrue);

        // --- Idempotenz: erneuter Vorschlag ist jetzt leer ---
        final secondProposal = await proposalService.buildProposal(tenantId: tenant, orderId: order.id);
        expect(secondProposal, isEmpty);

        // --- Idempotenz: erneute Entwurfsanlage erzeugt nichts Neues ---
        final secondCreate =
            await proposalService.createDraftsFromProposal(tenantId: tenant, orderId: order.id);
        expect(secondCreate, isEmpty);

        // --- Normale Bearbeitung eines Entwurfs erhält die Quellverweise,
        // auch wenn der Editor sie nicht mitschickt (UI kennt sources nicht) ---
        final edited = await purchaseOrderRepository.update(
          tenantId: tenant,
          id: steckdosePo.id,
          req: UpdatePurchaseOrderRequest(
            supplierId: supplierA.id,
            notes: 'Lieferzeit erfragen',
            items: [
              PurchaseOrderItem(
                id: steckdosePo.items.single.id,
                articleId: steckdose.id,
                description: 'Steckdose (aktualisiert)',
                quantity: 13,
                unitPrice: 2.5,
              ),
            ],
          ),
        );
        expect(edited, isNotNull);
        expect(edited!.items.single.sources, hasLength(2));
        expect(edited.notes, 'Lieferzeit erfragen');

        // --- Bestellvorschlag für fremden Mandanten bleibt unberührt ---
        final otherTenant = await insertTenant('Proposal Other Tenant');
        final otherSums =
            await purchaseOrderRepository.sumOrderedQuantitiesForOrder(tenantId: otherTenant, orderId: order.id);
        expect(otherSums, isEmpty);
      } finally {
        await pool.execute(Sql("DELETE FROM tenants WHERE name LIKE 'Proposal %'"));
        await pool.close();
      }
    },
    skip: port == null ? 'Set WAAS_TEST_DB_PORT for isolated PostgreSQL integration' : false,
  );
}
