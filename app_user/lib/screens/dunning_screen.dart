import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../state/auth_controller.dart';
import '../widgets/app_data_table.dart';
import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';

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

  StatusTone _levelTone(int level) => switch (level) {
        0 => StatusTone.neutral,
        1 => StatusTone.warning,
        _ => StatusTone.error,
      };

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentItem: AppNavItem.dunning,
      title: 'Mahnwesen',
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
          return AppDataTable(
            emptyLabel: 'Keine überfälligen Rechnungen.',
            trailingWidth: 180,
            columns: const [
              AppDataColumn('Rechnung', flex: 3),
              AppDataColumn('Fällig seit', flex: 2),
              AppDataColumn('Mahnstufe', flex: 2),
              AppDataColumn('Offen', numeric: true, flex: 2),
            ],
            rows: [
              for (final invoice in invoices)
                AppDataRow(
                  cells: [
                    Text('${invoice.invoiceNumber} — ${invoice.title}'),
                    Text(invoice.dueDate != null ? _formatDate(invoice.dueDate!) : '-'),
                    StatusChip(
                      label: _dunningLevelLabels[invoice.dunningLevel],
                      tone: _levelTone(invoice.dunningLevel),
                    ),
                    Text(_formatAmount(invoice.totalDue)),
                  ],
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
                          child: const Text('Mahnen'),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
