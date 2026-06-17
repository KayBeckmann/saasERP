import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/invoice_export_dialog.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final tenant = auth.tenant;

    return AppShell(
      currentItem: AppNavItem.dashboard,
      title: tenant?.name ?? 'saasERP',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Willkommen zurück!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            const _AnalyticsCard(),
            const SizedBox(height: 16),
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

/// Kennzahlen-Übersicht (offene Belege, überfällige Rechnungen,
/// Monatsstunden) sowie der Steuerberater-Export (CSV).
class _AnalyticsCard extends StatefulWidget {
  const _AnalyticsCard();

  @override
  State<_AnalyticsCard> createState() => _AnalyticsCardState();
}

class _AnalyticsCardState extends State<_AnalyticsCard> {
  late Future<DashboardSummary> _future;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _future = auth.apiClient.getDashboardSummary(auth.token!);
  }

  Future<void> _export() async {
    final range = await showInvoiceExportDialog(context: context);
    if (range == null) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    setState(() => _exporting = true);
    try {
      final bytes = await auth.apiClient.exportInvoicesCsv(
        token: auth.token!,
        from: range.from,
        to: range.to,
      );
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'rechnungen-export.csv', mimeType: 'text/csv')],
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export-Fehler: ${e.message}')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Auswertungen', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _exporting ? null : _export,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Steuerberater-Export (CSV)'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<DashboardSummary>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Text('Fehler beim Laden: ${snapshot.error}');
                }
                final summary = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Offene Angebote: ${summary.openQuotes}'),
                    Text('Offene Aufträge: ${summary.openOrders}'),
                    Text('Offene Bestellungen: ${summary.openPurchaseOrders}'),
                    Text('Offene Rechnungen: ${summary.openInvoices}'),
                    Text(
                      'Überfällige Rechnungen: ${summary.overdueInvoicesCount} '
                      '(${_formatNumber(summary.overdueInvoicesTotal)} €)',
                    ),
                    Text('Stunden im aktuellen Monat: ${_formatNumber(summary.monthlyHours)}'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _formatNumber(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

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
  late final TextEditingController _ibanController =
      TextEditingController(text: widget.tenant?.companyIban ?? '');
  late final TextEditingController _logoUrlController =
      TextEditingController(text: widget.tenant?.logoUrl ?? '');
  late final TextEditingController _defaultVatController =
      TextEditingController(text: _formatRate(widget.tenant?.defaultVatRate ?? 19.0));
  late final TextEditingController _reducedVatController =
      TextEditingController(text: _formatRate(widget.tenant?.reducedVatRate ?? 7.0));
  late final TextEditingController _dunningFee1Controller =
      TextEditingController(text: _formatRate(widget.tenant?.dunningFeeLevel1 ?? 0));
  late final TextEditingController _dunningFee2Controller =
      TextEditingController(text: _formatRate(widget.tenant?.dunningFeeLevel2 ?? 5.0));
  late final TextEditingController _dunningFee3Controller =
      TextEditingController(text: _formatRate(widget.tenant?.dunningFeeLevel3 ?? 10.0));
  late final TextEditingController _defaultHourlyRateController =
      TextEditingController(text: _formatRate(widget.tenant?.defaultHourlyRate ?? 0));

  static String _formatRate(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  @override
  void dispose() {
    _addressController.dispose();
    _taxIdController.dispose();
    _ibanController.dispose();
    _logoUrlController.dispose();
    _defaultVatController.dispose();
    _reducedVatController.dispose();
    _dunningFee1Controller.dispose();
    _dunningFee2Controller.dispose();
    _dunningFee3Controller.dispose();
    _defaultHourlyRateController.dispose();
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
          controller: _ibanController,
          decoration: const InputDecoration(
            labelText: 'IBAN (Zahlungshinweis auf Rechnungen)',
            hintText: 'DE12 3456 7890 1234 5678 90',
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
        Text('Mahngebühren (EUR)', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _dunningFee1Controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Zahlungserinnerung',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _dunningFee2Controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '1. Mahnung',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _dunningFee3Controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '2. Mahnung',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _defaultHourlyRateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Stundensatz für Projekt-Auswertung (€)',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () {
              final defaultVat = double.tryParse(_defaultVatController.text.replaceAll(',', '.'));
              final reducedVat = double.tryParse(_reducedVatController.text.replaceAll(',', '.'));
              final dunningFee1 = double.tryParse(_dunningFee1Controller.text.replaceAll(',', '.'));
              final dunningFee2 = double.tryParse(_dunningFee2Controller.text.replaceAll(',', '.'));
              final dunningFee3 = double.tryParse(_dunningFee3Controller.text.replaceAll(',', '.'));
              final defaultHourlyRate = double.tryParse(_defaultHourlyRateController.text.replaceAll(',', '.'));
              if (defaultVat == null || reducedVat == null) return;
              if (dunningFee1 == null || dunningFee2 == null || dunningFee3 == null) return;
              if (defaultHourlyRate == null) return;
              auth.updateTenantConfig(
                UpdateTenantConfigRequest(
                  companyAddress: _addressController.text.trim().isEmpty
                      ? null
                      : _addressController.text.trim(),
                  companyTaxId: _taxIdController.text.trim().isEmpty
                      ? null
                      : _taxIdController.text.trim(),
                  companyIban: _ibanController.text.trim().isEmpty
                      ? null
                      : _ibanController.text.trim(),
                  logoUrl: _logoUrlController.text.trim().isEmpty
                      ? null
                      : _logoUrlController.text.trim(),
                  defaultVatRate: defaultVat,
                  reducedVatRate: reducedVat,
                  dunningFeeLevel1: dunningFee1,
                  dunningFeeLevel2: dunningFee2,
                  dunningFeeLevel3: dunningFee3,
                  defaultHourlyRate: defaultHourlyRate,
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
