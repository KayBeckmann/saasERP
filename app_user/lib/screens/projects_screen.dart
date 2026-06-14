import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../state/auth_controller.dart';
import '../widgets/app_data_table.dart';
import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'project_editor_screen.dart';

/// Listet die Projekte des Mandanten und erlaubt Anlegen/Bearbeiten.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late Future<({List<Project> projects, List<Customer> customers})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<Project> projects, List<Customer> customers})> _load() async {
    final auth = context.read<AuthController>();
    final projects = await auth.apiClient.listProjects(auth.token!);
    final customers = await auth.apiClient.listCustomers(auth.token!);
    return (projects: projects, customers: customers);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _openEditor({Project? project}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProjectEditorScreen(project: project)),
    );
    if (changed ?? false) _reload();
  }

  String? _customerName(String? customerId, List<Customer> customers) {
    if (customerId == null) return null;
    for (final customer in customers) {
      if (customer.id == customerId) return customer.name;
    }
    return null;
  }

  String _statusLabel(ProjectStatus status) => switch (status) {
        ProjectStatus.open => 'Offen',
        ProjectStatus.completed => 'Abgeschlossen',
        ProjectStatus.cancelled => 'Abgebrochen',
      };

  StatusTone _statusTone(ProjectStatus status) => switch (status) {
        ProjectStatus.open => StatusTone.warning,
        ProjectStatus.completed => StatusTone.success,
        ProjectStatus.cancelled => StatusTone.error,
      };

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentItem: AppNavItem.projects,
      title: 'Projekte',
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
            emptyLabel: 'Noch keine Projekte vorhanden.',
            columns: const [
              AppDataColumn('Projekt', flex: 3),
              AppDataColumn('Kunde', flex: 2),
              AppDataColumn('Status', flex: 1),
            ],
            rows: [
              for (final project in data.projects)
                AppDataRow(
                  onTap: () => _openEditor(project: project),
                  cells: [
                    Text('${project.projectNumber} · ${project.name}'),
                    Text(_customerName(project.customerId, data.customers) ?? '-'),
                    StatusChip(label: _statusLabel(project.status), tone: _statusTone(project.status)),
                  ],
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'Neues Projekt',
        child: const Icon(Icons.add),
      ),
    );
  }
}
