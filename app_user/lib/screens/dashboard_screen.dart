import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../state/auth_controller.dart';
import '../theme.dart';

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
          if (auth.availableTenants.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Mandant wechseln',
              icon: const Icon(Icons.apartment),
              onSelected: (tenantId) => auth.switchTenant(tenantId),
              itemBuilder: (context) => auth.availableTenants
                  .map(
                    (access) => PopupMenuItem(
                      value: access.tenant.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (access.tenant.id == tenant?.id)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.check, size: 18),
                            ),
                          Text(access.tenant.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
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
                    if (user?.role == UserRole.owner) ...[
                      const SizedBox(height: 16),
                      _BrandingEditor(brandingColor: tenant?.brandingColor),
                    ],
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

/// Branding-Editor für Owner: setzt die Primärfarbe des Mandanten
/// (Whitelabel-Potenzial), wirkt sofort auf das App-Theme.
class _BrandingEditor extends StatefulWidget {
  const _BrandingEditor({required this.brandingColor});

  final String? brandingColor;

  @override
  State<_BrandingEditor> createState() => _BrandingEditorState();
}

class _BrandingEditorState extends State<_BrandingEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.brandingColor ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: parseBrandingColor(widget.brandingColor) ??
                Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Branding-Farbe (#RRGGBB)',
              hintText: '#091426',
              isDense: true,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check),
          tooltip: 'Speichern',
          onPressed: () {
            final value = _controller.text.trim();
            auth.updateTenantBranding(value.isEmpty ? null : value);
          },
        ),
        IconButton(
          icon: const Icon(Icons.restart_alt),
          tooltip: 'Zurücksetzen',
          onPressed: () {
            _controller.clear();
            auth.updateTenantBranding(null);
          },
        ),
      ],
    );
  }
}
