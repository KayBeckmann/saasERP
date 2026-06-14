import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../state/auth_controller.dart';
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

  Color _statusColor(ProjectStatus status, BuildContext context) => switch (status) {
        ProjectStatus.open => Theme.of(context).colorScheme.surfaceContainerHighest,
        ProjectStatus.completed => Colors.green.shade100,
        ProjectStatus.cancelled => Colors.red.shade100,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projekte')),
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
          if (data.projects.isEmpty) {
            return const Center(child: Text('Noch keine Projekte vorhanden.'));
          }

          return ListView.builder(
            itemCount: data.projects.length,
            itemBuilder: (context, index) {
              final project = data.projects[index];
              final customerName = _customerName(project.customerId, data.customers);

              return ListTile(
                title: Text('${project.projectNumber} · ${project.name}'),
                subtitle: customerName == null ? null : Text(customerName),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(project.status, context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_statusLabel(project.status)),
                ),
                onTap: () => _openEditor(project: project),
              );
            },
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
