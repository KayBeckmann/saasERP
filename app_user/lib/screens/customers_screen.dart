import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';

/// Kundenliste des aktuellen Mandanten — Freitext-first: nur `name` ist
/// Pflicht, alle anderen Felder sind optional und wachsen organisch.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late Future<List<Customer>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Customer>> _load() {
    final auth = context.read<AuthController>();
    return auth.apiClient.listCustomers(auth.token!);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _openForm({Customer? customer}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _CustomerFormDialog(customer: customer),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kunde löschen?'),
        content: Text('${customer.name} (${customer.customerNumber}) wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    await auth.apiClient.deleteCustomer(token: auth.token!, id: customer.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kunden')),
      body: FutureBuilder<List<Customer>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final customers = snapshot.data!;
          if (customers.isEmpty) {
            return const Center(child: Text('Noch keine Kunden angelegt.'));
          }
          return ListView.separated(
            itemCount: customers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final customer = customers[index];
              return ListTile(
                title: Text(customer.name),
                subtitle: Text(
                  [
                    customer.customerNumber,
                    if (customer.email != null) customer.email!,
                  ].join(' · '),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Löschen',
                  onPressed: () => _delete(customer),
                ),
                onTap: () => _openForm(customer: customer),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Neuer Kunde',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Formular zum Anlegen/Bearbeiten eines Kunden. Nur `name` ist Pflicht
/// (Freitext-first-Prinzip).
class _CustomerFormDialog extends StatefulWidget {
  const _CustomerFormDialog({this.customer});

  final Customer? customer;

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _leitwegIdController;
  late final TextEditingController _notesController;
  late CustomerKind _kind;
  late EInvoiceFormat _eInvoiceFormat;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c?.name ?? '');
    _contactPersonController = TextEditingController(text: c?.contactPerson ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _leitwegIdController = TextEditingController(text: c?.leitwegId ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');
    _kind = c?.kind ?? CustomerKind.private;
    _eInvoiceFormat = c?.eInvoiceFormat ?? EInvoiceFormat.none;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _leitwegIdController.dispose();
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

    final auth = context.read<AuthController>();
    try {
      if (widget.customer == null) {
        await auth.apiClient.createCustomer(
          token: auth.token!,
          req: CreateCustomerRequest(
            kind: _kind,
            name: _nameController.text.trim(),
            contactPerson: _orNull(_contactPersonController.text),
            email: _orNull(_emailController.text),
            phone: _orNull(_phoneController.text),
            address: _orNull(_addressController.text),
            eInvoiceFormat: _eInvoiceFormat,
            leitwegId: _orNull(_leitwegIdController.text),
            notes: _orNull(_notesController.text),
          ),
        );
      } else {
        await auth.apiClient.updateCustomer(
          token: auth.token!,
          id: widget.customer!.id,
          req: UpdateCustomerRequest(
            kind: _kind,
            name: _nameController.text.trim(),
            contactPerson: _orNull(_contactPersonController.text),
            email: _orNull(_emailController.text),
            phone: _orNull(_phoneController.text),
            address: _orNull(_addressController.text),
            eInvoiceFormat: _eInvoiceFormat,
            leitwegId: _orNull(_leitwegIdController.text),
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
    final isEdit = widget.customer != null;

    return AlertDialog(
      title: Text(isEdit ? 'Kunde bearbeiten' : 'Neuer Kunde'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEdit) ...[
                Text(
                  'Kundennummer: ${widget.customer!.customerNumber}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<CustomerKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Art'),
                items: const [
                  DropdownMenuItem(value: CustomerKind.private, child: Text('Privatperson')),
                  DropdownMenuItem(value: CustomerKind.business, child: Text('Unternehmen')),
                  DropdownMenuItem(
                    value: CustomerKind.authority,
                    child: Text('Behörde (öffentlicher Auftraggeber)'),
                  ),
                ],
                onChanged: (value) => setState(() => _kind = value ?? CustomerKind.private),
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
              DropdownButtonFormField<EInvoiceFormat>(
                initialValue: _eInvoiceFormat,
                decoration: const InputDecoration(labelText: 'E-Rechnungsformat'),
                items: const [
                  DropdownMenuItem(value: EInvoiceFormat.none, child: Text('Keine (PDF)')),
                  DropdownMenuItem(value: EInvoiceFormat.xrechnung, child: Text('XRechnung')),
                  DropdownMenuItem(value: EInvoiceFormat.zugferd, child: Text('ZUGFeRD')),
                ],
                onChanged: (value) =>
                    setState(() => _eInvoiceFormat = value ?? EInvoiceFormat.none),
              ),
              if (_eInvoiceFormat == EInvoiceFormat.xrechnung || _kind == CustomerKind.authority) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _leitwegIdController,
                  decoration: const InputDecoration(labelText: 'Leitweg-ID'),
                ),
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
