import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/app_data_table.dart';
import '../widgets/app_shell.dart';
import '../widgets/invoice_conversion_dialog.dart';
import '../widgets/status_chip.dart';
import 'invoice_editor_screen.dart';

/// Listet die Rechnungen des Mandanten und erlaubt Anlegen/Bearbeiten/Löschen.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late Future<({List<Invoice> invoices, List<Customer> customers})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<Invoice> invoices, List<Customer> customers})> _load() async {
    final auth = context.read<AuthController>();
    final invoices = await auth.apiClient.listInvoices(auth.token!);
    final customers = await auth.apiClient.listCustomers(auth.token!);
    return (invoices: invoices, customers: customers);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _openEditor({Invoice? invoice}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => InvoiceEditorScreen(invoice: invoice)),
    );
    if (changed ?? false) _reload();
  }

  Future<void> _delete(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechnung löschen?'),
        content: Text('Rechnung ${invoice.invoiceNumber} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    await auth.apiClient.deleteInvoice(token: auth.token!, id: invoice.id);
    _reload();
  }

  Future<void> _showPdf(Invoice invoice) async {
    final auth = context.read<AuthController>();
    try {
      final bytes = await auth.apiClient.getInvoicePdf(token: auth.token!, id: invoice.id);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${invoice.invoiceNumber}.pdf');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF-Fehler: ${e.message}')));
    }
  }

  String? _customerName(String? customerId, List<Customer> customers) {
    if (customerId == null) return null;
    for (final customer in customers) {
      if (customer.id == customerId) return customer.name;
    }
    return null;
  }

  String _statusLabel(InvoiceStatus status) => switch (status) {
        InvoiceStatus.draft => 'Entwurf',
        InvoiceStatus.sent => 'Versendet',
        InvoiceStatus.paid => 'Bezahlt',
        InvoiceStatus.overdue => 'Überfällig',
        InvoiceStatus.cancelled => 'Storniert',
      };

  StatusTone _statusTone(InvoiceStatus status) => switch (status) {
        InvoiceStatus.draft => StatusTone.neutral,
        InvoiceStatus.sent => StatusTone.warning,
        InvoiceStatus.paid => StatusTone.success,
        InvoiceStatus.overdue => StatusTone.error,
        InvoiceStatus.cancelled => StatusTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentItem: AppNavItem.invoices,
      title: 'Rechnungen',
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          return AppDataTable(
            emptyLabel: 'Noch keine Rechnungen vorhanden.',
            columns: const [
              AppDataColumn('Rechnung', flex: 3),
              AppDataColumn('Kunde', flex: 2),
              AppDataColumn('Betrag', numeric: true, flex: 2),
              AppDataColumn('Status', flex: 1),
            ],
            rows: [
              for (final invoice in data.invoices)
                AppDataRow(
                  onTap: () => _openEditor(invoice: invoice),
                  cells: [
                    Text(
                      [
                        '${invoice.invoiceNumber} — ${invoice.title}',
                        if (invoice.invoiceType != InvoiceType.standard)
                          invoiceTypeLabel(invoice.invoiceType),
                      ].join(' · '),
                    ),
                    Text(_customerName(invoice.customerId, data.customers) ?? '-'),
                    Text('${invoice.totalGross.toStringAsFixed(2)} €'),
                    StatusChip(label: _statusLabel(invoice.status), tone: _statusTone(invoice.status)),
                  ],
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        tooltip: 'PDF',
                        onPressed: () => _showPdf(invoice),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Löschen',
                        onPressed: () => _delete(invoice),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
