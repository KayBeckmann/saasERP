import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../state/auth_controller.dart';
import '../widgets/app_data_table.dart';
import '../widgets/app_shell.dart';

/// Bestandsübersicht — listet alle Artikel mit Lagerbestand und
/// Mindestbestand, Artikel unter dem Mindestbestand werden hervorgehoben.
class StockOverviewScreen extends StatefulWidget {
  const StockOverviewScreen({super.key});

  @override
  State<StockOverviewScreen> createState() => _StockOverviewScreenState();
}

class _StockOverviewScreenState extends State<StockOverviewScreen> {
  late Future<List<Article>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Article>> _load() {
    final auth = context.read<AuthController>();
    return auth.apiClient.listArticles(auth.token!);
  }

  void _reload() => setState(() => _future = _load());

  String _formatNumber(double value) =>
      value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentItem: AppNavItem.stock,
      title: 'Bestandsübersicht',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Aktualisieren',
          onPressed: _reload,
        ),
      ],
      body: FutureBuilder<List<Article>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final articles = [...snapshot.data!]
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          final lowStockCount = articles.where((a) => a.stockQuantity < a.minimumStock).length;

          return Column(
            children: [
              if (lowStockCount > 0)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '$lowStockCount Artikel unter Mindestbestand',
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              Expanded(
                child: AppDataTable(
                  emptyLabel: 'Noch keine Artikel angelegt.',
                  columns: const [
                    AppDataColumn('Artikel', flex: 3),
                    AppDataColumn('Details', flex: 2),
                    AppDataColumn('Mindestbestand', numeric: true, flex: 1),
                    AppDataColumn('Bestand', numeric: true, flex: 1),
                  ],
                  rows: [
                    for (final article in articles)
                      AppDataRow(
                        cells: [
                          Text(article.name),
                          Text(
                            [
                              if (article.sku != null) 'SKU ${article.sku}',
                              if (article.unit != null) article.unit!,
                            ].join(' · '),
                          ),
                          Text(_formatNumber(article.minimumStock)),
                          _StockCell(
                            quantity: article.stockQuantity,
                            belowMinimum: article.stockQuantity < article.minimumStock,
                            formatNumber: _formatNumber,
                          ),
                        ],
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

/// Lagerbestand eines Artikels, hervorgehoben wenn unter Mindestbestand.
class _StockCell extends StatelessWidget {
  const _StockCell({required this.quantity, required this.belowMinimum, required this.formatNumber});

  final double quantity;
  final bool belowMinimum;
  final String Function(double) formatNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatNumber(quantity),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: belowMinimum ? Theme.of(context).colorScheme.error : null,
                fontWeight: belowMinimum ? FontWeight.bold : null,
              ),
        ),
        if (belowMinimum)
          Text(
            'unter Mindestbestand',
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 11),
          ),
      ],
    );
  }
}
