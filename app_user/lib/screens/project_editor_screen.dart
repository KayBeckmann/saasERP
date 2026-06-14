import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/project_transaction_dialog.dart';

/// Anlegen/Bearbeiten eines Projekts: Stammdaten (Name, Kunde, Status,
/// Notizen) plus — im Bearbeitungsmodus — sonstige Transaktionen und die
/// Gewinn/Verlust-Übersicht.
class ProjectEditorScreen extends StatefulWidget {
  const ProjectEditorScreen({super.key, this.project});

  final Project? project;

  @override
  State<ProjectEditorScreen> createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  String? _customerId;
  ProjectStatus _status = ProjectStatus.open;

  late Future<List<Customer>> _customersFuture;
  Future<List<ProjectTransaction>>? _transactionsFuture;
  Future<ProjectProfitLoss>? _profitLossFuture;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameController = TextEditingController(text: p?.name ?? '');
    _notesController = TextEditingController(text: p?.notes ?? '');
    _customerId = p?.customerId;
    _status = p?.status ?? ProjectStatus.open;
    _customersFuture = _loadCustomers();
    if (p != null) {
      _transactionsFuture = _loadTransactions();
      _profitLossFuture = _loadProfitLoss();
    }
  }

  Future<List<Customer>> _loadCustomers() async {
    final auth = context.read<AuthController>();
    return auth.apiClient.listCustomers(auth.token!);
  }

  Future<List<ProjectTransaction>> _loadTransactions() async {
    final auth = context.read<AuthController>();
    return auth.apiClient.listProjectTransactions(token: auth.token!, projectId: widget.project!.id);
  }

  Future<ProjectProfitLoss> _loadProfitLoss() async {
    final auth = context.read<AuthController>();
    return auth.apiClient.getProjectProfitLoss(token: auth.token!, projectId: widget.project!.id);
  }

  void _reloadProjectData() {
    setState(() {
      _transactionsFuture = _loadTransactions();
      _profitLossFuture = _loadProfitLoss();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final auth = context.read<AuthController>();

    try {
      if (widget.project == null) {
        await auth.apiClient.createProject(
          token: auth.token!,
          req: CreateProjectRequest(
            customerId: _customerId,
            name: _nameController.text.trim(),
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          ),
        );
      } else {
        await auth.apiClient.updateProject(
          token: auth.token!,
          id: widget.project!.id,
          req: UpdateProjectRequest(
            customerId: _customerId,
            name: _nameController.text.trim(),
            status: _status,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
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

  Future<void> _addOrEditTransaction({ProjectTransaction? transaction}) async {
    final result = await showProjectTransactionDialog(context: context, transaction: transaction);
    if (result == null) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    try {
      if (transaction == null) {
        await auth.apiClient.createProjectTransaction(
          token: auth.token!,
          projectId: widget.project!.id,
          req: CreateProjectTransactionRequest(
            kind: result.kind,
            description: result.description,
            amount: result.amount,
            transactionDate: result.transactionDate,
          ),
        );
      } else {
        await auth.apiClient.updateProjectTransaction(
          token: auth.token!,
          projectId: widget.project!.id,
          id: transaction.id,
          req: UpdateProjectTransactionRequest(
            kind: result.kind,
            description: result.description,
            amount: result.amount,
            transactionDate: result.transactionDate,
          ),
        );
      }
      _reloadProjectData();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: ${e.message}')));
    }
  }

  Future<void> _deleteTransaction(ProjectTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transaktion löschen?'),
        content: Text('"${transaction.description}" wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    await auth.apiClient.deleteProjectTransaction(
      token: auth.token!,
      projectId: widget.project!.id,
      id: transaction.id,
    );
    _reloadProjectData();
  }

  String _statusLabel(ProjectStatus status) => switch (status) {
        ProjectStatus.open => 'Offen',
        ProjectStatus.completed => 'Abgeschlossen',
        ProjectStatus.cancelled => 'Abgebrochen',
      };

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.project != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Projekt ${widget.project!.projectNumber}' : 'Neues Projekt'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            tooltip: 'Speichern',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: FutureBuilder(
        future: _customersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final customers = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name *'),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Pflichtfeld' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _customerId,
                          decoration: const InputDecoration(labelText: 'Kunde'),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('— kein Kunde —')),
                            for (final customer in customers)
                              DropdownMenuItem<String?>(value: customer.id, child: Text(customer.name)),
                          ],
                          onChanged: (value) => setState(() => _customerId = value),
                        ),
                      ),
                      if (isEdit) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<ProjectStatus>(
                            initialValue: _status,
                            decoration: const InputDecoration(labelText: 'Status'),
                            items: [
                              for (final status in ProjectStatus.values)
                                DropdownMenuItem(value: status, child: Text(_statusLabel(status))),
                            ],
                            onChanged: (value) => setState(() => _status = value ?? ProjectStatus.open),
                          ),
                        ),
                      ],
                    ],
                  ),
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
                  if (isEdit) ...[
                    const Divider(height: 32),
                    _buildTransactionsSection(context),
                    const Divider(height: 32),
                    _buildProfitLossSection(context),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sonstige Einnahmen/Ausgaben', style: Theme.of(context).textTheme.titleMedium),
            OutlinedButton.icon(
              onPressed: () => _addOrEditTransaction(),
              icon: const Icon(Icons.add),
              label: const Text('Erfassen'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<ProjectTransaction>>(
          future: _transactionsFuture,
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
            final transactions = snapshot.data!;
            if (transactions.isEmpty) {
              return const Text('Noch keine Transaktionen erfasst.');
            }
            return Column(
              children: [
                for (final transaction in transactions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      transaction.kind == ProjectTransactionKind.income
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: transaction.kind == ProjectTransactionKind.income ? Colors.green : Colors.red,
                    ),
                    title: Text(transaction.description),
                    subtitle: Text(
                      '${transaction.transactionDate.day.toString().padLeft(2, '0')}.'
                      '${transaction.transactionDate.month.toString().padLeft(2, '0')}.'
                      '${transaction.transactionDate.year}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${transaction.amount.toStringAsFixed(2)} €'),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Bearbeiten',
                          onPressed: () => _addOrEditTransaction(transaction: transaction),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Löschen',
                          onPressed: () => _deleteTransaction(transaction),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfitLossSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gewinn/Verlust (netto)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FutureBuilder<ProjectProfitLoss>(
          future: _profitLossFuture,
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
            final pl = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _plRow('Rechnungs-Einnahmen', pl.invoicedIncome),
                _plRow('Sonstige Einnahmen', pl.otherIncome),
                _plRow('Einnahmen gesamt', pl.totalIncome, bold: true),
                const SizedBox(height: 8),
                _plRow('Bestellungen', pl.purchaseExpenses),
                _plRow('Sonstige Ausgaben', pl.otherExpenses),
                _plRow(
                  'Stundenkosten (${pl.laborHours.toStringAsFixed(2)} h × ${pl.hourlyRate.toStringAsFixed(2)} €)',
                  pl.laborCost,
                ),
                _plRow('Ausgaben gesamt', pl.totalExpenses, bold: true),
                const Divider(),
                _plRow('Gewinn/Verlust', pl.profit, bold: true),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _plRow(String label, double value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${value.toStringAsFixed(2)} €', style: style),
        ],
      ),
    );
  }
}
