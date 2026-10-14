import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/app_data_table.dart';
import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'roles_screen.dart';

/// Mitglieder- und Rollenverwaltung (RF2) — nur sichtbar für Mitglieder mit
/// Zugriff auf das Modul `members` (serverseitig deny-by-default erzwungen;
/// die Navigation blendet den Menüpunkt zusätzlich für Nicht-Admins aus).
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));
  late Future<List<AppUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<AppUser>> _load() {
    final auth = context.read<AuthController>();
    return auth.apiClient.listUsers(auth.token!);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _invite() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => const _CreateEmployeeDialog(),
    );
    if (saved == true) _reload();
  }

  Future<void> _remove(AppUser user) async {
    final auth = context.read<AuthController>();
    if (user.id == auth.user?.id) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mitarbeiter entfernen?'),
        content: Text('${user.email} wirklich aus dem Mandanten entfernen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Entfernen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await auth.apiClient.deleteUser(token: auth.token!, id: user.id);
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateRoleError(e))));
    }
  }

  Future<void> _changeRole(AppUser user) async {
    final auth = context.read<AuthController>();
    List<Role> roles;
    try {
      roles = await auth.apiClient.listRoles(auth.token!);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateRoleError(e))));
      return;
    }
    if (!mounted) return;

    final selectedRoleId = await showDialog<String>(
      context: context,
      builder: (ctx) => _RolePickerDialog(roles: roles, initialRoleId: user.roleId),
    );
    if (selectedRoleId == null || selectedRoleId == user.roleId) return;

    try {
      await auth.apiClient.updateUserRole(token: auth.token!, userId: user.id, roleId: selectedRoleId);
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateRoleError(e))));
    }
  }

  Future<void> _changePassword() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _ChangePasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final onMembersTab = _tabController.index == 0;
    return AppShell(
      currentItem: AppNavItem.users,
      title: 'Benutzer & Rollen',
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.lock_outline, size: 18),
          label: const Text('Passwort ändern'),
          onPressed: _changePassword,
        ),
        const SizedBox(width: 8),
        if (onMembersTab)
          FilledButton.icon(
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Mitarbeiter hinzufügen'),
            onPressed: _invite,
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Mitglieder'),
              Tab(text: 'Rollen'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                FutureBuilder<List<AppUser>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Fehler: ${snapshot.error}'));
                    }
                    final users = snapshot.data!;
                    final currentId = auth.user?.id;
                    return AppDataTable(
                      columns: const [
                        AppDataColumn('E-Mail', flex: 3),
                        AppDataColumn('Rolle', flex: 2),
                        AppDataColumn('Mitglied seit', flex: 2),
                        AppDataColumn('', flex: 1),
                      ],
                      rows: users
                          .map(
                            (u) => AppDataRow(
                              cells: [
                                Row(
                                  children: [
                                    Text(u.email),
                                    if (u.id == currentId) ...[
                                      const SizedBox(width: 8),
                                      const StatusChip(label: 'Ich', tone: StatusTone.info),
                                    ],
                                  ],
                                ),
                                InkWell(
                                  onTap: () => _changeRole(u),
                                  child: StatusChip(
                                    label: u.roleName ?? (u.role == UserRole.owner ? 'Inhaber' : 'Mitarbeiter'),
                                    tone: u.isAdminRole ? StatusTone.success : StatusTone.neutral,
                                  ),
                                ),
                                Text(_fmt(u.createdAt)),
                                // Letzter Admin und eigener Account werden
                                // serverseitig ohnehin geschützt — der Button
                                // bleibt trotzdem sichtbar, der Fehlertext
                                // erklärt bei Bedarf warum (Admin-Governance).
                                if (u.id != currentId)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                                    tooltip: 'Entfernen',
                                    onPressed: () => _remove(u),
                                  )
                                else
                                  const SizedBox.shrink(),
                              ],
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const RolesScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}

class _CreateEmployeeDialog extends StatefulWidget {
  const _CreateEmployeeDialog();

  @override
  State<_CreateEmployeeDialog> createState() => _CreateEmployeeDialogState();
}

class _CreateEmployeeDialogState extends State<_CreateEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscurePw = true;
  late Future<List<Role>> _rolesFuture;
  String? _selectedRoleId;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _rolesFuture = auth.apiClient.listRoles(auth.token!);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final auth = context.read<AuthController>();
    try {
      await auth.apiClient.createEmployee(
        token: auth.token!,
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
        roleId: _selectedRoleId,
      );
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
      title: const Text('Mitarbeiter hinzufügen'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'E-Mail-Adresse', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Bitte E-Mail eingeben' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pwCtrl,
                decoration: InputDecoration(
                  labelText: 'Initiales Passwort',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePw ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePw = !_obscurePw),
                  ),
                ),
                obscureText: _obscurePw,
                validator: (v) =>
                    (v == null || v.length < 8) ? 'Mindestens 8 Zeichen erforderlich' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pwConfirmCtrl,
                decoration: const InputDecoration(
                  labelText: 'Passwort bestätigen',
                  border: OutlineInputBorder(),
                ),
                obscureText: _obscurePw,
                validator: (v) =>
                    v != _pwCtrl.text ? 'Passwörter stimmen nicht überein' : null,
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Role>>(
                future: _rolesFuture,
                builder: (context, snapshot) {
                  final roles = snapshot.data ?? const <Role>[];
                  if (roles.isNotEmpty) {
                    _selectedRoleId ??= roles.firstWhere(
                      (r) => r.name == 'Nur Lesen',
                      orElse: () => roles.first,
                    ).id;
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedRoleId,
                    decoration: const InputDecoration(labelText: 'Rolle', border: OutlineInputBorder()),
                    items: [
                      for (final role in roles) DropdownMenuItem(value: role.id, child: Text(role.name)),
                    ],
                    onChanged: snapshot.connectionState == ConnectionState.done
                        ? (value) => setState(() => _selectedRoleId = value)
                        : null,
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Der Mitarbeiter kann sich danach mit diesen Zugangsdaten anmelden und das Passwort unter Benutzerverwaltung ändern. '
                'Ohne Auswahl wird die Rolle "Nur Lesen" vergeben (Least Privilege).',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Anlegen'),
        ),
      ],
    );
  }
}

