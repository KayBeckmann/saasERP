import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:saaserp_shared/saaserp_shared.dart';

/// Erzeugt das PDF-Dokument für eine Bestellung — Mandanten-Briefkopf,
/// Lieferantenadresse, Positionstabelle mit Menge und Einzelpreis, Gesamtsumme.
Future<Uint8List> buildPurchaseOrderPdf({
  required PurchaseOrder purchaseOrder,
  required Tenant tenant,
  Supplier? supplier,
}) async {
  final totalNet = purchaseOrder.items
      .fold<double>(0, (s, i) => s + i.quantity * i.unitPrice);

  final doc = pw.Document()
    ..addPage(
      pw.MultiPage(
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              tenant.name,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            if (tenant.companyAddress != null)
              pw.Text(tenant.companyAddress!),
            if (tenant.companyTaxId != null)
              pw.Text('USt-IdNr.: ${tenant.companyTaxId}'),
            pw.SizedBox(height: 16),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ),
        build: (context) => [
          if (supplier != null) ...[
            pw.Text(supplier.name),
            if (supplier.address != null) pw.Text(supplier.address!),
            if (supplier.email != null) pw.Text(supplier.email!),
            pw.SizedBox(height: 16),
          ],
          pw.Text(
            'Bestellung ${purchaseOrder.purchaseOrderNumber}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Datum: ${_formatDate(purchaseOrder.createdAt)}'),
          pw.SizedBox(height: 16),
          _itemsTable(purchaseOrder.items),
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
            pw.Text(
              'Notizen',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(purchaseOrder.notes!),
          ],
        ],
      ),
    );

  return doc.save();
}

pw.Widget _itemsTable(List<PurchaseOrderItem> items) {
  return pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(4),
      1: pw.FlexColumnWidth(1.2),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(1.5),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _cell('Beschreibung', bold: true),
          _cell('Menge', bold: true, align: pw.TextAlign.right),
          _cell('Einzelpreis', bold: true, align: pw.TextAlign.right),
          _cell('Gesamt (netto)', bold: true, align: pw.TextAlign.right),
        ],
      ),
      for (final item in items)
        pw.TableRow(
          children: [
            _cell(item.description),
            _cell(
              '${_formatNumber(item.quantity)}${item.unit != null ? ' ${item.unit}' : ''}',
              align: pw.TextAlign.right,
            ),
            _cell(_formatAmount(item.unitPrice), align: pw.TextAlign.right),
            _cell(
              _formatAmount(item.quantity * item.unitPrice),
              align: pw.TextAlign.right,
            ),
          ],
        ),
    ],
  );
}

pw.Widget _cell(
  String text, {
  bool bold = false,
  pw.TextAlign align = pw.TextAlign.left,
}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String _formatAmount(double value) => '${value.toStringAsFixed(2)} EUR';

String _formatNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
