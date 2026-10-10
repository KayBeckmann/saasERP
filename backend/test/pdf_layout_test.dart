import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:backend/src/pdf/quote_pdf_builder.dart';
import 'package:backend/src/pdf/invoice_pdf_builder.dart';
import 'package:backend/src/pdf/purchase_order_pdf_builder.dart';
import 'package:backend/src/pdf/dunning_pdf_builder.dart';

final date = DateTime(2026, 10, 10);
final tenant = Tenant(
  id: 't',
  name: 'Müller & Söhne GmbH',
  createdAt: date,
  companyAddress: 'Hafenstraße 12\n20457 Hamburg',
  companyTaxId: 'DE123456789',
  companyIban: 'DE89 3704 0044 0532 0130 00',
);
final customer = Customer(
  id: 'c',
  tenantId: 't',
  customerNumber: 'K0001',
  kind: CustomerKind.business,
  name: 'Büro für schöne Räume',
  address: 'Marktstraße 7\n10115 Berlin',
  createdAt: date,
);
final supplier = Supplier(
  id: 's',
  tenantId: 't',
  name: 'Schröder Zubehör',
  address: 'Am Kai 5\n28195 Bremen',
  email: 'kontakt@example.test',
  createdAt: date,
);

Future<String> verify(
  Uint8List bytes,
  String name,
  List<String> expected, {
  bool multipage = false,
}) async {
  final dir = await Directory.systemTemp.createTemp('saaserp-pdf-');
  try {
    final file = File('${dir.path}/$name.pdf');
    await file.writeAsBytes(bytes);
    final info = await Process.run('pdfinfo', [file.path]);
    expect(info.exitCode, 0, reason: '${info.stderr}');
    expect(info.stdout, contains('A4'));
    final textResult = await Process.run('pdftotext', [
      '-layout',
      file.path,
      '-',
    ]);
    expect(textResult.exitCode, 0);
    final text = textResult.stdout as String;
    for (final phrase in expected) {
      expect(text, contains(phrase), reason: name);
    }
    expect(text, isNot(contains('�')));
    // Every extracted word must stay inside the printable A4 area, on every page.
    final boxes = await Process.run('pdftotext', ['-bbox', file.path, '-']);
    expect(boxes.exitCode, 0);
    final words = RegExp(
      r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)"',
    ).allMatches(boxes.stdout as String).toList();
    expect(words, isNotEmpty);
    for (final word in words) {
      final xMin = double.parse(word.group(1)!);
      final yMin = double.parse(word.group(2)!);
      final xMax = double.parse(word.group(3)!);
      final yMax = double.parse(word.group(4)!);
      expect(xMin, greaterThanOrEqualTo(20), reason: '$name clipped left');
      expect(xMax, lessThanOrEqualTo(575), reason: '$name clipped right');
      expect(yMin, greaterThanOrEqualTo(20), reason: '$name clipped top');
      expect(yMax, lessThanOrEqualTo(825), reason: '$name clipped bottom');
    }
    if (multipage) {
      final match = RegExp(r'Pages:\s+(\d+)').firstMatch(info.stdout as String);
      expect(int.parse(match!.group(1)!), greaterThan(1));
    }
    final preview = Platform.environment['PDF_PREVIEW_DIR'];
    if (preview != null) {
      await Directory(preview).create(recursive: true);
      await File('$preview/$name.pdf').writeAsBytes(bytes);
    }
    return text;
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  test(
    'Angebot: Gruppen, Umlaute, Beträge und durchgängiger Briefkopf',
    () async {
      final quote = Quote(
        id: 'q',
        tenantId: 't',
        quoteNumber: 'A-100',
        title: 'Schöne Küche',
        createdAt: date,
        validUntil: DateTime(2026, 11, 10),
        notes: 'Maße vor Ort prüfen.',
        items: [
          const QuoteItem(
            kind: QuoteItemKind.article,
            description: 'Öl für Küche',
            quantity: 2,
            unit: 'Stk',
            unitPrice: 35,
            groupLabel: 'Material',
          ),
        ],
      );
      await verify(
        await buildQuotePdf(quote: quote, tenant: tenant, customer: customer),
        'angebot',
        [
          'Angebot A-100',
          'Müller & Söhne',
          'Büro für schöne Räume',
          'Öl für Küche',
          'Material',
          'Zwischensumme',
          '83.30 EUR',
          'Notizen',
        ],
      );
    },
  );

  test(
    'Rechnung: WaaS-Positionen, Vorrechnungen und zahlbarer Betrag',
    () async {
      final invoice = Invoice(
        id: 'i',
        tenantId: 't',
        invoiceNumber: 'R-200',
        title: 'WaaS – Gerätebetreuung',
        createdAt: date,
        dueDate: DateTime(2026, 10, 24),
        invoiceType: InvoiceType.closingInvoice,
        priorInvoicedTotal: 11.90,
        priorInvoices: [
          const PriorInvoiceRef(
            invoiceNumber: 'R-100',
            invoiceType: InvoiceType.partial,
            totalGross: 11.90,
          ),
        ],
        items: [
          const InvoiceItem(
            kind: InvoiceItemKind.text,
            description: 'WaaS – monatliche Gerätebetreuung',
            quantity: 2,
            unitPrice: 20,
            groupLabel: 'Service',
          ),
        ],
      );
      await verify(
        await buildInvoicePdf(
          invoice: invoice,
          tenant: tenant,
          customer: customer,
        ),
        'rechnung-waas',
        [
          'Rechnung R-200',
          'WaaS – monatliche Gerätebetreuung',
          'Zwischensumme',
          '47.60 EUR',
          'R-100',
          '35.70 EUR',
          'IBAN',
        ],
      );
    },
  );

  test(
    'Lange Rechnung paginiert vollständig und behält alle Positionen',
    () async {
      final invoice = Invoice(
        id: 'i',
        tenantId: 't',
        invoiceNumber: 'R-201',
        title: 'Wartung',
        createdAt: date,
        items: [
          for (var i = 0; i < 55; i++)
            InvoiceItem(
              kind: InvoiceItemKind.text,
              description: 'Gerätewartung Position $i – Prüfung und Übergabe',
              unitPrice: 12,
            ),
        ],
        notes: 'Abschlussprüfung erfolgreich.',
      );
      final extracted = await verify(
        await buildInvoicePdf(
          invoice: invoice,
          tenant: tenant,
          customer: customer,
        ),
        'rechnung-mehrseitig',
        [
          'Gerätewartung Position 0',
          'Gerätewartung Position 54',
          'Abschlussprüfung erfolgreich.',
          'Zu zahlen',
        ],
        multipage: true,
      );
      expect(
        extracted.split('\f').where((page) => page.trim().isNotEmpty),
        everyElement(contains('Beschreibung')),
      );
    },
  );

  test('Bestellung: Lieferanten-SKU und Netto-Gesamt', () async {
    final order = PurchaseOrder(
      id: 'p',
      tenantId: 't',
      purchaseOrderNumber: 'BE-300',
      createdAt: date,
      items: [
        const PurchaseOrderItem(
          articleId: 'a',
          description: 'Dübelgröße M8',
          quantity: 3,
          unitPrice: 4,
        ),
      ],
    );
    await verify(
      await buildPurchaseOrderPdf(
        purchaseOrder: order,
        tenant: tenant,
        supplier: supplier,
        supplierSkus: {'a': 'LIEF-Ö42'},
      ),
      'bestellung',
      [
        'Bestellung BE-300',
        'Schröder Zubehör',
        'LIEF-Ö42',
        'Dübelgröße M8',
        '12.00 EUR',
      ],
    );
  });

  test('Mahnung: Mahnstufe, Gebühren, offener Betrag und Bankdaten', () async {
    final invoice = Invoice(
      id: 'i',
      tenantId: 't',
      invoiceNumber: 'R-400',
      title: 'Überfällige Leistung',
      createdAt: date,
      dueDate: date,
      dunningLevel: 2,
      dunningFeeTotal: 5,
      items: [
        const InvoiceItem(
          kind: InvoiceItemKind.text,
          description: 'Beratung',
          unitPrice: 100,
        ),
      ],
    );
    await verify(
      await buildDunningPdf(
        invoice: invoice,
        tenant: tenant,
        customer: customer,
      ),
      'mahnung',
      [
        '1. Mahnung',
        'R-400',
        'Überfällige Leistung',
        'Mahngebühren',
        '124.00 EUR',
        'IBAN',
      ],
    );
  });
}