/// Einfacher Rollen-Auswahldialog für den "Rolle ändern"-Aktion in der
/// Mitgliederliste.
class _RolePickerDialog extends StatefulWidget {
  const _RolePickerDialog({required this.roles, required this.initialRoleId});

  final List<Role> roles;
  final String? initialRoleId;

  @override
  State<_RolePickerDialog> createState() => _RolePickerDialogState();
}

class _RolePickerDialogState extends State<_RolePickerDialog> {
  late String? _selected = widget.initialRoleId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rolle ändern'),
      content: SizedBox(
        width: 360,
        child: DropdownButtonFormField<String>(
          initialValue: _selected,
          decoration: const InputDecoration(labelText: 'Rolle', border: OutlineInputBorder()),
          items: [
            for (final role in widget.roles) DropdownMenuItem(value: role.id, child: Text(role.name)),
          ],
          onChanged: (value) => setState(() => _selected = value),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: _selected == null ? null : () => Navigator.pop(context, _selected),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final auth = context.read<AuthController>();
    try {
      await auth.apiClient.changePassword(
        token: auth.token!,
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwort erfolgreich geändert.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Passwort ändern'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentCtrl,
                decoration: InputDecoration(
                  labelText: 'Aktuelles Passwort',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                validator: (v) => (v == null || v.isEmpty) ? 'Bitte aktuelles Passwort eingeben' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newCtrl,
                decoration: const InputDecoration(labelText: 'Neues Passwort', border: OutlineInputBorder()),
                obscureText: _obscure,
                validator: (v) =>
                    (v == null || v.length < 8) ? 'Mindestens 8 Zeichen erforderlich' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                decoration: const InputDecoration(
                  labelText: 'Neues Passwort bestätigen',
                  border: OutlineInputBorder(),
                ),
                obscureText: _obscure,
                validator: (v) => v != _newCtrl.text ? 'Passwörter stimmen nicht überein' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
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
