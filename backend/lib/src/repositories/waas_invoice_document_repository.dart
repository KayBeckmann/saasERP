import 'dart:convert';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../pdf/invoice_pdf_builder.dart';
import '../pdf/zugferd_xml_builder.dart';
import '../tenant_encryption_service.dart';

const _table = 'waas_invoice_documents';

/// Stored, single-version PDF/XML pair for an explicitly approved WaaS invoice.
/// This is NOT a validated Factur-X, XRechnung, or PDF/A-3 artifact.
///
/// RF1-Hinweis: `pdf`/`xml` sind serverseitig feldverschlüsselt (AEAD,
/// gebunden an invoice_id). Das `snapshot`-JSONB bleibt bewusst unverschlüsselt
/// (siehe docs/waas-issued-documents.md) — es enthält aktuell aber auch
/// `tenant.company_address`/`company_iban`/`customer.address`, die in ihren
/// Quelltabellen verschlüsselt sind. Das ist ein dokumentierter, noch offener
/// Punkt (siehe RF0/RF1-Auditnotiz im Vault), keine stille Lücke.
class WaasInvoiceDocument {
  const WaasInvoiceDocument({
    required this.version,
    required this.snapshot,
    required this.pdf,
    required this.xml,
  });
  final int version;
  final Map<String, dynamic> snapshot;
  final Uint8List pdf;
  final Uint8List xml;
}

class WaasInvoiceDocumentRepository {
  WaasInvoiceDocumentRepository(this._pool, this._encryptionService);
  final Pool<void> _pool;
  final TenantEncryptionService _encryptionService;

  /// Serialized by the run-row lock. Approval and artifact persistence commit
  /// together. No retry may re-render a previously approved document.
  Future<bool> approve({
    required String tenantId,
    required String invoiceId,
    required String actorId,
    required Invoice invoice,
    required Tenant tenant,
    required Customer customer,
  }) async {
    if (invoice.id != invoiceId ||
        invoice.tenantId != tenantId ||
        tenant.id != tenantId ||
        customer.tenantId != tenantId ||
        invoice.customerId != customer.id ||
        invoice.items.isEmpty) {
      return false;
    }
    final crypto = await _encryptionService.forTenant(tenantId);
    return _pool.runTx((tx) async {
      final runs = await tx.execute(
        Sql.named(
          'SELECT approved_at FROM waas_billing_runs WHERE tenant_id = @tenant '
          'AND invoice_id = @invoice FOR UPDATE',
        ),
        parameters: {'tenant': tenantId, 'invoice': invoiceId},
      );
      if (runs.isEmpty || runs.first.toColumnMap()['approved_at'] != null)
        return false;
      final dbInvoice = await tx.execute(
        Sql.named(
          'SELECT invoice_number, customer_id, title, status, due_date FROM invoices '
          'WHERE id = @invoice AND tenant_id = @tenant FOR UPDATE',
        ),
        parameters: {'tenant': tenantId, 'invoice': invoiceId},
      );
      if (dbInvoice.isEmpty) return false;
      final header = dbInvoice.first.toColumnMap();
      if (header['status'] != 'draft' ||
          header['invoice_number'] != invoice.invoiceNumber ||
          header['customer_id'] != customer.id ||
          header['title'] != invoice.title)
        return false;
      final items = await tx.execute(
        Sql.named(
          'SELECT description, quantity, unit_price, vat_rate FROM invoice_items '
          'WHERE invoice_id = @invoice AND tenant_id = @tenant ORDER BY sort_order',
        ),
        parameters: {'tenant': tenantId, 'invoice': invoiceId},
      );
      if (items.length != invoice.items.length) return false;
      for (var i = 0; i < items.length; i++) {
        final row = items[i].toColumnMap();
        final item = invoice.items[i];
        if (row['description'] != item.description ||
            (row['quantity'] as num).toDouble() != item.quantity ||
            (row['unit_price'] as num).toDouble() != item.unitPrice ||
            (row['vat_rate'] as num).toDouble() != item.vatRate)
          return false;
      }
      // Draft creation is not issuance: the payment term starts at approval.
      // Preserve a later existing due date, but never issue already overdue.
      final clock = await tx.execute(Sql('SELECT now() AS issued_at'));
      final issuedAt = (clock.first.toColumnMap()['issued_at'] as DateTime)
          .toUtc();
      final minimumDue = DateTime.utc(
        issuedAt.year,
        issuedAt.month,
        issuedAt.day,
      ).add(const Duration(days: 14));
      final draftDue = header['due_date'] as DateTime?;
      final due = draftDue != null && draftDue.toUtc().isAfter(minimumDue)
          ? draftDue.toUtc()
          : minimumDue;
      await tx.execute(
        Sql.named(
          'UPDATE invoices SET created_at = @issued, due_date = @due '
          'WHERE id = @invoice AND tenant_id = @tenant',
        ),
        parameters: {
          'issued': issuedAt,
          'due': due,
          'invoice': invoiceId,
          'tenant': tenantId,
        },
      );
      // The PDF has a fixed "sent" label. Later payment/status transitions
      // must not change the issued representation.
      final issued = Invoice.fromJson({
        ...invoice.toJson(),
        'status': 'sent',
        'created_at': issuedAt.toIso8601String(),
        'due_date': due.toIso8601String().split('T').first,
      });
      final snapshot = {
        'invoice': {
          'invoice_number': issued.invoiceNumber,
          'title': issued.title,
          'status': issued.status.toJson(),
          'created_at': issued.createdAt.toIso8601String(),
          'due_date': issued.dueDate?.toIso8601String().split('T').first,
          'notes': issued.notes,
          'items': [
            for (final item in issued.items)
              {
                'description': item.description,
                'quantity': item.quantity,
                'unit': item.unit,
                'unit_price': item.unitPrice,
                'vat_rate': item.vatRate,
                'group_label': item.groupLabel,
              },
          ],
        },
        'tenant': {
          'name': tenant.name,
          'company_address': tenant.companyAddress,
          'company_tax_id': tenant.companyTaxId,
          'company_iban': tenant.companyIban,
        },
        'customer': {
          'name': customer.name,
          'address': customer.address,
          'leitweg_id': customer.leitwegId,
        },
      };
      final pdf = await buildInvoicePdf(
        invoice: issued,
        tenant: tenant,
        customer: customer,
      );
      final xml = utf8.encode(
        buildZugferdXml(invoice: issued, tenant: tenant, customer: customer),
      );
      await tx.execute(
        Sql.named(
          'INSERT INTO waas_invoice_documents (invoice_id, tenant_id, customer_id, snapshot, pdf, xml) '
          'VALUES (@invoice, @tenant, @customer, @snapshot, @pdf, @xml)',
        ),
        parameters: {
          'invoice': invoiceId,
          'tenant': tenantId,
          'customer': customer.id,
          'snapshot': jsonEncode(snapshot),
          'pdf': crypto.encryptBytesField(table: _table, recordId: invoiceId, field: 'pdf', value: pdf),
          'xml': crypto.encryptBytesField(table: _table, recordId: invoiceId, field: 'xml', value: xml),
        },
      );
      await tx.execute(
        Sql.named(
          'UPDATE waas_billing_runs SET approved_by = @actor, approved_at = now() '
          'WHERE invoice_id = @invoice AND tenant_id = @tenant',
        ),
        parameters: {
          'actor': actorId,
          'invoice': invoiceId,
          'tenant': tenantId,
        },
      );
      await tx.execute(
        Sql.named(
          "UPDATE invoices SET status = 'sent' WHERE id = @invoice AND tenant_id = @tenant",
        ),
        parameters: {'invoice': invoiceId, 'tenant': tenantId},
      );
      return true;
    });
  }

