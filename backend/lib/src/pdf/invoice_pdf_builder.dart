import 'dart:typed_data';
import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:saaserp_shared/saaserp_shared.dart';
import 'document_style.dart';

/// Erzeugt das PDF-Dokument für eine Rechnung — Briefkopf mit
/// Mandanten-Stammdaten, Kundenadresse, Positionstabelle (gruppiert nach
/// [InvoiceItem.groupLabel] mit Zwischensummen je Gruppe), Zahlungsstatus
/// sowie Gesamt- und Zahlbetrag und Notizen.
Future<Uint8List> buildInvoicePdf({
  required Invoice invoice,
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
            'Rechnung ${invoice.invoiceNumber}',
            style: pw.TextStyle(
              font: style.bold,
              color: DocumentStyle.navy,
              fontSize: 20,
            ),
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
                pw.Text('Gesamt netto: ${_formatAmount(invoice.totalNet)}'),
                pw.Text(
                  'Gesamt brutto: ${_formatAmount(invoice.totalGross)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (invoice.priorInvoices.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Bereits in Rechnung gestellt:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  for (final prior in invoice.priorInvoices)
                    pw.SizedBox(
                      width: 280,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '  ${prior.invoiceNumber} '
                            '(${_invoiceTypeLabel(prior.invoiceType)})',
                          ),
                          pw.Text('- ${_formatAmount(prior.totalGross)}'),
                        ],
                      ),
                    ),
                  pw.Divider(thickness: 0.5),
                ] else if (invoice.priorInvoicedTotal != null)
                  pw.Text(
                    'Bereits in Rechnung gestellt: ${_formatAmount(invoice.priorInvoicedTotal!)}',
                  ),
                if (invoice.dunningFeeTotal > 0)
                  pw.Text(
                    'Mahngebühren: ${_formatAmount(invoice.dunningFeeTotal)}',
                  ),
                pw.Text(
                  'Zu zahlen: ${_formatAmount(invoice.totalDue)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          if (invoice.notes != null && invoice.notes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            style.section('Notizen'),
            pw.Text(invoice.notes!),
          ],
          if (tenant.companyIban != null) ...[
            pw.SizedBox(height: 16),
            style.payment(
              tenant,
              'Bitte überweisen Sie den Betrag auf folgendes Konto:',
            ),
          ],
        ],
      ),
    );

  return doc.save();
}

pw.Widget _itemsTable(List<InvoiceItem> items, DocumentStyle style) {
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

String _invoiceTypeLabel(InvoiceType type) => switch (type) {
  InvoiceType.standard => 'Rechnung',
  InvoiceType.partial => 'Materialabschlag',
  InvoiceType.downPayment => 'Abschlagsrechnung',
  InvoiceType.closingInvoice => 'Schlussrechnung',
};
