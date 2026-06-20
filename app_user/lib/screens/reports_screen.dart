import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';

/// Berichte-Screen (Platzhalter — wird in einem späteren Meilenstein ausgebaut).
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentItem: AppNavItem.reports,
      title: 'Berichte',
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'Berichte werden in einem der nächsten Meilensteine implementiert.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
