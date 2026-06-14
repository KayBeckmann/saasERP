import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/app_data_table.dart';
import '../widgets/app_shell.dart';

/// Lieferantenliste des aktuellen Mandanten — Freitext-first: nur `name`
/// ist Pflicht, alle anderen Felder sind optional.
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late Future<List<Supplier>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Supplier>> _load() {
    final auth = context.read<AuthController>();
    return auth.apiClient.listSuppliers(auth.token!);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _openForm({Supplier? supplier}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _SupplierFormDialog(supplier: supplier),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lieferant löschen?'),
        content: Text('${supplier.name} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    await auth.apiClient.deleteSupplier(token: auth.token!, id: supplier.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentItem: AppNavItem.suppliers,
      title: 'Lieferanten',
      body: FutureBuilder<List<Supplier>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final suppliers = snapshot.data!;
          return AppDataTable(
            emptyLabel: 'Noch keine Lieferanten angelegt.',
            columns: const [
              AppDataColumn('Name', flex: 3),
              AppDataColumn('Kontakt', flex: 2),
              AppDataColumn('Zahlungsziel', flex: 2),
            ],
            rows: [
              for (final supplier in suppliers)
                AppDataRow(
                  onTap: () => _openForm(supplier: supplier),
                  cells: [
                    Text(supplier.name),
                    Text(supplier.email ?? '-'),
                    Text(
                      supplier.paymentTermsDays != null
                          ? '${supplier.paymentTermsDays} Tage'
                          : '-',
                    ),
                  ],
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Löschen',
                    onPressed: () => _delete(supplier),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Neuer Lieferant',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Formular zum Anlegen/Bearbeiten eines Lieferanten. Nur `name` ist
/// Pflicht (Freitext-first-Prinzip).
class _SupplierFormDialog extends StatefulWidget {
  const _SupplierFormDialog({this.supplier});

  final Supplier? supplier;

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _ibanController;
  late final TextEditingController _paymentTermsController;
  late final TextEditingController _notesController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameController = TextEditingController(text: s?.name ?? '');
    _contactPersonController = TextEditingController(text: s?.contactPerson ?? '');
    _emailController = TextEditingController(text: s?.email ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _ibanController = TextEditingController(text: s?.iban ?? '');
    _paymentTermsController = TextEditingController(text: s?.paymentTermsDays?.toString() ?? '');
    _notesController = TextEditingController(text: s?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _ibanController.dispose();
    _paymentTermsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _orNull(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final paymentTerms = int.tryParse(_paymentTermsController.text.trim());

    final auth = context.read<AuthController>();
    try {
      if (widget.supplier == null) {
        await auth.apiClient.createSupplier(
          token: auth.token!,
          req: CreateSupplierRequest(
            name: _nameController.text.trim(),
            contactPerson: _orNull(_contactPersonController.text),
            email: _orNull(_emailController.text),
            phone: _orNull(_phoneController.text),
            address: _orNull(_addressController.text),
            iban: _orNull(_ibanController.text),
            paymentTermsDays: paymentTerms,
            notes: _orNull(_notesController.text),
          ),
        );
      } else {
        await auth.apiClient.updateSupplier(
          token: auth.token!,
          id: widget.supplier!.id,
          req: UpdateSupplierRequest(
            name: _nameController.text.trim(),
            contactPerson: _orNull(_contactPersonController.text),
            email: _orNull(_emailController.text),
            phone: _orNull(_phoneController.text),
            address: _orNull(_addressController.text),
            iban: _orNull(_ibanController.text),
            paymentTermsDays: paymentTerms,
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
    final isEdit = widget.supplier != null;

    return AlertDialog(
      title: Text(isEdit ? 'Lieferant bearbeiten' : 'Neuer Lieferant'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contactPersonController,
                decoration: const InputDecoration(labelText: 'Ansprechpartner'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-Mail'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Adresse'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ibanController,
                decoration: const InputDecoration(labelText: 'IBAN'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _paymentTermsController,
                decoration: const InputDecoration(labelText: 'Zahlungsziel (Tage)'),
                keyboardType: TextInputType.number,
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
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Speichern'),
        ),
      ],
    );
  }
}
