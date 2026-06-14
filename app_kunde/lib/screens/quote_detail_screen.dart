import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../formatting.dart';
import '../state/auth_controller.dart';
import '../widgets/status_chip.dart';

/// Detailansicht eines Angebots im Kundenportal: Positionen, Summen und —
/// solange `status == sent` — die Möglichkeit, das Angebot freizugeben oder
/// abzulehnen (mit optionalem Kommentar).
class QuoteDetailScreen extends StatefulWidget {
  const QuoteDetailScreen({super.key, required this.quote});

  final Quote quote;

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  late Quote _quote;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _quote = widget.quote;
  }

  Future<void> _decide(QuoteStatus decision) async {
    final auth = context.read<AuthController>();
    final comment = await _askForComment(decision);
    if (comment == null) return;

    setState(() => _submitting = true);
    try {
      final updated = await auth.apiClient.decideQuote(
        token: auth.token!,
        quoteId: _quote.id,
        decision: decision,
        comment: comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      setState(() => _quote = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Zeigt einen Dialog mit optionalem Kommentarfeld. Gibt `null` zurück,
  /// wenn der Nutzer abbricht — sonst den (ggf. leeren) Kommentartext.
  Future<String?> _askForComment(QuoteStatus decision) {
    final controller = TextEditingController();
    final title = decision == QuoteStatus.accepted ? 'Angebot freigeben?' : 'Angebot ablehnen?';
    final actionLabel = decision == QuoteStatus.accepted ? 'Freigeben' : 'Ablehnen';

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Kommentar (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;

    return Scaffold(
      appBar: AppBar(title: Text(quote.quoteNumber)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(quote.title, style: Theme.of(context).textTheme.titleLarge)),
              const SizedBox(width: 12),
              StatusChip(label: quoteStatusLabel(quote.status), tone: quoteStatusTone(quote.status)),
            ],
          ),
          if (quote.validUntil != null) ...[
            const SizedBox(height: 8),
            Text('Gültig bis: ${formatDate(quote.validUntil!)}'),
          ],
          const SizedBox(height: 16),
          for (final group in quote.groupedItems) _QuoteGroupCard(group: group),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Gesamt: ${formatAmount(quote.totalGross)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (quote.notes != null && quote.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Notizen', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(quote.notes!),
          ],
          const SizedBox(height: 24),
          if (quote.status == QuoteStatus.sent)
            _DecisionButtons(submitting: _submitting, onDecide: _decide)
          else if (quote.customerDecisionAt != null)
            _DecisionInfo(quote: quote),
        ],
      ),
    );
  }
}

class _QuoteGroupCard extends StatelessWidget {
  const _QuoteGroupCard({required this.group});

  final QuoteGroupSummary group;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.label != null) ...[
              Text(group.label!, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
            ],
            for (final item in group.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(item.description)),
                    Text(formatAmount(item.totalGross)),
                  ],
                ),
              ),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Zwischensumme: ${formatAmount(group.totalGross)}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionButtons extends StatelessWidget {
  const _DecisionButtons({required this.submitting, required this.onDecide});

  final bool submitting;
  final ValueChanged<QuoteStatus> onDecide;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: submitting ? null : () => onDecide(QuoteStatus.rejected),
            child: const Text('Ablehnen'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: submitting ? null : () => onDecide(QuoteStatus.accepted),
            child: const Text('Freigeben'),
          ),
        ),
      ],
    );
  }
}

class _DecisionInfo extends StatelessWidget {
  const _DecisionInfo({required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final label = quote.status == QuoteStatus.accepted ? 'Angenommen am' : 'Abgelehnt am';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label ${formatDate(quote.customerDecisionAt!)}'),
            if (quote.customerComment != null && quote.customerComment!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Kommentar: ${quote.customerComment}'),
            ],
          ],
        ),
      ),
    );
  }
}
