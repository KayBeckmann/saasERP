import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../formatting.dart';
import '../state/auth_controller.dart';
import '../widgets/status_chip.dart';
import 'invoice_detail_screen.dart';
import 'quote_detail_screen.dart';

String _contractStatusLabel(MaintenanceContractStatus status) => switch (status) {
      MaintenanceContractStatus.active => 'Aktiv',
      MaintenanceContractStatus.cancelled => 'Gekündigt',
    };

StatusTone _contractStatusTone(MaintenanceContractStatus status) => switch (status) {
      MaintenanceContractStatus.active => StatusTone.success,
      MaintenanceContractStatus.cancelled => StatusTone.neutral,
    };

/// Übersicht des Kundenportals: eigene Angebote, Rechnungen und
/// Wartungsverträge/Abos. Bewusst nur Lesezugriff — Freigabe/Ablehnung,
/// PDF-Download und Kündigung folgen in den nächsten M2b-Schritten.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<CustomerPortalOverview> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _loadOverview();
  }

  Future<CustomerPortalOverview> _loadOverview() {
    final auth = context.read<AuthController>();
    return auth.apiClient.getOverview(auth.token!);
  }

  Future<void> _refresh() async {
    final future = _loadOverview();
    setState(() => _overviewFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.tenantName ?? 'Kundenportal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<CustomerPortalOverview>(
          future: _overviewFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Fehler beim Laden: ${snapshot.error}'),
                  ),
                ],
              );
            }

            final overview = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Willkommen, ${auth.customerName ?? ''}!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                _OverviewSection(
                  title: 'Angebote',
                  emptyText: 'Keine Angebote vorhanden.',
                  items: [
                    for (final quote in overview.quotes)
                      _OverviewRow(
                        leading: quote.quoteNumber,
                        title: quote.title,
                        trailing: formatAmount(quote.totalGross),
                        statusLabel: quoteStatusLabel(quote.status),
                        statusTone: quoteStatusTone(quote.status),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => QuoteDetailScreen(quote: quote)),
                          );
                          if (mounted) _refresh();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _OverviewSection(
                  title: 'Rechnungen',
                  emptyText: 'Keine Rechnungen vorhanden.',
                  items: [
                    for (final invoice in overview.invoices)
                      _OverviewRow(
                        leading: invoice.invoiceNumber,
                        title: invoice.title,
                        subtitle: invoice.dueDate != null ? 'Fällig: ${formatDate(invoice.dueDate!)}' : null,
                        trailing: formatAmount(invoice.totalDue),
                        statusLabel: invoiceStatusLabel(invoice.status),
                        statusTone: invoiceStatusTone(invoice.status),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoice: invoice)),
                          );
                          if (mounted) _refresh();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _OverviewSection(
                  title: 'Wartungsverträge/Abos',
                  emptyText: 'Keine Wartungsverträge/Abos vorhanden.',
                  items: [
                    for (final contract in overview.maintenanceContracts)
                      _OverviewRow(
                        leading: contract.contractNumber,
                        title: contract.title,
                        subtitle: 'Laufzeit bis: ${formatDate(contract.endDate)}',
                        statusLabel: _contractStatusLabel(contract.status),
                        statusTone: _contractStatusTone(contract.status),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.title, required this.emptyText, required this.items});

  final String title;
  final String emptyText;
  final List<_OverviewRow> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  emptyText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              )
            else
              for (final item in items) item,
          ],
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.leading,
    required this.title,
    required this.statusLabel,
    required this.statusTone,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String leading;
  final String title;
  final String? subtitle;
  final String? trailing;
  final String statusLabel;
  final StatusTone statusTone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$leading · $title', overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (trailing != null) Text(trailing!),
          const SizedBox(width: 12),
          StatusChip(label: statusLabel, tone: statusTone),
          if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
