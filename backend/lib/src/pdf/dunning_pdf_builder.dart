import 'dart:typed_data';
import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:saaserp_shared/saaserp_shared.dart';
import 'document_style.dart';

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
            title,
            style: pw.TextStyle(
              font: style.bold,
              color: DocumentStyle.navy,
              fontSize: 20,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Datum: ${_formatDate(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.Text(intro),
          pw.SizedBox(height: 16),
          _summaryTable(invoice, style),
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
          if (tenant.companyIban != null) ...[
            pw.SizedBox(height: 16),
            style.payment(
              tenant,
              'Bitte überweisen Sie den offenen Betrag auf folgendes Konto:',
            ),
          ],
        ],
      ),
    );

  return doc.save();
}

pw.Widget _summaryTable(Invoice invoice, DocumentStyle style) {
  return pw.Table(
    border: pw.TableBorder(
      horizontalInside: pw.BorderSide(color: DocumentStyle.rule, width: 0.5),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(3),
      1: pw.FlexColumnWidth(1.5),
    },
    children: [
      style.heading(
        [
          style.cell('Position', boldText: true),
          style.cell('Betrag', boldText: true, align: pw.TextAlign.right),
        ],
      ),
      pw.TableRow(
        children: [
          style.cell('Rechnung ${invoice.invoiceNumber} — ${invoice.title}'),
          style.cell(
            _formatAmount(invoice.amountDue),
            align: pw.TextAlign.right,
          ),
        ],
      ),
      if (invoice.dueDate != null)
        pw.TableRow(
          children: [
            style.cell('Fällig seit'),
            style.cell(
              _formatDate(invoice.dueDate!),
              align: pw.TextAlign.right,
            ),
          ],
        ),
      if (invoice.dunningFeeTotal > 0)
        pw.TableRow(
          children: [
            style.cell('Mahngebühren'),
            style.cell(
              _formatAmount(invoice.dunningFeeTotal),
              align: pw.TextAlign.right,
            ),
          ],
        ),
    ],
  );
}

String _dunningTitle(int dunningLevel) => switch (dunningLevel) {
  1 => 'Zahlungserinnerung',
  2 => '1. Mahnung',
  _ => '2. Mahnung',
};

String _dunningIntro(int dunningLevel) => switch (dunningLevel) {
  1 =>
    'Mit dieser Zahlungserinnerung weisen wir Sie freundlich darauf hin, dass die folgende '
        'Rechnung noch nicht ausgeglichen wurde:',
  2 =>
    'Trotz Fälligkeit konnten wir bisher keinen Zahlungseingang zu folgender Rechnung '
        'feststellen. Wir bitten Sie, den offenen Betrag zeitnah zu begleichen:',
  _ =>
    'Wir haben Sie bereits gemahnt, der offene Betrag wurde jedoch weiterhin nicht '
        'ausgeglichen. Wir fordern Sie letztmalig zur Zahlung der folgenden Rechnung auf:',
};

String _dunningClosing(int dunningLevel) => switch (dunningLevel) {
  1 =>
    'Sollte Ihre Zahlung bereits erfolgt sein, betrachten Sie dieses Schreiben als '
        'gegenstandslos. Andernfalls bitten wir um Ausgleich innerhalb von 7 Tagen.',
  2 =>
    'Wir bitten um Ausgleich des Gesamtbetrags innerhalb von 7 Tagen. Bei weiterem '
        'Zahlungsverzug behalten wir uns weitere Schritte vor.',
  _ =>
    'Bitte begleichen Sie den Gesamtbetrag innerhalb von 7 Tagen, um weitere Schritte zu '
        'vermeiden.',
};

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String _formatAmount(double value) => '${value.toStringAsFixed(2)} EUR';
