import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../state/auth_controller.dart';

const _dunningLevelLabels = ['Keine Mahnung', 'Zahlungserinnerung', '1. Mahnung', '2. Mahnung'];

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String _formatAmount(double value) => '${value.toStringAsFixed(2)} €';

/// Mahnwesen: listet überfällige, nicht bezahlte Rechnungen mit ihrer
/// aktuellen Mahnstufe. "Mahnung erstellen" erhöht die Mahnstufe und
/// berechnet die zugehörige Mahngebühr; danach kann die Mahnung als PDF
/// geöffnet werden.
class DunningScreen extends StatefulWidget {
  const DunningScreen({super.key});

  @override
  State<DunningScreen> createState() => _DunningScreenState();
}

class _DunningScreenState extends State<DunningScreen> {
  late Future<List<Invoice>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Invoice>> _load() {
    final auth = context.read<AuthController>();
    return auth.apiClient.listOverdueInvoices(auth.token!);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _createDunning(Invoice invoice) async {
    final nextLevel = _dunningLevelLabels[invoice.dunningLevel + 1];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mahnung erstellen?'),
        content: Text(
          'Für Rechnung ${invoice.invoiceNumber} wird die Mahnstufe "$nextLevel" gesetzt '
          'und eine entsprechende Mahngebühr berechnet.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Erstellen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    await auth.apiClient.dunInvoice(token: auth.token!, id: invoice.id);
    _reload();
  }

  Future<void> _openPdf(Invoice invoice) async {
    final auth = context.read<AuthController>();
    final bytes = await auth.apiClient.getDunningPdf(token: auth.token!, id: invoice.id);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'Mahnung-${invoice.invoiceNumber}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mahnwesen')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final invoices = snapshot.data!;
          if (invoices.isEmpty) {
            return const Center(child: Text('Keine überfälligen Rechnungen.'));
          }

          return ListView.builder(
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoices[index];

              return ListTile(
                title: Text('${invoice.invoiceNumber} — ${invoice.title}'),
                subtitle: Text(
                  [
                    if (invoice.dueDate != null) 'Fällig seit ${_formatDate(invoice.dueDate!)}',
                    _dunningLevelLabels[invoice.dunningLevel],
                    'Offen: ${_formatAmount(invoice.totalDue)}',
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (invoice.dunningLevel >= 1)
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        tooltip: 'Mahnung als PDF',
                        onPressed: () => _openPdf(invoice),
                      ),
                    if (invoice.dunningLevel < 3)
                      TextButton(
                        onPressed: () => _createDunning(invoice),
                        child: const Text('Mahnung erstellen'),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
