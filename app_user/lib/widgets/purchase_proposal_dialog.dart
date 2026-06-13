import 'package:flutter/material.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Dialog zur Auswahl einer Lieferanten-Gruppe aus einem Bestellvorschlag
/// (siehe `GET /api/orders/<id>/purchase-proposal`). Zeigt je Gruppe die
/// vorgeschlagenen Positionen mit Bedarf, Lagerbestand und Fehlmenge.
Future<PurchaseProposalGroup?> showPurchaseProposalDialog({
  required BuildContext context,
  required List<PurchaseProposalGroup> proposals,
}) {
  return showDialog<PurchaseProposalGroup>(
    context: context,
    builder: (context) => _PurchaseProposalDialog(proposals: proposals),
  );
}

class _PurchaseProposalDialog extends StatefulWidget {
  const _PurchaseProposalDialog({required this.proposals});

  final List<PurchaseProposalGroup> proposals;

  @override
  State<_PurchaseProposalDialog> createState() => _PurchaseProposalDialogState();
}

class _PurchaseProposalDialogState extends State<_PurchaseProposalDialog> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bestellvorschlag'),
      content: SizedBox(
        width: 420,
        child: RadioGroup<int>(
          groupValue: _selected,
          onChanged: (value) => setState(() => _selected = value ?? 0),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var i = 0; i < widget.proposals.length; i++)
                RadioListTile<int>(
                  value: i,
                  title: Text(widget.proposals[i].supplierName ?? '— ohne Lieferant —'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in widget.proposals[i].items)
                        Text(
                          '${item.description}: ${item.orderQuantity.toStringAsFixed(2)}'
                          '${item.unit != null ? ' ${item.unit}' : ''} '
                          '(Bedarf ${item.requiredQuantity.toStringAsFixed(2)}, '
                          'Bestand ${item.stockQuantity.toStringAsFixed(2)})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.pop(context, widget.proposals[_selected]),
          child: const Text('Bestellung erstellen'),
        ),
      ],
    );
  }
}
