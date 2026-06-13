import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../state/auth_controller.dart';
import '../theme.dart';
import 'articles_screen.dart';
import 'customers_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'quotes_screen.dart';
import 'suppliers_screen.dart';

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
            if (user?.role == UserRole.owner && tenant != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Firmendaten & Steuersätze',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _CompanyConfigEditor(tenant: tenant),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Kunden'),
                subtitle: const Text('Kundenstamm verwalten'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CustomersScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text('Lieferanten'),
                subtitle: const Text('Lieferantenstamm verwalten'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SuppliersScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Artikel'),
                subtitle: const Text('Artikelstamm verwalten'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ArticlesScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.widgets_outlined),
                title: const Text('Produkte'),
                subtitle: const Text('Bundles aus Artikeln & Arbeitszeit verwalten'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProductsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Angebote'),
                subtitle: const Text('Angebote erstellen und verwalten'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QuotesScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text('Aufträge'),
                subtitle: const Text('Aufträge erstellen und verwalten'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OrdersScreen()),
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

/// Editor für Firmendaten und Steuersätze des Mandanten (nur Owner).
/// Grundlage für Briefkopf/Belege und Nummernkreise (Mandanten-Konfiguration).
class _CompanyConfigEditor extends StatefulWidget {
  const _CompanyConfigEditor({required this.tenant});

  final Tenant? tenant;

  @override
  State<_CompanyConfigEditor> createState() => _CompanyConfigEditorState();
}

class _CompanyConfigEditorState extends State<_CompanyConfigEditor> {
  late final TextEditingController _addressController =
      TextEditingController(text: widget.tenant?.companyAddress ?? '');
  late final TextEditingController _taxIdController =
      TextEditingController(text: widget.tenant?.companyTaxId ?? '');
  late final TextEditingController _logoUrlController =
      TextEditingController(text: widget.tenant?.logoUrl ?? '');
  late final TextEditingController _defaultVatController =
      TextEditingController(text: _formatRate(widget.tenant?.defaultVatRate ?? 19.0));
  late final TextEditingController _reducedVatController =
      TextEditingController(text: _formatRate(widget.tenant?.reducedVatRate ?? 7.0));

  static String _formatRate(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  @override
  void dispose() {
    _addressController.dispose();
    _taxIdController.dispose();
    _logoUrlController.dispose();
    _defaultVatController.dispose();
    _reducedVatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _addressController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Firmenadresse',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _taxIdController,
          decoration: const InputDecoration(
            labelText: 'Steuernummer / USt-IdNr.',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _logoUrlController,
          decoration: const InputDecoration(
            labelText: 'Logo-URL',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _defaultVatController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Standard-MwSt. (%)',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _reducedVatController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Ermäßigte MwSt. (%)',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () {
              final defaultVat = double.tryParse(_defaultVatController.text.replaceAll(',', '.'));
              final reducedVat = double.tryParse(_reducedVatController.text.replaceAll(',', '.'));
              if (defaultVat == null || reducedVat == null) return;
              auth.updateTenantConfig(
                UpdateTenantConfigRequest(
                  companyAddress: _addressController.text.trim().isEmpty
                      ? null
                      : _addressController.text.trim(),
                  companyTaxId: _taxIdController.text.trim().isEmpty
                      ? null
                      : _taxIdController.text.trim(),
                  logoUrl: _logoUrlController.text.trim().isEmpty
                      ? null
                      : _logoUrlController.text.trim(),
                  defaultVatRate: defaultVat,
                  reducedVatRate: reducedVat,
                ),
              );
            },
            child: const Text('Speichern'),
          ),
        ),
      ],
    );
  }
}
