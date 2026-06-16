import 'package:flutter/material.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';

/// Dialog zum Erstellen einer Materialabschlag-Rechnung aus einem Auftrag.
/// Zeigt nur direkte Artikel-Positionen (kind = article), gruppiert nach
/// [groupLabel]. Produkte und Leistungen erscheinen in der Endrechnung.
Future<void> showMaterialInvoiceDialog({
  required BuildContext context,
  required ApiClient apiClient,
  required String token,
  required String orderId,
}) {
  return showDialog(
    context: context,
    builder: (context) => _MaterialInvoiceDialog(
      apiClient: apiClient,
      token: token,
      orderId: orderId,
    ),
  );
}

class _MaterialItem {
  _MaterialItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.groupLabel,
    required this.alreadyInvoiced,
  });

  final String id;
  final String description;
  final double quantity;
  final String? unit;
  final double unitPrice;
  final String? groupLabel;
  final bool alreadyInvoiced;

  double get totalNet => quantity * unitPrice;
}

class _MaterialInvoiceDialog extends StatefulWidget {
  const _MaterialInvoiceDialog({
    required this.apiClient,
    required this.token,
    required this.orderId,
  });

  final ApiClient apiClient;
  final String token;
  final String orderId;

  @override
  State<_MaterialInvoiceDialog> createState() =>
      _MaterialInvoiceDialogState();
}

class _MaterialInvoiceDialogState extends State<_MaterialInvoiceDialog> {
  late Future<List<_MaterialItem>> _itemsFuture;
  final Set<String> _selected = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
  }

  Future<List<_MaterialItem>> _loadItems() async {
    final raw = await widget.apiClient
        .getBillableOrderItems(token: widget.token, orderId: widget.orderId);
    final items = raw
        .where((item) => (item['kind'] as String?) == 'article')
        .map((item) => _MaterialItem(
              id: item['id'] as String,
              description: item['description'] as String? ?? '',
              quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
              unit: item['unit'] as String?,
              unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
              groupLabel: item['group_label'] as String?,
              alreadyInvoiced: item['already_invoiced'] as bool? ?? false,
            ))
        .toList();

    // pre-select all not already invoiced
    _selected.addAll(
        items.where((i) => !i.alreadyInvoiced).map((i) => i.id));
    return items;
  }

  /// Groups by label in order of first occurrence; null label = "Allgemeine Positionen".
  Map<String?, List<_MaterialItem>> _groupItems(List<_MaterialItem> items) {
    final grouped = <String?, List<_MaterialItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.groupLabel, () => []).add(item);
    }
    return grouped;
  }

  Future<void> _create(BuildContext context) async {
    if (_selected.isEmpty) {
      setState(() => _error = 'Bitte mindestens eine Position auswählen.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final invoice = await widget.apiClient.convertOrderToInvoice(
        token: widget.token,
        orderId: widget.orderId,
        invoiceType: InvoiceType.partial,
        itemIds: _selected.toList(),
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Materialabschlag ${invoice.invoiceNumber} erstellt.')),
      );
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Materialabschlag erstellen'),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<List<_MaterialItem>>(
          future: _itemsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Text('Fehler: ${snapshot.error}');
            }
            final items = snapshot.data!;
            if (items.isEmpty) {
              return const Text(
                'Keine abrechenbaren Artikel-Positionen vorhanden. '
                'Produkte und Leistungen werden in der Endrechnung abgerechnet.',
              );
            }

            final grouped = _groupItems(items);

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in grouped.entries) ...[
                    _GroupHeader(
                      label: entry.key ?? 'Allgemeine Positionen',
                      items: entry.value,
                      selected: _selected,
                      onToggleGroup: (allSelected) {
                        setState(() {
                          final ids = entry.value
                              .where((i) => !i.alreadyInvoiced)
                              .map((i) => i.id);
                          if (allSelected) {
                            _selected.addAll(ids);
                          } else {
                            _selected.removeAll(ids);
                          }
                        });
                      },
                    ),
                    for (final item in entry.value)
                      CheckboxListTile(
                        dense: true,
                        value: item.alreadyInvoiced
                            ? false
                            : _selected.contains(item.id),
                        enabled: !item.alreadyInvoiced,
                        title: Text(
                          item.description,
                          style: item.alreadyInvoiced
                              ? TextStyle(
                                  color: Theme.of(context).disabledColor)
                              : null,
                        ),
                        subtitle: item.alreadyInvoiced
                            ? const Text('bereits abgerechnet')
                            : Text(
                                '${_fmtQty(item.quantity)}${item.unit != null ? ' ${item.unit}' : ''} × '
                                '${item.unitPrice.toStringAsFixed(2)} € = '
                                '${item.totalNet.toStringAsFixed(2)} € netto',
                              ),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(item.id);
                            } else {
                              _selected.remove(item.id);
                            }
                          });
                        },
                      ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _create(context),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Rechnung erstellen'),
        ),
      ],
    );
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.items,
    required this.selected,
    required this.onToggleGroup,
  });

  final String label;
  final List<_MaterialItem> items;
  final Set<String> selected;
  final void Function(bool allSelected) onToggleGroup;

  bool get _allSelected => items
      .where((i) => !i.alreadyInvoiced)
      .every((i) => selected.contains(i.id));

  bool get _hasSelectable => items.any((i) => !i.alreadyInvoiced);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (_hasSelectable)
            Checkbox(
              value: _allSelected,
              tristate: false,
              onChanged: (v) => onToggleGroup(v ?? false),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
