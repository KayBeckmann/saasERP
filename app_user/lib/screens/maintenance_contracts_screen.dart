import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/app_data_table.dart';
import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String _formatAmount(double value) => '${value.toStringAsFixed(2)} €';

String _statusLabel(MaintenanceContractStatus status) => switch (status) {
      MaintenanceContractStatus.active => 'Aktiv',
      MaintenanceContractStatus.cancelled => 'Gekündigt',
    };

StatusTone _statusTone(MaintenanceContractStatus status) => switch (status) {
      MaintenanceContractStatus.active => StatusTone.success,
      MaintenanceContractStatus.cancelled => StatusTone.neutral,
    };

/// Wartungsverträge/Abos zwischen dem Mandanten und seinen Endkunden —
/// Grundlage für die spätere Kundenportal-Ansicht (Einsicht/Kündigung mit
/// Vertragsstrafen-Vorschau).
class MaintenanceContractsScreen extends StatefulWidget {
  const MaintenanceContractsScreen({super.key});

  @override
  State<MaintenanceContractsScreen> createState() => _MaintenanceContractsScreenState();
}

class _MaintenanceContractsScreenState extends State<MaintenanceContractsScreen> {
  late Future<({List<MaintenanceContract> contracts, List<Customer> customers})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<MaintenanceContract> contracts, List<Customer> customers})> _load() async {
    final auth = context.read<AuthController>();
    final contracts = await auth.apiClient.listMaintenanceContracts(auth.token!);
    final customers = await auth.apiClient.listCustomers(auth.token!);
    return (contracts: contracts, customers: customers);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _openForm({MaintenanceContract? contract, required List<Customer> customers}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _MaintenanceContractFormDialog(contract: contract, customers: customers),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(MaintenanceContract contract) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wartungsvertrag löschen?'),
        content: Text('${contract.contractNumber} · ${contract.title} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    await auth.apiClient.deleteMaintenanceContract(token: auth.token!, id: contract.id);
    _reload();
  }

  String _customerName(String customerId, List<Customer> customers) {
    for (final customer in customers) {
      if (customer.id == customerId) return customer.name;
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentItem: AppNavItem.maintenanceContracts,
      title: 'Wartungsverträge',
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
          return AppDataTable(
            emptyLabel: 'Noch keine Wartungsverträge angelegt.',
            trailingWidth: 48,
            columns: const [
              AppDataColumn('Vertrag', flex: 3),
              AppDataColumn('Kunde', flex: 2),
              AppDataColumn('Laufzeit', flex: 1),
              AppDataColumn('Enddatum', flex: 1),
              AppDataColumn('Status', flex: 1),
            ],
            rows: [
              for (final contract in data.contracts)
                AppDataRow(
                  onTap: () => _openForm(contract: contract, customers: data.customers),
                  cells: [
                    Text('${contract.contractNumber} · ${contract.title}'),
                    Text(_customerName(contract.customerId, data.customers)),
                    Text('${contract.termMonths} Monate'),
                    Text(_formatDate(contract.endDate)),
                    StatusChip(label: _statusLabel(contract.status), tone: _statusTone(contract.status)),
                  ],
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Löschen',
                    onPressed: () => _delete(contract),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          final customers = snapshot.data?.customers ?? [];
          return FloatingActionButton(
            onPressed: () => _openForm(customers: customers),
            tooltip: 'Neuer Wartungsvertrag',
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}

/// Formular zum Anlegen/Bearbeiten eines Wartungsvertrags. Kündigungsdatum
/// und Vertragsstrafen-Vorschau sind nur sichtbar, sobald der Status auf
/// "Gekündigt" gesetzt wird.
class _MaintenanceContractFormDialog extends StatefulWidget {
  const _MaintenanceContractFormDialog({this.contract, required this.customers});

  final MaintenanceContract? contract;
  final List<Customer> customers;

  @override
  State<_MaintenanceContractFormDialog> createState() => _MaintenanceContractFormDialogState();
}

class _MaintenanceContractFormDialogState extends State<_MaintenanceContractFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _termMonthsController;
  late final TextEditingController _noticePeriodController;
  late final TextEditingController _maxPenaltyController;
  late final TextEditingController _notesController;
  String? _customerId;
  late DateTime _startDate;
  late DateTime _endDate;
  late MaintenanceContractStatus _status;
  DateTime? _cancelledAt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.contract;
    _titleController = TextEditingController(text: c?.title ?? '');
    _termMonthsController = TextEditingController(text: (c?.termMonths ?? 12).toString());
    _noticePeriodController = TextEditingController(text: (c?.noticePeriodMonths ?? 1).toString());
    _maxPenaltyController = TextEditingController(text: (c?.maxPenalty ?? 0).toString());
    _notesController = TextEditingController(text: c?.notes ?? '');
    _customerId = c?.customerId ?? (widget.customers.isNotEmpty ? widget.customers.first.id : null);
    final now = DateTime.now();
    _startDate = c?.startDate ?? DateTime(now.year, now.month, now.day);
    _endDate = c?.endDate ?? DateTime(now.year + 1, now.month, now.day);
    _status = c?.status ?? MaintenanceContractStatus.active;
    _cancelledAt = c?.cancelledAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _termMonthsController.dispose();
    _noticePeriodController.dispose();
    _maxPenaltyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required DateTime initial, required void Function(DateTime) onPicked}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  String? _orNull(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      setState(() => _error = 'Bitte einen Kunden auswählen.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final termMonths = int.parse(_termMonthsController.text.trim());
    final noticePeriodMonths = int.tryParse(_noticePeriodController.text.trim()) ?? 1;
    final maxPenalty = double.tryParse(_maxPenaltyController.text.trim().replaceAll(',', '.')) ?? 0;

    final auth = context.read<AuthController>();
    try {
      if (widget.contract == null) {
        await auth.apiClient.createMaintenanceContract(
          token: auth.token!,
          req: CreateMaintenanceContractRequest(
            customerId: _customerId!,
            title: _titleController.text.trim(),
            termMonths: termMonths,
            startDate: _startDate,
            endDate: _endDate,
            noticePeriodMonths: noticePeriodMonths,
            maxPenalty: maxPenalty,
            notes: _orNull(_notesController.text),
          ),
        );
      } else {
        await auth.apiClient.updateMaintenanceContract(
          token: auth.token!,
          id: widget.contract!.id,
          req: UpdateMaintenanceContractRequest(
            customerId: _customerId!,
            title: _titleController.text.trim(),
            termMonths: termMonths,
            startDate: _startDate,
            endDate: _endDate,
            noticePeriodMonths: noticePeriodMonths,
            maxPenalty: maxPenalty,
            status: _status,
            cancelledAt: _status == MaintenanceContractStatus.cancelled ? _cancelledAt : null,
            notes: _orNull(_notesController.text),
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.contract != null;
    final maxPenalty = double.tryParse(_maxPenaltyController.text.trim().replaceAll(',', '.')) ?? 0;
    final termMonths = int.tryParse(_termMonthsController.text.trim()) ?? 0;

    return AlertDialog(
      title: Text(isEdit ? 'Wartungsvertrag bearbeiten' : 'Neuer Wartungsvertrag'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEdit) ...[
                Text(
                  'Vertragsnummer: ${widget.contract!.contractNumber}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<String>(
                initialValue: _customerId,
                decoration: const InputDecoration(labelText: 'Kunde *'),
                items: [
                  for (final customer in widget.customers)
                    DropdownMenuItem(value: customer.id, child: Text(customer.name)),
                ],
                onChanged: (value) => setState(() => _customerId = value),
                validator: (value) => value == null ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Bezeichnung *'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _termMonthsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Laufzeit (Monate) *'),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  return (parsed == null || parsed <= 0) ? 'Bitte eine Zahl > 0 angeben' : null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Startdatum',
                      date: _startDate,
                      onTap: () => _pickDate(initial: _startDate, onPicked: (d) => _startDate = d),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateField(
                      label: 'Enddatum',
                      date: _endDate,
                      onTap: () => _pickDate(initial: _endDate, onPicked: (d) => _endDate = d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noticePeriodController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kündigungsfrist (Monate)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _maxPenaltyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Maximale Vertragsstrafe (€)'),
                onChanged: (_) => setState(() {}),
              ),
              if (isEdit) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<MaintenanceContractStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: MaintenanceContractStatus.active, child: Text('Aktiv')),
                    DropdownMenuItem(value: MaintenanceContractStatus.cancelled, child: Text('Gekündigt')),
                  ],
                  onChanged: (value) => setState(() {
                    _status = value ?? MaintenanceContractStatus.active;
                    _cancelledAt ??= DateTime.now();
                  }),
                ),
                if (_status == MaintenanceContractStatus.cancelled) ...[
                  const SizedBox(height: 8),
                  _DateField(
                    label: 'Kündigungsdatum',
                    date: _cancelledAt ?? DateTime.now(),
                    onTap: () => _pickDate(
                      initial: _cancelledAt ?? DateTime.now(),
                      onPicked: (d) => _cancelledAt = d,
                    ),
                  ),
                  if (termMonths > 0 && maxPenalty > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Vertragsstrafe bei Kündigung am ${_formatDate(_cancelledAt ?? DateTime.now())}: '
                      '${_formatAmount(_previewPenalty(maxPenalty, termMonths))}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notizen'),
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Speichern'),
        ),
      ],
    );
  }

  /// Vorschau gemäß M0-Formel `Strafe = maximale Strafe ×
  /// Restlaufzeit/Laufzeit`, berechnet auf Basis der aktuellen Formularwerte.
  double _previewPenalty(double maxPenalty, int termMonths) {
    final cancellationDate = _cancelledAt ?? DateTime.now();
    if (!cancellationDate.isBefore(_endDate)) return 0;
    final remaining = ((_endDate.year - cancellationDate.year) * 12 + (_endDate.month - cancellationDate.month))
        .clamp(0, termMonths);
    return maxPenalty * remaining / termMonths;
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(_formatDate(date)),
      ),
    );
  }
}
