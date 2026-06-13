import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:saaserp_shared/saaserp_shared.dart';

/// Erzeugt das PDF-Dokument für ein Angebot — Briefkopf mit
/// Mandanten-Stammdaten, Kundenadresse, Positionstabelle (gruppiert nach
/// [QuoteItem.groupLabel] mit Zwischensummen je Gruppe) sowie Gesamtsumme
/// und Notizen.
Future<Uint8List> buildQuotePdf({
  required Quote quote,
  required Tenant tenant,
  Customer? customer,
}) async {
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
            if (tenant.companyAddress != null) pw.Text(tenant.companyAddress!),
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
          if (customer != null) ...[
            pw.Text(customer.name),
            if (customer.address != null) pw.Text(customer.address!),
            pw.SizedBox(height: 16),
          ],
          pw.Text(
            'Angebot ${quote.quoteNumber}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(quote.title, style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 4),
          pw.Text('Datum: ${_formatDate(quote.createdAt)}'),
          if (quote.validUntil != null)
            pw.Text('Gültig bis: ${_formatDate(quote.validUntil!)}'),
          pw.SizedBox(height: 16),
          for (final group in quote.groupedItems) ...[
            if (group.label != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  group.label!,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            _itemsTable(group.items),
            if (group.label != null)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    'Zwischensumme: ${_formatAmount(group.totalNet)} netto / '
                    '${_formatAmount(group.totalGross)} brutto',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ),
            pw.SizedBox(height: 12),
          ],
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Gesamt netto: ${_formatAmount(quote.totalNet)}'),
                pw.Text(
                  'Gesamt brutto: ${_formatAmount(quote.totalGross)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          if (quote.notes != null && quote.notes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Notizen',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(quote.notes!),
          ],
        ],
      ),
    );

  return doc.save();
}

pw.Widget _itemsTable(List<QuoteItem> items) {
  return pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(4),
      1: pw.FlexColumnWidth(1.2),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(),
      4: pw.FlexColumnWidth(1.5),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _cell('Beschreibung', bold: true),
          _cell('Menge', bold: true, align: pw.TextAlign.right),
          _cell('Einzelpreis', bold: true, align: pw.TextAlign.right),
          _cell('MwSt.', bold: true, align: pw.TextAlign.right),
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
              '${_formatNumber(item.vatRate)} %',
              align: pw.TextAlign.right,
            ),
            _cell(_formatAmount(item.totalNet), align: pw.TextAlign.right),
          ],
        ),
    ],
  );
}

pw.Widget _cell(
  String text, {
  bool bold = false,
  pw.TextAlign align = pw.TextAlign.left,
}) => pw.Padding(
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

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
