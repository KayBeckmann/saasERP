import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/app_data_table.dart';
import '../widgets/app_shell.dart';

String _formatDateTime(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

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

  Future<void> _openPortalAccess(Customer customer) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CustomerPortalAccessDialog(customer: customer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentItem: AppNavItem.customers,
      title: 'Kunden',
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
          return AppDataTable(
            emptyLabel: 'Noch keine Kunden angelegt.',
            trailingWidth: 96,
            columns: const [
              AppDataColumn('Name', flex: 3),
              AppDataColumn('Kundennummer', flex: 2),
              AppDataColumn('Kontakt', flex: 3),
            ],
            rows: [
              for (final customer in customers)
                AppDataRow(
                  onTap: () => _openForm(customer: customer),
                  cells: [
                    Text(customer.name),
                    Text(customer.customerNumber),
                    Text(customer.email ?? '-'),
                  ],
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.badge_outlined),
                        tooltip: 'Kundenzugang',
                        onPressed: () => _openPortalAccess(customer),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Löschen',
                        onPressed: () => _delete(customer),
                      ),
                    ],
                  ),
                ),
            ],
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

/// Verwaltung des Kundenportal-Zugangs (Einladungslink) eines Kunden —
/// Anlage, Anzeige/Kopieren des Links und Widerruf.
class _CustomerPortalAccessDialog extends StatefulWidget {
  const _CustomerPortalAccessDialog({required this.customer});

  final Customer customer;

  @override
  State<_CustomerPortalAccessDialog> createState() => _CustomerPortalAccessDialogState();
}

class _CustomerPortalAccessDialogState extends State<_CustomerPortalAccessDialog> {
  late Future<CustomerPortalAccount?> _future;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<CustomerPortalAccount?> _load() {
    final auth = context.read<AuthController>();
    return auth.apiClient.getCustomerPortalAccess(token: auth.token!, customerId: widget.customer.id);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    try {
      await auth.apiClient.createCustomerPortalAccess(token: auth.token!, customerId: widget.customer.id);
      _reload();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kundenzugang widerrufen?'),
        content: const Text('Der Endkunde kann sich danach nicht mehr im Kundenportal anmelden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Widerrufen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _busy = true);
    final auth = context.read<AuthController>();
    try {
      await auth.apiClient.deleteCustomerPortalAccess(token: auth.token!, customerId: widget.customer.id);
      _reload();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Einladungslink kopiert.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kundenzugang'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<CustomerPortalAccount?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Text('Fehler: ${snapshot.error}');
            }

            final account = snapshot.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.customer.name} (${widget.customer.customerNumber})'),
                const SizedBox(height: 12),
                if (account == null) ...[
                  const Text('Für diesen Kunden existiert noch kein Kundenportal-Zugang.'),
                  const SizedBox(height: 8),
                  Text(
                    widget.customer.email == null
                        ? 'Hinweis: Der Kunde hat keine E-Mail-Adresse hinterlegt.'
                        : 'Einladung wird an ${widget.customer.email} adressiert.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else if (account.status == CustomerPortalAccountStatus.invited) ...[
                  Text(
                    'Eingeladen am ${_formatDateTime(account.invitedAt)} (${account.email}), '
                    'noch kein Passwort vergeben.',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: account.inviteUrl),
                    decoration: InputDecoration(
                      labelText: 'Einladungslink',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: 'Link kopieren',
                        onPressed:
                            account.inviteUrl == null ? null : () => _copyLink(account.inviteUrl!),
                      ),
                    ),
                  ),
                ] else ...[
                  Text('Aktiv seit ${_formatDateTime(account.activatedAt ?? account.invitedAt)} (${account.email}).'),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        FutureBuilder<CustomerPortalAccount?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
            final account = snapshot.data;
            if (account == null) {
              return FilledButton(
                onPressed: _busy ? null : _create,
                child: const Text('Kundenzugang anlegen'),
              );
            }
            return TextButton(
              onPressed: _busy ? null : _revoke,
              child: const Text('Zugang widerrufen'),
            );
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
