import 'package:flutter/material.dart';

/// Zeitraum-Auswahl für den Steuerberater-Export — `from`/`to` sind beide
/// optional (kein Datum = unbeschränkt in diese Richtung).
typedef InvoiceExportRange = ({DateTime? from, DateTime? to});

/// Dialog zur Auswahl des Export-Zeitraums für [showInvoiceExportDialog].
Future<InvoiceExportRange?> showInvoiceExportDialog({required BuildContext context}) {
  return showDialog<InvoiceExportRange>(
    context: context,
    builder: (context) => const _InvoiceExportDialog(),
  );
}

class _InvoiceExportDialog extends StatefulWidget {
  const _InvoiceExportDialog();

  @override
  State<_InvoiceExportDialog> createState() => _InvoiceExportDialogState();
}

class _InvoiceExportDialogState extends State<_InvoiceExportDialog> {
  DateTime? _from;
  DateTime? _to;

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _to = picked);
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Steuerberater-Export (CSV)'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Zeitraum (optional, bezogen auf das Rechnungsdatum):'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickFrom,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Von'),
                      child: Text(_from == null ? '— offen —' : _formatDate(_from!)),
                    ),
                  ),
                ),
                if (_from != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Zurücksetzen',
                    onPressed: () => setState(() => _from = null),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickTo,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Bis'),
                      child: Text(_to == null ? '— offen —' : _formatDate(_to!)),
                    ),
                  ),
                ),
                if (_to != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Zurücksetzen',
                    onPressed: () => setState(() => _to = null),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        TextButton(
          onPressed: () => Navigator.pop(context, (from: _from, to: _to)),
          child: const Text('Exportieren'),
        ),
      ],
    );
  }
}
