import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:saaserp_shared/saaserp_shared.dart';

/// Shared, offline A4 letterhead. Bundled DejaVu fonts support German text,
/// punctuation and searchable Unicode. Previous issued documents are not changed.
class DocumentStyle {
  DocumentStyle._(this.regular, this.bold);

  final pw.Font regular;
  final pw.Font bold;

  static final PdfColor navy = PdfColor.fromHex('193048');
  static final PdfColor teal = PdfColor.fromHex('147D83');
  static final PdfColor muted = PdfColor.fromHex('596D7B');
  static final PdfColor pale = PdfColor.fromHex('EEF5F5');
  static final PdfColor rule = PdfColor.fromHex('D7E3E6');

  static Future<DocumentStyle>? _cached;
  static Future<DocumentStyle> load() => _cached ??= _load();

  static Future<DocumentStyle> _load() async {
    Future<pw.Font> font(String filename) async {
      final uri = await Isolate.resolvePackageUri(
        Uri.parse('package:backend/src/pdf/fonts/$filename'),
      );
      if (uri == null) {
        throw StateError('Bundled PDF font unavailable: $filename');
      }
      final bytes = await File.fromUri(uri).readAsBytes();
      return pw.Font.ttf(ByteData.sublistView(bytes));
    }

    return DocumentStyle._(
      await font('DejaVuSans.ttf'),
      await font('DejaVuSans-Bold.ttf'),
    );
  }

  pw.ThemeData get theme =>
      pw.ThemeData.withFont(base: regular, bold: bold).copyWith(
        defaultTextStyle: pw.TextStyle(
          font: regular,
          fontSize: 9,
          color: navy,
          lineSpacing: 3,
        ),
      );

  pw.Widget header(Tenant tenant) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(height: 4, color: teal),
      pw.SizedBox(height: 15),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              tenant.name,
              style: pw.TextStyle(font: bold, fontSize: 16, color: navy),
            ),
          ),
          pw.SizedBox(width: 25),
          pw.Expanded(
            child: pw.Text(
              [
                if (tenant.companyAddress?.trim().isNotEmpty == true)
                  tenant.companyAddress!.trim(),
                if (tenant.companyTaxId?.trim().isNotEmpty == true)
                  'USt-IdNr.: ${tenant.companyTaxId}',
              ].join('\n'),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: regular, fontSize: 8, color: muted),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Container(height: 0.7, color: rule),
      pw.SizedBox(height: 18),
    ],
  );

  pw.Widget footer(pw.Context context, Tenant tenant) => pw.Column(
    children: [
      pw.Container(height: 0.7, color: rule),
      pw.SizedBox(height: 7),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              [
                tenant.name,
                if (tenant.companyIban?.trim().isNotEmpty == true)
                  tenant.companyIban!,
              ].join('  ·  '),
              maxLines: 2,
              style: pw.TextStyle(font: regular, color: muted, fontSize: 7),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount}',
            style: pw.TextStyle(font: regular, color: muted, fontSize: 8),
          ),
        ],
      ),
    ],
  );

  pw.Widget recipient(
    String label,
    String name,
    String? address, {
    String? contact,
  }) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: pw.BoxDecoration(
      color: pale,
      border: pw.Border(left: pw.BorderSide(color: teal, width: 2)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            font: bold,
            fontSize: 7,
            color: teal,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 10)),
        if (address?.trim().isNotEmpty == true) pw.Text(address!),
        if (contact?.trim().isNotEmpty == true) pw.Text(contact!),
      ],
    ),
  );

  pw.Widget section(String label) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 6, bottom: 7),
    child: pw.Text(
      label,
      style: pw.TextStyle(font: bold, color: teal, fontSize: 10),
    ),
  );

  pw.Widget cell(
    String text, {
    bool boldText = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 5),
    child: pw.Text(
      text,
      textAlign: align,
      softWrap: true,
      style: pw.TextStyle(
        font: boldText ? bold : regular,
        color: navy,
        fontSize: 8.1,
        lineSpacing: 2,
      ),
    ),
  );

  pw.TableRow heading(List<pw.Widget> children) => pw.TableRow(
    decoration: pw.BoxDecoration(color: pale),
    repeat: true,
    children: children,
  );

  pw.Widget payment(Tenant tenant, String instruction) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: pale,
      border: pw.Border(left: pw.BorderSide(color: teal, width: 2)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Zahlungshinweis',
          style: pw.TextStyle(font: bold, color: teal),
        ),
        pw.SizedBox(height: 4),
        pw.Text(instruction),
        pw.Text('IBAN: ${tenant.companyIban}', style: pw.TextStyle(font: bold)),
        pw.Text('Empfänger: ${tenant.name}'),
      ],
    ),
  );
}
