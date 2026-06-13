import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:saaserp_shared/saaserp_shared.dart';

/// Erzeugt das PDF-Dokument für eine Mahnung — Briefkopf mit
/// Mandanten-Stammdaten, Kundenadresse, Mahnstufen-Text passend zu
/// [Invoice.dunningLevel] sowie eine Übersicht über Rechnungsbetrag,
/// bisherige Mahngebühren und Gesamtbetrag.
Future<Uint8List> buildDunningPdf({
  required Invoice invoice,
  required Tenant tenant,
  Customer? customer,
}) async {
  final title = _dunningTitle(invoice.dunningLevel);
  final intro = _dunningIntro(invoice.dunningLevel);

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
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Datum: ${_formatDate(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.Text(intro),
          pw.SizedBox(height: 16),
          _summaryTable(invoice),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Offener Gesamtbetrag: ${_formatAmount(invoice.totalDue)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(_dunningClosing(invoice.dunningLevel)),
        ],
      ),
    );

  return doc.save();
}

pw.Widget _summaryTable(Invoice invoice) {
  return pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(3),
      1: pw.FlexColumnWidth(1.5),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _cell('Position', bold: true),
          _cell('Betrag', bold: true, align: pw.TextAlign.right),
        ],
      ),
      pw.TableRow(
        children: [
          _cell('Rechnung ${invoice.invoiceNumber} — ${invoice.title}'),
          _cell(_formatAmount(invoice.amountDue), align: pw.TextAlign.right),
        ],
      ),
      if (invoice.dueDate != null)
        pw.TableRow(
          children: [
            _cell('Fällig seit'),
            _cell(_formatDate(invoice.dueDate!), align: pw.TextAlign.right),
          ],
        ),
      if (invoice.dunningFeeTotal > 0)
        pw.TableRow(
          children: [
            _cell('Mahngebühren'),
            _cell(_formatAmount(invoice.dunningFeeTotal), align: pw.TextAlign.right),
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

String _dunningTitle(int dunningLevel) => switch (dunningLevel) {
      1 => 'Zahlungserinnerung',
      2 => '1. Mahnung',
      _ => '2. Mahnung',
    };

String _dunningIntro(int dunningLevel) => switch (dunningLevel) {
      1 => 'Mit dieser Zahlungserinnerung weisen wir Sie freundlich darauf hin, dass die folgende '
          'Rechnung noch nicht ausgeglichen wurde:',
      2 => 'Trotz Fälligkeit konnten wir bisher keinen Zahlungseingang zu folgender Rechnung '
          'feststellen. Wir bitten Sie, den offenen Betrag zeitnah zu begleichen:',
      _ => 'Wir haben Sie bereits gemahnt, der offene Betrag wurde jedoch weiterhin nicht '
          'ausgeglichen. Wir fordern Sie letztmalig zur Zahlung der folgenden Rechnung auf:',
    };

String _dunningClosing(int dunningLevel) => switch (dunningLevel) {
      1 => 'Sollte Ihre Zahlung bereits erfolgt sein, betrachten Sie dieses Schreiben als '
          'gegenstandslos. Andernfalls bitten wir um Ausgleich innerhalb von 7 Tagen.',
      2 => 'Wir bitten um Ausgleich des Gesamtbetrags innerhalb von 7 Tagen. Bei weiterem '
          'Zahlungsverzug behalten wir uns weitere Schritte vor.',
      _ => 'Bitte begleichen Sie den Gesamtbetrag innerhalb von 7 Tagen, um weitere Schritte zu '
          'vermeiden.',
    };

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String _formatAmount(double value) => '${value.toStringAsFixed(2)} EUR';
