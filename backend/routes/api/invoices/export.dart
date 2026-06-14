import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/invoices/export?from=YYYY-MM-DD&to=YYYY-MM-DD — Rechnungen des
/// Mandanten als CSV (Semikolon-getrennt, Komma als Dezimaltrennzeichen —
/// gängige Konvention für den Import in deutsche Buchhaltungssoftware) für
/// den Steuerberater. `from`/`to` filtern auf `created_at`, beide optional.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final query = context.request.uri.queryParameters;
  final from = query['from'] != null ? DateTime.parse(query['from']!) : null;
  final to = query['to'] != null ? DateTime.parse(query['to']!) : null;

  final invoices = await context.read<InvoiceRepository>().listForExport(
        tenantId: auth.tenantId,
        from: from,
        to: to,
      );

  final customerRepository = context.read<CustomerRepository>();
  final customerNames = <String, String>{};
  for (final invoice in invoices) {
    final customerId = invoice.customerId;
    if (customerId == null || customerNames.containsKey(customerId)) continue;
    final customer = await customerRepository.findById(tenantId: auth.tenantId, id: customerId);
    customerNames[customerId] = customer?.name ?? '';
  }

  final lines = <String>[
    'Rechnungsnummer;Rechnungsdatum;Faelligkeit;Kunde;Rechnungstyp;Status;Netto;USt;Brutto',
  ];
  for (final invoice in invoices) {
    final net = invoice.totalNet;
    final gross = invoice.totalGross;
    final vat = gross - net;
    final dueDate = invoice.dueDate;
    lines.add(
      [
        invoice.invoiceNumber,
        _formatDate(invoice.createdAt),
        if (dueDate != null) _formatDate(dueDate) else '',
        customerNames[invoice.customerId] ?? '',
        invoice.invoiceType.toJson(),
        invoice.status.toJson(),
        _formatAmount(net),
        _formatAmount(vat),
        _formatAmount(gross),
      ].join(';'),
    );
  }

  return Response(
    body: '${lines.join('\r\n')}\r\n',
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': 'attachment; filename="rechnungen-export.csv"',
    },
  );
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _formatAmount(double value) => value.toStringAsFixed(2).replaceAll('.', ',');
