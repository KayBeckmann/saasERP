import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/status_chip.dart';

/// Übersetzt die RF2-Governance-Fehlercodes des Backends in lesbare
/// deutsche Hinweise. Alles, was hier nicht gelistet ist, zeigt
/// [ApiException.message] unverändert (bessere Diagnose als "Fehler").
String translateRoleError(ApiException e) {
  switch (e.message) {
    case 'cannot_delete_role':
      return 'Diese Rolle kann nicht gelöscht werden — entweder ist es die Admin-Rolle, '
          'oder es sind noch Mitglieder zugewiesen.';
    case 'cannot_grant_permissions_you_lack':
      return 'Du kannst keine Berechtigungen vergeben, die du selbst nicht hast.';
    case 'cannot_grant_admin_role':
      return 'Nur ein Admin darf die Admin-Rolle vergeben.';
    case 'cannot_self_demote':
      return 'Du kannst dir selbst nicht die Admin-Rolle entziehen.';
    case 'cannot_demote_last_admin':
      return 'Der letzte Admin eines Mandanten kann nicht herabgestuft werden.';
    case 'invalid_role':
      return 'Diese Rolle existiert nicht (mehr).';
    case 'name_required':
      return 'Bitte einen Namen für die Rolle angeben.';
    case 'cannot_remove_self':
      return 'Du kannst dich nicht selbst aus dem Mandanten entfernen.';
    case 'cannot_remove_last_admin':
      return 'Der letzte Admin eines Mandanten kann nicht entfernt werden.';
    default:
      return e.message;
  }
}

/// Rollenverwaltung (RF2) — anpassbare Rollen samt Modul×Aktion-Matrix.
/// Nur sichtbar/nutzbar für Mitglieder mit dem Modul `members`, wird aber
/// hier nicht zusätzlich clientseitig geprüft: der Server entscheidet
/// (deny-by-default), die UI zeigt bei Ablehnung einfach den Fehlertext.
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  late Future<List<Role>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Role>> _load() {
    final auth = context.read<AuthController>();
    return auth.apiClient.listRoles(auth.token!);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _create() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => const _RoleEditorDialog(role: null),
    );
    if (saved == true) _reload();
  }

  Future<void> _edit(Role role) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _RoleEditorDialog(role: role),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Role role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rolle löschen?'),
        content: Text('Die Rolle "${role.name}" wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthController>();
    try {
      await auth.apiClient.deleteRole(token: auth.token!, id: role.id);
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateRoleError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Rolle anlegen'),
              onPressed: _create,
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Role>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Fehler: ${snapshot.error}'));
              }
              final roles = snapshot.data!;
              return ListView.separated(
                itemCount: roles.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final role = roles[i];
                  return ListTile(
                    title: Row(
                      children: [
                        Text(role.name),
                        const SizedBox(width: 8),
                        if (role.isAdminRole)
                          const StatusChip(label: 'Admin-Rolle', tone: StatusTone.success)
                        else if (role.isBuiltin)
                          const StatusChip(label: 'Vorlage', tone: StatusTone.info),
                      ],
                    ),
                    subtitle: Text('${role.permissions.length} Berechtigungen'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Bearbeiten',
                          onPressed: () => _edit(role),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          tooltip: 'Löschen',
                          onPressed: role.isAdminRole ? null : () => _delete(role),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RoleEditorDialog extends StatefulWidget {
  const _RoleEditorDialog({required this.role});

  /// `null` = neue Rolle anlegen.
  final Role? role;

  @override
  State<_RoleEditorDialog> createState() => _RoleEditorDialogState();
}

class _RoleEditorDialogState extends State<_RoleEditorDialog> {
  late final TextEditingController _nameCtrl = TextEditingController(text: widget.role?.name ?? '');
  late final Set<String> _selected = {
    for (final p in widget.role?.permissions ?? const <RolePermission>[]) p.key,
  };
  bool _saving = false;

  bool get _isAdminRole => widget.role?.isAdminRole ?? false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    final auth = context.read<AuthController>();
    final req = UpsertRoleRequest(
      name: name,
      permissions: [
        for (final module in PermissionModule.all)
          for (final action in PermissionAction.all)
            if (_selected.contains('$module:$action')) RolePermission(module: module, action: action),
      ],
    );

    try {
      if (widget.role == null) {
        await auth.apiClient.createRole(token: auth.token!, req: req);
      } else {
        await auth.apiClient.updateRole(token: auth.token!, id: widget.role!.id, req: req);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateRoleError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.role == null ? 'Rolle anlegen' : 'Rolle bearbeiten'),
      content: SizedBox(
        width: 640,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              enabled: !_isAdminRole,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            if (_isAdminRole)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Die Admin-Rolle behält immer alle Berechtigungen — nur der Name ist änderbar.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 16,
                    columns: [
                      const DataColumn(label: Text('Modul')),
                      for (final action in PermissionAction.all) DataColumn(label: Text(_actionLabel(action))),
                    ],
                    rows: [
                      for (final module in PermissionModule.all)
                        DataRow(
                          cells: [
                            DataCell(Text(_moduleLabel(module))),
                            for (final action in PermissionAction.all)
                              DataCell(
                                Checkbox(
                                  value: _isAdminRole || _selected.contains('$module:$action'),
                                  onChanged: _isAdminRole
                                      ? null
                                      : (checked) => setState(() {
                                            final key = '$module:$action';
                                            if (checked == true) {
                                              _selected.add(key);
                                            } else {
                                              _selected.remove(key);
                                            }
                                          }),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Speichern'),
        ),
      ],
    );
  }
}

/// Deutsche Anzeigenamen für Module/Aktionen — nur UI-Beschriftung, die
/// Wire-Werte ([PermissionModule]/[PermissionAction]) bleiben Englisch.
String _moduleLabel(String module) => switch (module) {
      PermissionModule.customers => 'Kunden',
      PermissionModule.suppliers => 'Lieferanten',
      PermissionModule.articles => 'Artikel',
      PermissionModule.products => 'Produkte',
      PermissionModule.quotes => 'Angebote',
      PermissionModule.orders => 'Aufträge',
      PermissionModule.invoices => 'Rechnungen',
      PermissionModule.purchaseOrders => 'Bestellungen',
      PermissionModule.projects => 'Projekte',
      PermissionModule.timeEntries => 'Zeiterfassung',
      PermissionModule.documents => 'Dokumente',
      PermissionModule.maintenanceContracts => 'Wartungsverträge',
      PermissionModule.dashboard => 'Dashboard',
      PermissionModule.tenantConfig => 'Mandanten-Konfiguration',
      PermissionModule.members => 'Mitglieder & Rollen',
      PermissionModule.waas => 'WaaS',
      _ => module,
    };

String _actionLabel(String action) => switch (action) {
      PermissionAction.view => 'Ansehen',
      PermissionAction.create => 'Erstellen',
      PermissionAction.edit => 'Ändern',
      PermissionAction.release => 'Freigeben',
      PermissionAction.send => 'Versenden',
      PermissionAction.export => 'Exportieren',
      PermissionAction.delete => 'Löschen',
      PermissionAction.cancel => 'Stornieren',
      _ => action,
    };
