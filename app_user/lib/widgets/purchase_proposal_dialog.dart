import 'package:flutter/material.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Ergebnis des Bestellvorschlag-Dialogs: entweder eine einzelne
/// Lieferantengruppe oder alle Gruppen zusammengeführt unter einem
/// vom Nutzer gewählten Lieferanten.
class PurchaseProposalSelection {
  const PurchaseProposalSelection({
    required this.items,
    required this.supplierId,
  });

  final List<PurchaseProposalItem> items;
  final String? supplierId;
}

/// Dialog zur Auswahl einer Lieferanten-Gruppe aus einem Bestellvorschlag
/// (siehe `GET /api/orders/<id>/purchase-proposal`). Zeigt je Gruppe die
/// vorgeschlagenen Positionen. Zusätzliche Option: "Alle Artikel" fasst
/// alle Gruppen zusammen und lässt den Nutzer einen Lieferanten wählen.
Future<PurchaseProposalSelection?> showPurchaseProposalDialog({
  required BuildContext context,
  required List<PurchaseProposalGroup> proposals,
}) {
  return showDialog<PurchaseProposalSelection>(
    context: context,
    builder: (context) => _PurchaseProposalDialog(proposals: proposals),
  );
}

enum _SelectionMode { bySupplier, allArticles }

class _PurchaseProposalDialog extends StatefulWidget {
  const _PurchaseProposalDialog({required this.proposals});

  final List<PurchaseProposalGroup> proposals;

  @override
  State<_PurchaseProposalDialog> createState() =>
      _PurchaseProposalDialogState();
}

class _PurchaseProposalDialogState extends State<_PurchaseProposalDialog> {
  _SelectionMode _mode = _SelectionMode.bySupplier;
  int _selectedGroup = 0;
  String? _allArticlesSupplierIndex;

  @override
  Widget build(BuildContext context) {
    // Collect all unique suppliers for the "Alle Artikel" supplier picker
    final allSuppliers = <String?, String>{};
    for (final group in widget.proposals) {
      if (!allSuppliers.containsKey(group.supplierId)) {
        allSuppliers[group.supplierId] = group.supplierName ?? '— ohne Lieferant —';
      }
    }

    return AlertDialog(
      title: const Text('Bestellvorschlag'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<_SelectionMode>(
              groupValue: _mode,
              onChanged: (v) =>
                  setState(() => _mode = v ?? _SelectionMode.bySupplier),
              child: Column(
                children: [
                  const RadioListTile<_SelectionMode>(
                    value: _SelectionMode.bySupplier,
                    title: Text('Nach Lieferant bestellen'),
                  ),
                  const RadioListTile<_SelectionMode>(
                    value: _SelectionMode.allArticles,
                    title: Text('Alle Artikel zu einem Lieferanten'),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            if (_mode == _SelectionMode.bySupplier) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: RadioGroup<int>(
                  groupValue: _selectedGroup,
                  onChanged: (v) =>
                      setState(() => _selectedGroup = v ?? 0),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (var i = 0; i < widget.proposals.length; i++)
                        RadioListTile<int>(
                          value: i,
                          title: Text(widget.proposals[i].supplierName ??
                              '— ohne Lieferant —'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final item in widget.proposals[i].items)
                                Text(
                                  '${item.description}: '
                                  '${_fmtQty(item.orderQuantity)}'
                                  '${item.unit != null ? ' ${item.unit}' : ''} '
                                  '(Bedarf ${_fmtQty(item.requiredQuantity)}, '
                                  'Bestand ${_fmtQty(item.stockQuantity)})',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              DropdownButtonFormField<String?>(
                initialValue: _allArticlesSupplierIndex,
                decoration: const InputDecoration(labelText: 'Lieferant'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('— kein Lieferant —')),
                  for (final entry in allSuppliers.entries)
                    DropdownMenuItem<String?>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => _allArticlesSupplierIndex = v),
              ),
              const SizedBox(height: 12),
              Text(
                'Alle ${widget.proposals.fold(0, (s, g) => s + g.items.length)} '
                'Artikel-Positionen werden in eine Bestellung zusammengefasst.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (_mode == _SelectionMode.bySupplier) {
              final group = widget.proposals[_selectedGroup];
              Navigator.pop(
                context,
                PurchaseProposalSelection(
                  items: group.items,
                  supplierId: group.supplierId,
                ),
              );
            } else {
              final allItems = widget.proposals
                  .expand((g) => g.items)
                  .toList();
              Navigator.pop(
                context,
                PurchaseProposalSelection(
                  items: allItems,
                  supplierId: _allArticlesSupplierIndex,
                ),
              );
            }
          },
          child: const Text('Bestellung erstellen'),
        ),
      ],
    );
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
