import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final tenant = auth.tenant;

    return Scaffold(
      appBar: AppBar(
        title: Text(tenant?.name ?? 'saasERP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Willkommen zurück!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mandant',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${tenant?.name ?? '-'}'),
                    Text('ID: ${tenant?.id ?? '-'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Benutzer',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('E-Mail: ${user?.email ?? '-'}'),
                    Text('Rolle: ${user?.role.name ?? '-'}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
