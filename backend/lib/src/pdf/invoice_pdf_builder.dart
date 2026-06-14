import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:saaserp_shared/saaserp_shared.dart';

/// Erzeugt das PDF-Dokument für eine Rechnung — Briefkopf mit
/// Mandanten-Stammdaten, Kundenadresse, Positionstabelle (gruppiert nach
/// [InvoiceItem.groupLabel] mit Zwischensummen je Gruppe), Zahlungsstatus
/// sowie Gesamt- und Zahlbetrag und Notizen.
Future<Uint8List> buildInvoicePdf({
  required Invoice invoice,
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
            'Rechnung ${invoice.invoiceNumber}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(invoice.title, style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 4),
          pw.Text('Datum: ${_formatDate(invoice.createdAt)}'),
          if (invoice.dueDate != null)
            pw.Text('Fällig am: ${_formatDate(invoice.dueDate!)}'),
          pw.Text('Status: ${_statusLabel(invoice.status)}'),
          pw.SizedBox(height: 16),
          for (final group in invoice.groupedItems) ...[
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
                pw.Text('Gesamt netto: ${_formatAmount(invoice.totalNet)}'),
                pw.Text(
                  'Gesamt brutto: ${_formatAmount(invoice.totalGross)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (invoice.priorInvoicedTotal != null)
                  pw.Text(
                    'Bereits in Rechnung gestellt: ${_formatAmount(invoice.priorInvoicedTotal!)}',
                  ),
                if (invoice.dunningFeeTotal > 0)
                  pw.Text('Mahngebühren: ${_formatAmount(invoice.dunningFeeTotal)}'),
                pw.Text(
                  'Zu zahlen: ${_formatAmount(invoice.totalDue)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          if (invoice.notes != null && invoice.notes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Notizen',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(invoice.notes!),
          ],
        ],
      ),
    );

  return doc.save();
}

pw.Widget _itemsTable(List<InvoiceItem> items) {
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

String _statusLabel(InvoiceStatus status) => switch (status) {
      InvoiceStatus.draft => 'Entwurf',
      InvoiceStatus.sent => 'Versendet',
      InvoiceStatus.paid => 'Bezahlt',
      InvoiceStatus.overdue => 'Überfällig',
      InvoiceStatus.cancelled => 'Storniert',
    };

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String _formatAmount(double value) => '${value.toStringAsFixed(2)} EUR';

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
