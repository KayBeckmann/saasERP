import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';

/// Erste Übersichtsseite des Kundenportals nach Login/Invite-Annahme.
/// Grundgerüst — die eigentlichen Inhalte (Angebote, Rechnungen,
/// Wartungsverträge) folgen in den nächsten M2b-Schritten.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.tenantName ?? 'Kundenportal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Willkommen, ${auth.customerName ?? ''}!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Mandant: ${auth.tenantName ?? '-'}'),
                    Text('E-Mail: ${auth.account?.email ?? '-'}'),
                    const SizedBox(height: 16),
                    Text(
                      'Hier finden Sie demnächst Ihre Angebote, Rechnungen und Wartungsverträge.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
