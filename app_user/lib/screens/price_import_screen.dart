import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/app_shell.dart';

/// Preisimport für Artikel-Einkaufspreise: CSV (`sku,einkaufspreis`) wird
/// eingefügt, betroffene Artikel werden aktualisiert und für Produkte mit
/// geänderten Kosten wird ein Verkaufspreis-Vorschlag berechnet
/// ("Vorschlag mit Bestätigung" — Confirm/Reject direkt hier).
class PriceImportScreen extends StatefulWidget {
  const PriceImportScreen({super.key});

  @override
  State<PriceImportScreen> createState() => _PriceImportScreenState();
}

class _PriceImportScreenState extends State<PriceImportScreen> {
  final _csvController = TextEditingController();
  bool _importing = false;
  String? _error;
  ArticlePriceImportResult? _result;

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final csv = _csvController.text.trim();
    if (csv.isEmpty) return;

    setState(() {
      _importing = true;
      _error = null;
    });

    final auth = context.read<AuthController>();
    try {
      final result = await auth.apiClient.importArticlePrices(token: auth.token!, csv: csv);
      setState(() => _result = result);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _confirmSuggestion(ProductPriceSuggestion suggestion) async {
    final auth = context.read<AuthController>();
    await auth.apiClient.confirmProductPrice(token: auth.token!, id: suggestion.productId);
    _removeSuggestion(suggestion);
  }

  Future<void> _rejectSuggestion(ProductPriceSuggestion suggestion) async {
    final auth = context.read<AuthController>();
    await auth.apiClient.rejectProductPrice(token: auth.token!, id: suggestion.productId);
    _removeSuggestion(suggestion);
  }

  void _removeSuggestion(ProductPriceSuggestion suggestion) {
    final result = _result;
    if (result == null) return;
    setState(() {
      _result = ArticlePriceImportResult(
        updatedArticles: result.updatedArticles,
        notFoundSkus: result.notFoundSkus,
        productSuggestions: result.productSuggestions.where((s) => s.productId != suggestion.productId).toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return AppShell(
      currentItem: AppNavItem.articles,
      title: 'Preisimport',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CSV einfügen (Spalten: SKU, Einkaufspreis — Trenner Komma oder Semikolon, '
              'eine optionale Kopfzeile wird automatisch erkannt).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _csvController,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'sku;einkaufspreis\nART-001;12.50\nART-002;7.90',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _importing ? null : _import,
                child: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Importieren'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (result != null) ...[
              const Divider(height: 32),
              Text('Aktualisierte Artikel (${result.updatedArticles.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              if (result.updatedArticles.isEmpty) const Text('Keine Artikel aktualisiert.'),
              for (final update in result.updatedArticles)
                ListTile(
                  dense: true,
                  title: Text('${update.name} (${update.sku})'),
                  subtitle: Text(
                    '${update.oldPurchasePrice?.toStringAsFixed(2) ?? '–'} € → '
                    '${update.newPurchasePrice.toStringAsFixed(2)} €',
                  ),
                ),
              const SizedBox(height: 16),
              Text('Nicht gefundene SKUs (${result.notFoundSkus.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              if (result.notFoundSkus.isEmpty)
                const Text('Alle SKUs zugeordnet.')
              else
                Text(result.notFoundSkus.join(', ')),
              const SizedBox(height: 16),
              Text('Preisvorschläge für Produkte (${result.productSuggestions.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              if (result.productSuggestions.isEmpty) const Text('Keine betroffenen Produkte.'),
              for (final suggestion in result.productSuggestions)
                ListTile(
                  dense: true,
                  title: Text(suggestion.name),
                  subtitle: Text(
                    'VK ${suggestion.oldSalePrice.toStringAsFixed(2)} € → '
                    '${suggestion.pendingSalePrice.toStringAsFixed(2)} €',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        tooltip: 'Übernehmen',
                        onPressed: () => _confirmSuggestion(suggestion),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Verwerfen',
                        onPressed: () => _rejectSuggestion(suggestion),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
