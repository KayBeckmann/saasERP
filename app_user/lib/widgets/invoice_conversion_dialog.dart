import 'package:flutter/material.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';

/// Auswahl aus dem Dialog [showInvoiceConversionDialog]: Rechnungsart und
/// (bei Teil-/Abschlags-/Schlussrechnung) die ausgewählten Auftragspositionen.
class InvoiceConversionChoice {
  const InvoiceConversionChoice({required this.invoiceType, this.itemIds});

  final InvoiceType invoiceType;

  /// `null` bei [InvoiceType.standard] — dann übernimmt das Backend alle
  /// noch nicht abgerechneten Positionen.
  final List<String>? itemIds;
}

String invoiceTypeLabel(InvoiceType type) => switch (type) {
      InvoiceType.standard => 'Rechnung',
      InvoiceType.partial => 'Teilrechnung',
      InvoiceType.downPayment => 'Abschlagsrechnung',
      InvoiceType.closingInvoice => 'Schlussrechnung',
    };

/// Dialog zum Erzeugen einer Rechnung aus einem Auftrag: Auswahl der
/// Rechnungsart und — bei Teil-/Abschlags-/Schlussrechnung — eine
/// Positions-Checkliste. Bereits abgerechnete Positionen sind ausgegraut
/// und nicht auswählbar (Doppelabrechnungsschutz).
Future<InvoiceConversionChoice?> showInvoiceConversionDialog({
  required BuildContext context,
  required ApiClient apiClient,
  required String token,
  required String orderId,
}) {
  return showDialog<InvoiceConversionChoice>(
    context: context,
    builder: (context) => _InvoiceConversionDialog(apiClient: apiClient, token: token, orderId: orderId),
  );
}

class _InvoiceConversionDialog extends StatefulWidget {
  const _InvoiceConversionDialog({required this.apiClient, required this.token, required this.orderId});

  final ApiClient apiClient;
  final String token;
  final String orderId;

  @override
  State<_InvoiceConversionDialog> createState() => _InvoiceConversionDialogState();
}

class _InvoiceConversionDialogState extends State<_InvoiceConversionDialog> {
  InvoiceType _type = InvoiceType.standard;
  late Future<List<Map<String, dynamic>>> _itemsFuture;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.apiClient.getBillableOrderItems(token: widget.token, orderId: widget.orderId);
    _itemsFuture.then((items) {
      if (!mounted) return;
      setState(() {
        _selected
          ..clear()
          ..addAll(
            items
                .where((item) => item['already_invoiced'] != true && item['id'] != null)
                .map((item) => item['id'] as String),
          );
      });
    });
  }

  bool get _needsSelection => _type != InvoiceType.standard;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechnung erstellen'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<InvoiceType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Rechnungsart'),
              items: InvoiceType.values
                  .map((type) => DropdownMenuItem(value: type, child: Text(invoiceTypeLabel(type))))
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? InvoiceType.standard),
            ),
            if (_needsSelection) ...[
              const SizedBox(height: 12),
              const Text('Positionen auswählen:'),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _itemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text('Fehler: ${snapshot.error}');
                  }
                  final items = snapshot.data!;
                  if (items.isEmpty) {
                    return const Text('Keine Positionen vorhanden.');
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final item in items)
                          CheckboxListTile(
                            dense: true,
                            value: item['already_invoiced'] == true
                                ? false
                                : _selected.contains(item['id'] as String?),
                            enabled: item['already_invoiced'] != true,
                            title: Text(
                              item['description'] as String? ?? '',
                              style: item['already_invoiced'] == true
                                  ? TextStyle(color: Theme.of(context).disabledColor)
                                  : null,
                            ),
                            subtitle: item['already_invoiced'] == true
                                ? const Text('bereits abgerechnet')
                                : null,
                            onChanged: (checked) {
                              final id = item['id'] as String?;
                              if (id == null) return;
                              setState(() {
                                if (checked == true) {
                                  _selected.add(id);
                                } else {
                                  _selected.remove(id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            InvoiceConversionChoice(
              invoiceType: _type,
              itemIds: _needsSelection ? _selected.toList() : null,
            ),
          ),
          child: const Text('Erstellen'),
        ),
      ],
    );
  }
}
