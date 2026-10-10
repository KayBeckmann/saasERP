import 'dart:typed_data';
import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:saaserp_shared/saaserp_shared.dart';
import 'document_style.dart';

/// Erzeugt das PDF-Dokument für ein Angebot — Briefkopf mit
/// Mandanten-Stammdaten, Kundenadresse, Positionstabelle (gruppiert nach
/// [QuoteItem.groupLabel] mit Zwischensummen je Gruppe) sowie Gesamtsumme
/// und Notizen.
Future<Uint8List> buildQuotePdf({
  required Quote quote,
  required Tenant tenant,
  Customer? customer,
}) async {
  final style = await DocumentStyle.load();
  final doc = pw.Document(theme: style.theme)
    ..addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(44, 42, 44, 48),
        header: (context) => style.header(tenant),
        footer: (context) => style.footer(context, tenant),
        build: (context) => [
          if (customer != null) ...[
            style.recipient('Empfänger', customer.name, customer.address),
            pw.SizedBox(height: 16),
          ],
          pw.Text(
            'Angebot ${quote.quoteNumber}',
            style: pw.TextStyle(
              font: style.bold,
              color: DocumentStyle.navy,
              fontSize: 20,
            ),
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
            _itemsTable(group.items, style),
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
            style.section('Notizen'),
            pw.Text(quote.notes!),
          ],
        ],
      ),
    );

  return doc.save();
}

pw.Widget _itemsTable(List<QuoteItem> items, DocumentStyle style) {
  return pw.Table(
    border: pw.TableBorder(
      horizontalInside: pw.BorderSide(color: DocumentStyle.rule, width: 0.5),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(4),
      1: pw.FlexColumnWidth(1.2),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(),
      4: pw.FlexColumnWidth(1.5),
    },
    children: [
      style.heading(
        [
          style.cell('Beschreibung', boldText: true),
          style.cell('Menge', boldText: true, align: pw.TextAlign.right),
          style.cell('Einzelpreis', boldText: true, align: pw.TextAlign.right),
          style.cell('MwSt.', boldText: true, align: pw.TextAlign.right),
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
              '${_formatNumber(item.vatRate)} %',
              align: pw.TextAlign.right,
            ),
            style.cell(_formatAmount(item.totalNet), align: pw.TextAlign.right),
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
