import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../state/auth_controller.dart';
import '../services/api_client.dart';

/// Dialog zum Erstellen einer Schlussrechnung (Endrechnung) aus einem Auftrag.
/// Zeigt alle noch nicht abgerechneten Positionen (Produkte, Leistungen, Artikel)
/// sowie eine Vorschau der abzuziehenden Vorrechnungen.
Future<void> showClosingInvoiceDialog({
  required BuildContext context,
  required String orderId,
}) {
  return showDialog(
    context: context,
    builder: (context) => _ClosingInvoiceDialog(orderId: orderId),
  );
}

class _BillableItem {
  _BillableItem({
    required this.id,
    required this.kind,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.vatRate,
    required this.groupLabel,
    required this.alreadyInvoiced,
  });

  final String id;
  final String kind;
  final String description;
  final double quantity;
  final String? unit;
  final double unitPrice;
  final double vatRate;
  final String? groupLabel;
  final bool alreadyInvoiced;

  double get totalNet => quantity * unitPrice;
  double get totalGross => totalNet * (1 + vatRate / 100);

  String get kindLabel => switch (kind) {
        'article' => 'Artikel',
        'product' => 'Produkt',
        'hours' => 'Leistung/Stunden',
        _ => 'Freitext',
      };
}

class _ClosingInvoiceDialog extends StatefulWidget {
  const _ClosingInvoiceDialog({required this.orderId});
  final String orderId;

  @override
  State<_ClosingInvoiceDialog> createState() => _ClosingInvoiceDialogState();
}

class _ClosingInvoiceDialogState extends State<_ClosingInvoiceDialog> {
  late Future<_LoadResult> _loadFuture;
  final Set<String> _selected = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<_LoadResult> _load() async {
    final auth = context.read<AuthController>();
    final raw = await auth.apiClient
        .getBillableOrderItems(token: auth.token!, orderId: widget.orderId);

    final items = raw
        .map((item) => _BillableItem(
              id: item['id'] as String,
              kind: item['kind'] as String? ?? 'text',
              description: item['description'] as String? ?? '',
              quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
              unit: item['unit'] as String?,
              unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
              vatRate: (item['vat_rate'] as num?)?.toDouble() ?? 19.0,
              groupLabel: item['group_label'] as String?,
              alreadyInvoiced: item['already_invoiced'] as bool? ?? false,
            ))
        .toList();

    // Pre-select all not yet invoiced
    _selected.addAll(items.where((i) => !i.alreadyInvoiced).map((i) => i.id));

    return _LoadResult(items: items);
  }

  Map<String?, List<_BillableItem>> _groupItems(List<_BillableItem> items) {
    final grouped = <String?, List<_BillableItem>>{};
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
      final auth = context.read<AuthController>();
      final invoice = await auth.apiClient.convertOrderToInvoice(
        token: auth.token!,
        orderId: widget.orderId,
        invoiceType: InvoiceType.closingInvoice,
        itemIds: _selected.toList(),
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Endrechnung ${invoice.invoiceNumber} erstellt.')),
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
      title: const Text('Endrechnung erstellen'),
      content: SizedBox(
        width: 500,
        child: FutureBuilder<_LoadResult>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Text('Fehler: ${snapshot.error}');
            }
            final result = snapshot.data!;
            final grouped = _groupItems(result.items);
            final selectedItems =
                result.items.where((i) => _selected.contains(i.id));
            final selectedGross =
                selectedItems.fold(0.0, (s, i) => s + i.totalGross);

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text(
                    'Wähle die Positionen für die Endrechnung. '
                    'Bereits abgerechnete Positionen sind ausgeblendet. '
                    'Alle Vorrechnungen werden automatisch abgezogen.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in grouped.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Checkbox(
                            tristate: false,
                            value: entry.value
                                .where((i) => !i.alreadyInvoiced)
                                .every((i) => _selected.contains(i.id)),
                            onChanged: entry.value
                                    .any((i) => !i.alreadyInvoiced)
                                ? (v) {
                                    setState(() {
                                      final ids = entry.value
                                          .where((i) => !i.alreadyInvoiced)
                                          .map((i) => i.id);
                                      if (v == true) {
                                        _selected.addAll(ids);
                                      } else {
                                        _selected.removeAll(ids);
                                      }
                                    });
                                  }
                                : null,
                          ),
                          Expanded(
                            child: Text(
                              entry.key ?? 'Allgemeine Positionen',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
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
                                '${item.kindLabel} · '
                                '${_fmtQty(item.quantity)}'
                                '${item.unit != null ? ' ${item.unit}' : ''} × '
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
                  if (selectedGross > 0) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Ausgewählt: ${selectedGross.toStringAsFixed(2)} € brutto',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Text(
                      'Vorrechnungen werden beim Erstellen automatisch als Abzug berechnet.',
                      style: TextStyle(fontSize: 11),
                      textAlign: TextAlign.end,
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
              : const Text('Endrechnung erstellen'),
        ),
      ],
    );
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _LoadResult {
  const _LoadResult({required this.items});
  final List<_BillableItem> items;
}