  /// True even before approval, used by legacy exports to fail closed rather
  /// than dynamically render a draft or re-render an approved WaaS invoice.
  Future<bool> isWaasInvoice({
    required String tenantId,
    required String invoiceId,
  }) async {
    final rows = await _pool.execute(
      Sql.named(
        'SELECT 1 FROM waas_billing_runs WHERE tenant_id = @tenant AND invoice_id = @invoice',
      ),
      parameters: {'tenant': tenantId, 'invoice': invoiceId},
    );
    return rows.isNotEmpty;
  }

  Future<WaasInvoiceDocument?> read({
    required String tenantId,
    required String invoiceId,
    String? customerId,
  }) async {
    final rows = await _pool.execute(
      Sql.named(
        'SELECT d.version, d.snapshot, d.pdf, d.xml FROM waas_invoice_documents d '
        'JOIN waas_billing_runs w ON w.invoice_id = d.invoice_id AND w.tenant_id = d.tenant_id '
        'WHERE d.tenant_id = @tenant AND d.invoice_id = @invoice '
        'AND w.approved_at IS NOT NULL AND (@customer::uuid IS NULL OR d.customer_id = @customer::uuid)',
      ),
      parameters: {
        'tenant': tenantId,
        'invoice': invoiceId,
        'customer': customerId,
      },
    );
    if (rows.isEmpty) return null;
    final row = rows.first.toColumnMap();
    // waas_invoice_documents ist per DB-Trigger unveränderlich — eine
    // Rotation kann bestehende Zeilen nicht umschlüsseln (siehe
    // TenantEncryptionService.decryptImmutableBytesField). Entschlüsselung
    // muss daher die im Ciphertext codierte (ggf. retired) Version
    // auflösen, nicht die aktuell aktive erzwingen.
    final pdf = await _encryptionService.decryptImmutableBytesField(
      tenantId: tenantId,
      table: _table,
      recordId: invoiceId,
      field: 'pdf',
      value: row['pdf'] as Uint8List,
    );
    final xml = await _encryptionService.decryptImmutableBytesField(
      tenantId: tenantId,
      table: _table,
      recordId: invoiceId,
      field: 'xml',
      value: row['xml'] as Uint8List,
    );
    return WaasInvoiceDocument(
      version: row['version'] as int,
      snapshot: (row['snapshot'] as Map).cast<String, dynamic>(),
      pdf: pdf!,
      xml: xml!,
    );
  }
}
