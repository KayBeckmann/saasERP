import 'package:flutter/material.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';

/// Dialog zum Erstellen einer Materialabschlag-Rechnung aus einem Auftrag.
/// Zeigt alle Artikel-Positionen des Auftrags gruppiert nach [groupLabel],
/// inklusive der Artikel-Komponenten aus Produkt-Positionen.
/// Bereits abgerechnete Positionen sind deaktiviert.
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
    required this.vatRate,
    required this.groupLabel,
    required this.alreadyInvoiced,
    required this.parentDescription,
    required this.rawData,
  });

  final String id;
  final String description;
  final double quantity;
  final String? unit;
  final double unitPrice;
  final double vatRate;
  final String? groupLabel;
  final bool alreadyInvoiced;
  /// For synthetic items: the description of the parent product order item.
  final String? parentDescription;
  /// Raw JSON from the billable-items endpoint — used to build extra_items.
  final Map<String, dynamic> rawData;

  bool get isSynthetic => id.startsWith('cmp:');

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
    final raw = await widget.apiClient.getBillableOrderItems(
      token: widget.token,
      orderId: widget.orderId,
      expandProducts: true,
    );
    final items = raw
        .map((item) => _MaterialItem(
              id: item['id'] as String,
              description: item['description'] as String? ?? '',
              quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
              unit: item['unit'] as String?,
              unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
              vatRate: (item['vat_rate'] as num?)?.toDouble() ?? 19.0,
              groupLabel: item['group_label'] as String?,
              alreadyInvoiced: item['already_invoiced'] as bool? ?? false,
              parentDescription: item['parent_description'] as String?,
              rawData: item,
            ))
        .toList();

    _selected.addAll(
        items.where((i) => !i.alreadyInvoiced).map((i) => i.id));
    return items;
  }

  /// Groups items by [groupLabel]; null label → "Allgemeine Positionen".
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

    // Separate regular order-item IDs from synthetic component IDs.
    final regularIds = <String>[];
    final extraItems = <Map<String, dynamic>>[];
    for (final id in _selected) {
      if (id.startsWith('cmp:')) {
        // Synthetic item: pass full data as extra_item
        final snapshot = await _itemsFuture;
        final item = snapshot.firstWhere((i) => i.id == id);
        extraItems.add({
          'kind': 'article',
          'description': item.description,
          'quantity': item.quantity,
          'unit': item.unit,
          'unit_price': item.unitPrice,
          'vat_rate': item.vatRate,
          'group_label': item.groupLabel,
        });
      } else {
        regularIds.add(id);
      }
    }

    try {
      final invoice = await widget.apiClient.convertOrderToInvoice(
        token: widget.token,
        orderId: widget.orderId,
        invoiceType: InvoiceType.partial,
        itemIds: regularIds.isEmpty ? null : regularIds,
        extraItems: extraItems.isEmpty ? null : extraItems,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Materialabschlag ${invoice.invoiceNumber} erstellt.'),
        ),
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
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                'Materialabschlag erstellen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Wähle die Artikel, die in dieser Abschlagsrechnung verrechnet werden sollen.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              // Column header
              _ColumnHeader(),
              const Divider(height: 1),
              // Item list
              Flexible(
                child: FutureBuilder<List<_MaterialItem>>(
                  future: _itemsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Fehler: ${snapshot.error}'),
                      );
                    }
                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Keine abrechenbaren Artikel-Positionen vorhanden.',
                          ),
                        ),
                      );
                    }

                    final grouped = _groupItems(items);
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        for (final entry in grouped.entries) ...[
                          _GroupHeaderRow(
                            label: entry.key ?? 'Allgemeine Positionen',
                            items: entry.value,
                            selected: _selected,
                            onToggle: (allSelected) => setState(() {
                              final ids = entry.value
                                  .where((i) => !i.alreadyInvoiced)
                                  .map((i) => i.id);
                              if (allSelected) {
                                _selected.addAll(ids);
                              } else {
                                _selected.removeAll(ids);
                              }
                            }),
                          ),
                          for (final item in entry.value)
                            _ItemRow(
                              item: item,
                              isSelected: _selected.contains(item.id),
                              onToggle: item.alreadyInvoiced
                                  ? null
                                  : (v) => setState(() {
                                        if (v) {
                                          _selected.add(item.id);
                                        } else {
                                          _selected.remove(item.id);
                                        }
                                      }),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              // Footer: summary + error + actions
              const SizedBox(height: 12),
              FutureBuilder<List<_MaterialItem>>(
                future: _itemsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final items = snapshot.data!;
                  final selectedItems =
                      items.where((i) => _selected.contains(i.id));
                  final total = selectedItems.fold<double>(
                      0, (sum, i) => sum + i.totalNet);
                  final count = selectedItems.length;
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          count == 0
                              ? 'Keine Positionen ausgewählt'
                              : '$count Position${count == 1 ? '' : 'en'} ausgewählt  ·  '
                                  '${total.toStringAsFixed(2)} € netto',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 0, 6),
      child: Row(
        children: [
          Expanded(child: Text('Beschreibung', style: style)),
          SizedBox(
              width: 80,
              child: Text('Menge',
                  style: style, textAlign: TextAlign.right)),
          SizedBox(
              width: 90,
              child:
                  Text('EP (€)', style: style, textAlign: TextAlign.right)),
          SizedBox(
              width: 90,
              child: Text('Gesamt netto',
                  style: style, textAlign: TextAlign.right)),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _GroupHeaderRow extends StatelessWidget {
  const _GroupHeaderRow({
    required this.label,
    required this.items,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final List<_MaterialItem> items;
  final Set<String> selected;
  final void Function(bool) onToggle;

  bool get _allSelected => items
      .where((i) => !i.alreadyInvoiced)
      .every((i) => selected.contains(i.id));

  bool get _hasSelectable => items.any((i) => !i.alreadyInvoiced);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: _hasSelectable
                ? Checkbox(
                    value: _allSelected,
                    tristate: false,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) => onToggle(v ?? false),
                  )
                : null,
          ),
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

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.isSelected,
    required this.onToggle,
  });

  final _MaterialItem item;
  final bool isSelected;
  final void Function(bool)? onToggle;

  @override
  Widget build(BuildContext context) {
    final disabled = item.alreadyInvoiced;
    final textColor = disabled
        ? Theme.of(context).disabledColor
        : Theme.of(context).colorScheme.onSurface;
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: textColor);

    return InkWell(
      onTap: onToggle == null ? null : () => onToggle!(!isSelected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Checkbox(
                value: disabled ? false : isSelected,
                tristate: false,
                visualDensity: VisualDensity.compact,
                onChanged: disabled ? null : (v) => onToggle!(v ?? false),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.description, style: style),
                  if (item.isSynthetic && item.parentDescription != null)
                    Text(
                      'aus Produkt: ${item.parentDescription}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  if (disabled)
                    Text(
                      'bereits abgerechnet',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).disabledColor,
                          ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                '${_fmtQty(item.quantity)}${item.unit != null ? ' ${item.unit}' : ''}',
                style: style,
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                item.unitPrice.toStringAsFixed(2),
                style: style,
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                item.totalNet.toStringAsFixed(2),
                style: style?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
