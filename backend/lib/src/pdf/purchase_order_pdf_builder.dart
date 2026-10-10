import 'dart:typed_data';
import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:saaserp_shared/saaserp_shared.dart';
import 'document_style.dart';

/// Erzeugt das PDF-Dokument für eine Bestellung — Mandanten-Briefkopf,
/// Lieferantenadresse, Positionstabelle mit Menge und Einzelpreis, Gesamtsumme.
/// [supplierSkus] bildet article_id → Lieferanten-Artikelnummer; Einträge
/// ohne Treffer oder Freitextpositionen bleiben leer.
Future<Uint8List> buildPurchaseOrderPdf({
  required PurchaseOrder purchaseOrder,
  required Tenant tenant,
  Supplier? supplier,
  Map<String, String?> supplierSkus = const {},
}) async {
  final totalNet = purchaseOrder.items.fold<double>(
    0,
    (s, i) => s + i.quantity * i.unitPrice,
  );

  final style = await DocumentStyle.load();
  final doc = pw.Document(theme: style.theme)
    ..addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(44, 42, 44, 48),
        header: (context) => style.header(tenant),
        footer: (context) => style.footer(context, tenant),
        build: (context) => [
          if (supplier != null) ...[
            style.recipient(
              'Lieferant',
              supplier.name,
              supplier.address,
              contact: supplier.email,
            ),
            pw.SizedBox(height: 16),
          ],
          pw.Text(
            'Bestellung ${purchaseOrder.purchaseOrderNumber}',
            style: pw.TextStyle(
              font: style.bold,
              color: DocumentStyle.navy,
              fontSize: 20,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Datum: ${_formatDate(purchaseOrder.createdAt)}'),
          pw.SizedBox(height: 16),
          _itemsTable(purchaseOrder.items, supplierSkus, style),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Gesamt netto: ${_formatAmount(totalNet)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (purchaseOrder.notes != null &&
              purchaseOrder.notes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            style.section('Notizen'),
            pw.Text(purchaseOrder.notes!),
          ],
        ],
      ),
    );

  return doc.save();
}

pw.Widget _itemsTable(
  List<PurchaseOrderItem> items,
  Map<String, String?> supplierSkus,
  DocumentStyle style,
) {
  final hasSkus = items.any(
    (i) => i.articleId != null && (supplierSkus[i.articleId] ?? '').isNotEmpty,
  );

  return pw.Table(
    border: pw.TableBorder(
      horizontalInside: pw.BorderSide(color: DocumentStyle.rule, width: 0.5),
    ),
    columnWidths: hasSkus
        ? const {
            0: pw.FlexColumnWidth(1.8),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(1.5),
            4: pw.FlexColumnWidth(1.5),
          }
        : const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(1.5),
          },
    children: [
      style.heading(
        [
          if (hasSkus) style.cell('Lief.-Art.-Nr.', boldText: true),
          style.cell('Beschreibung', boldText: true),
          style.cell('Menge', boldText: true, align: pw.TextAlign.right),
          style.cell('Einzelpreis', boldText: true, align: pw.TextAlign.right),
          style.cell(
            'Gesamt (netto)',
            boldText: true,
            align: pw.TextAlign.right,
          ),
        ],
      ),
      for (final item in items)
        pw.TableRow(
          children: [
            if (hasSkus)
              style.cell(
                item.articleId != null
                    ? (supplierSkus[item.articleId] ?? '')
                    : '',
              ),
            style.cell(item.description),
            style.cell(
              '${_formatNumber(item.quantity)}${item.unit != null ? ' ${item.unit}' : ''}',
              align: pw.TextAlign.right,
            ),
            style.cell(
              _formatAmount(item.unitPrice),
              align: pw.TextAlign.right,
            ),
            style.cell(
              _formatAmount(item.quantity * item.unitPrice),
              align: pw.TextAlign.right,
            ),
          ],
        ),
    ],
  );
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String _formatAmount(double value) => '${value.toStringAsFixed(2)} EUR';

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
