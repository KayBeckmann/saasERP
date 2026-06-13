import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../state/auth_controller.dart';
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

  Color _statusColor(InvoiceStatus status, BuildContext context) => switch (status) {
        InvoiceStatus.draft => Theme.of(context).colorScheme.surfaceContainerHighest,
        InvoiceStatus.sent => Colors.blue.shade100,
        InvoiceStatus.paid => Colors.green.shade100,
        InvoiceStatus.overdue => Colors.orange.shade100,
        InvoiceStatus.cancelled => Colors.red.shade100,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rechnungen')),
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
          if (data.invoices.isEmpty) {
            return const Center(child: Text('Noch keine Rechnungen vorhanden.'));
          }

          return ListView.builder(
            itemCount: data.invoices.length,
            itemBuilder: (context, index) {
              final invoice = data.invoices[index];
              final customerName = _customerName(invoice.customerId, data.customers);

              return ListTile(
                title: Text('${invoice.invoiceNumber} — ${invoice.title}'),
                subtitle: Text(
                  [
                    ?customerName,
                    '${invoice.totalGross.toStringAsFixed(2)} €',
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(invoice.status, context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_statusLabel(invoice.status)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Löschen',
                      onPressed: () => _delete(invoice),
                    ),
                  ],
                ),
                onTap: () => _openEditor(invoice: invoice),
              );
            },
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
