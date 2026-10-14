import 'dart:io';
import 'dart:typed_data';

import 'package:backend/src/config.dart';
import 'package:backend/src/db.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/document_repository.dart';
import 'package:backend/src/repositories/number_sequence_repository.dart';
import 'package:backend/src/repositories/supplier_repository.dart';
import 'package:backend/src/repositories/tenant_encryption_key_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/tenant_encryption_service.dart';
import 'package:backend/src/tenant_key_rotation_service.dart';
import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';

void main() {
  final port = int.tryParse(Platform.environment['WAAS_TEST_DB_PORT'] ?? '');
  test(
    'Schlüsselrotation: zwei Mandanten, alle Felder nach Rotation weiterhin korrekt lesbar, '
    'Ciphertext ändert sich, Mandanten bleiben isoliert',
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

        final config = AppConfig.fromEnvironment();
        final keyRepo = TenantEncryptionKeyRepository(pool);
        final encryptionService = TenantEncryptionService(config, keyRepo);
        final numberSequences = NumberSequenceRepository(pool);
        final customerRepo = CustomerRepository(pool, encryptionService, numberSequences);
        final supplierRepo = SupplierRepository(pool, encryptionService);
        final tenantRepo = TenantRepository(pool, encryptionService);
        final documentRepo = DocumentRepository(pool, encryptionService);
        final rotationService = TenantKeyRotationService(pool, encryptionService);

        Future<String> insertTenant(String name) async {
          final result = await pool.execute(
            Sql.named('INSERT INTO tenants (name) VALUES (@name) RETURNING id'),
            parameters: {'name': name},
          );
          final id = result.first.toColumnMap()['id'] as String;
          await encryptionService.provisionTenant(id);
          return id;
        }

        final tenantA = await insertTenant('Rotation Tenant A');
        final tenantB = await insertTenant('Rotation Tenant B');

        // --- Tenant A: Bestandsdaten über alle rotierten Tabellen hinweg ---
        final customerA = await customerRepo.create(
          tenantId: tenantA,
          req: const CreateCustomerRequest(
            kind: CustomerKind.private,
            name: 'Kunde A',
            email: 'kunde-a@example.test',
            phone: '0151-11111',
            address: 'Musterstraße 1',
            notes: 'Notiz A',
          ),
        );
        final supplierA = await supplierRepo.create(
          tenantId: tenantA,
          req: const CreateSupplierRequest(
            name: 'Lieferant A',
            contactPerson: 'Kontakt A',
            email: 'lieferant-a@example.test',
            phone: '0151-22222',
            address: 'Lieferstraße 1',
            iban: 'DE89370400440532013000',
            notes: 'Lieferantennotiz A',
          ),
        );
        await tenantRepo.updateConfig(
          tenantId: tenantA,
          config: const UpdateTenantConfigRequest(
            companyAddress: 'Firmenadresse A',
            companyTaxId: 'DE111111111',
            companyIban: 'DE02120300000000202051',
            defaultVatRate: 19,
            reducedVatRate: 7,
            dunningFeeLevel1: 5,
            dunningFeeLevel2: 10,
            dunningFeeLevel3: 15,
            defaultHourlyRate: 80,
          ),
        );
        final documentA = await documentRepo.create(
          tenantId: tenantA,
          customerId: customerA.id,
          filename: 'vollmacht.pdf',
          contentType: 'application/pdf',
          content: Uint8List.fromList('Vertraulicher Dokumentinhalt A'.codeUnits),
        );

        // --- Rohe Ciphertexte VOR der Rotation einsammeln (zum Vergleich) ---
        Future<Map<String, dynamic>> rawCustomerRow() async {
          final r = await pool.execute(
            Sql.named('SELECT email, phone, address, notes FROM customers WHERE id = @id'),
            parameters: {'id': customerA.id},
          );
          return r.first.toColumnMap();
        }

        final beforeCustomer = await rawCustomerRow();

        // --- Rotation für Tenant A durchführen ---
        final result = await rotationService.rotateTenant(tenantA);

        expect(result.oldVersion, 1);
        expect(result.newVersion, 2);
        expect(result.reencryptedCounts['customers'], 1);
        expect(result.reencryptedCounts['suppliers'], 1);
        expect(result.reencryptedCounts['tenants'], 1);
        expect(result.reencryptedCounts['documents'], 1);

        // --- Ciphertext hat sich geändert (neue Version, neuer Nonce) ---
        final afterCustomer = await rawCustomerRow();
        expect(afterCustomer['email'], isNot(equals(beforeCustomer['email'])));
        expect(afterCustomer['phone'], isNot(equals(beforeCustomer['phone'])));

        // --- Schlüsselstatus: alte Version retired, neue aktiv ---
        final versions = await encryptionService.listKeyVersions(tenantA);
        expect(versions, hasLength(2));
        expect(versions.firstWhere((v) => v.keyVersion == 1).status, 'retired');
        expect(versions.firstWhere((v) => v.keyVersion == 2).status, 'active');

        // --- Alle Felder bleiben nach Rotation korrekt lesbar (gleicher Klartext) ---
        final customerAfter = await customerRepo.findById(tenantId: tenantA, id: customerA.id);
        expect(customerAfter!.email, 'kunde-a@example.test');
        expect(customerAfter.phone, '0151-11111');
        expect(customerAfter.address, 'Musterstraße 1');
        expect(customerAfter.notes, 'Notiz A');

        final supplierAfter = await supplierRepo.findById(tenantId: tenantA, id: supplierA.id);
        expect(supplierAfter!.contactPerson, 'Kontakt A');
        expect(supplierAfter.email, 'lieferant-a@example.test');
        expect(supplierAfter.iban, 'DE89370400440532013000');
        expect(supplierAfter.notes, 'Lieferantennotiz A');

        final tenantAfter = await tenantRepo.findById(tenantA);
        expect(tenantAfter!.companyAddress, 'Firmenadresse A');
        expect(tenantAfter.companyTaxId, 'DE111111111');
        expect(tenantAfter.companyIban, 'DE02120300000000202051');

        final documentAfter = await documentRepo.findContentById(tenantId: tenantA, id: documentA.id);
        expect(
          String.fromCharCodes(documentAfter!.$2),
          'Vertraulicher Dokumentinhalt A',
        );

        // --- Tenant B (nicht rotiert) bleibt unberührt und weiterhin lesbar ---
        final customerB = await customerRepo.create(
          tenantId: tenantB,
          req: const CreateCustomerRequest(
            kind: CustomerKind.private,
            name: 'Kunde B',
            email: 'kunde-b@example.test',
          ),
        );
        final customerBRead = await customerRepo.findById(tenantId: tenantB, id: customerB.id);
        expect(customerBRead!.email, 'kunde-b@example.test');
        final versionsB = await encryptionService.listKeyVersions(tenantB);
        expect(versionsB, hasLength(1));
        expect(versionsB.single.status, 'active');

        // --- Zweite Rotation für Tenant A (Version 2 -> 3) funktioniert erneut ---
        final secondRotation = await rotationService.rotateTenant(tenantA);
        expect(secondRotation.oldVersion, 2);
        expect(secondRotation.newVersion, 3);
        final customerAfterSecond = await customerRepo.findById(tenantId: tenantA, id: customerA.id);
        expect(customerAfterSecond!.email, 'kunde-a@example.test');
      } finally {
        await pool.execute(Sql("DELETE FROM documents WHERE filename = 'vollmacht.pdf'"));
        await pool.execute(Sql("DELETE FROM customers WHERE name IN ('Kunde A', 'Kunde B')"));
        await pool.execute(Sql("DELETE FROM suppliers WHERE name = 'Lieferant A'"));
        await pool.execute(
          Sql("DELETE FROM tenants WHERE name IN ('Rotation Tenant A', 'Rotation Tenant B')"),
        );
        await pool.close();
      }
    },
    skip: port == null ? 'Set WAAS_TEST_DB_PORT for isolated PostgreSQL integration' : false,
  );
}
