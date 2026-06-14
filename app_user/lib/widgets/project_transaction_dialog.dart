import 'package:flutter/material.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Eingaben aus [showProjectTransactionDialog] — dient sowohl für
/// `CreateProjectTransactionRequest` als auch `UpdateProjectTransactionRequest`.
class ProjectTransactionFormResult {
  const ProjectTransactionFormResult({
    required this.kind,
    required this.description,
    required this.amount,
    required this.transactionDate,
  });

  final ProjectTransactionKind kind;
  final String description;
  final double amount;
  final DateTime transactionDate;
}

String projectTransactionKindLabel(ProjectTransactionKind kind) => switch (kind) {
      ProjectTransactionKind.income => 'Einnahme',
      ProjectTransactionKind.expense => 'Ausgabe',
    };

/// Dialog zum Anlegen/Bearbeiten einer sonstigen Projekt-Einnahme/-Ausgabe
/// (Art, Beschreibung, Betrag, Datum).
Future<ProjectTransactionFormResult?> showProjectTransactionDialog({
  required BuildContext context,
  ProjectTransaction? transaction,
}) {
  return showDialog<ProjectTransactionFormResult>(
    context: context,
    builder: (context) => _ProjectTransactionDialog(transaction: transaction),
  );
}

class _ProjectTransactionDialog extends StatefulWidget {
  const _ProjectTransactionDialog({this.transaction});

  final ProjectTransaction? transaction;

  @override
  State<_ProjectTransactionDialog> createState() => _ProjectTransactionDialogState();
}

class _ProjectTransactionDialogState extends State<_ProjectTransactionDialog> {
  late ProjectTransactionKind _kind;
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late DateTime _date;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _kind = t?.kind ?? ProjectTransactionKind.expense;
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _amountController = TextEditingController(text: _formatNumber(t?.amount ?? 0));
    _date = t?.transactionDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _submit() {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Beschreibung darf nicht leer sein.');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (amount == null) {
      setState(() => _error = 'Betrag ist ungültig.');
      return;
    }
    Navigator.pop(
      context,
      ProjectTransactionFormResult(
        kind: _kind,
        description: description,
        amount: amount,
        transactionDate: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.transaction == null ? 'Transaktion erfassen' : 'Transaktion bearbeiten'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<ProjectTransactionKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Art'),
              items: [
                for (final kind in ProjectTransactionKind.values)
                  DropdownMenuItem(value: kind, child: Text(projectTransactionKindLabel(kind))),
              ],
              onChanged: (value) => setState(() => _kind = value ?? ProjectTransactionKind.expense),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Betrag (€, netto)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Datum'),
                child: Text(
                  '${_date.day.toString().padLeft(2, '0')}.'
                  '${_date.month.toString().padLeft(2, '0')}.'
                  '${_date.year}',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        TextButton(onPressed: _submit, child: const Text('Speichern')),
      ],
    );
  }
}
