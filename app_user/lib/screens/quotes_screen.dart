import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';

import '../state/auth_controller.dart';
import 'quote_editor_screen.dart';

/// Listet die Angebote des Mandanten und erlaubt Anlegen/Bearbeiten/Löschen.
class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  late Future<({List<Quote> quotes, List<Customer> customers})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<Quote> quotes, List<Customer> customers})> _load() async {
    final auth = context.read<AuthController>();
    final quotes = await auth.apiClient.listQuotes(auth.token!);
    final customers = await auth.apiClient.listCustomers(auth.token!);
    return (quotes: quotes, customers: customers);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _openEditor({Quote? quote}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => QuoteEditorScreen(quote: quote)),
    );
    if (changed ?? false) _reload();
  }

  Future<void> _delete(Quote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Angebot löschen?'),
        content: Text('Angebot ${quote.quoteNumber} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    await auth.apiClient.deleteQuote(token: auth.token!, id: quote.id);
    _reload();
  }

  Future<void> _showPdf(Quote quote) async {
    final auth = context.read<AuthController>();
    try {
      final bytes = await auth.apiClient.getQuotePdf(token: auth.token!, id: quote.id);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${quote.quoteNumber}.pdf');
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

  String _statusLabel(QuoteStatus status) => switch (status) {
        QuoteStatus.draft => 'Entwurf',
        QuoteStatus.sent => 'Versendet',
        QuoteStatus.accepted => 'Angenommen',
        QuoteStatus.rejected => 'Abgelehnt',
      };

  Color _statusColor(QuoteStatus status, BuildContext context) => switch (status) {
        QuoteStatus.draft => Theme.of(context).colorScheme.surfaceContainerHighest,
        QuoteStatus.sent => Colors.blue.shade100,
        QuoteStatus.accepted => Colors.green.shade100,
        QuoteStatus.rejected => Colors.red.shade100,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Angebote')),
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
          if (data.quotes.isEmpty) {
            return const Center(child: Text('Noch keine Angebote vorhanden.'));
          }

          return ListView.builder(
            itemCount: data.quotes.length,
            itemBuilder: (context, index) {
              final quote = data.quotes[index];
              final customerName = _customerName(quote.customerId, data.customers);

              return ListTile(
                title: Text('${quote.quoteNumber} — ${quote.title}'),
                subtitle: Text(
                  [
                    ?customerName,
                    '${quote.totalGross.toStringAsFixed(2)} €',
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(quote.status, context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_statusLabel(quote.status)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      tooltip: 'PDF',
                      onPressed: () => _showPdf(quote),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Löschen',
                      onPressed: () => _delete(quote),
                    ),
                  ],
                ),
                onTap: () => _openEditor(quote: quote),
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
