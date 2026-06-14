import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../formatting.dart';
import '../state/auth_controller.dart';
import '../widgets/status_chip.dart';

/// Detailansicht eines Wartungsvertrags/Abos im Kundenportal: Laufzeit,
/// Kündigungsfrist und — solange `status == active` — eine
/// Vertragsstrafen-Vorschau bei Kündigung zum heutigen Tag mit
/// Kündigungs-Button.
class MaintenanceContractDetailScreen extends StatefulWidget {
  const MaintenanceContractDetailScreen({super.key, required this.contract});

  final MaintenanceContract contract;

  @override
  State<MaintenanceContractDetailScreen> createState() => _MaintenanceContractDetailScreenState();
}

class _MaintenanceContractDetailScreenState extends State<MaintenanceContractDetailScreen> {
  late MaintenanceContract _contract;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _contract = widget.contract;
  }

  double get _previewPenalty {
    final contract = _contract;
    if (contract.termMonths <= 0) return 0;
    return contract.maxPenalty * contract.remainingMonths(DateTime.now()) / contract.termMonths;
  }

  Future<void> _cancel() async {
    final auth = context.read<AuthController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vertrag kündigen?'),
        content: Text(
          'Bei einer Kündigung zum heutigen Tag (${formatDate(DateTime.now())}) fällt voraussichtlich '
          'eine Vertragsstrafe von ${formatAmount(_previewPenalty)} an.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kündigen')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      final updated = await auth.apiClient.cancelMaintenanceContract(token: auth.token!, contractId: _contract.id);
      if (!mounted) return;
      setState(() => _contract = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contract = _contract;

    return Scaffold(
      appBar: AppBar(title: Text(contract.contractNumber)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(contract.title, style: Theme.of(context).textTheme.titleLarge)),
              const SizedBox(width: 12),
              StatusChip(label: contractStatusLabel(contract.status), tone: contractStatusTone(contract.status)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Laufzeit: ${formatDate(contract.startDate)} – ${formatDate(contract.endDate)}'),
                  Text('Vertragsdauer: ${contract.termMonths} Monate'),
                  Text('Kündigungsfrist: ${contract.noticePeriodMonths} Monate'),
                  if (contract.maxPenalty > 0)
                    Text('Maximale Vertragsstrafe: ${formatAmount(contract.maxPenalty)}'),
                ],
              ),
            ),
          ),
          if (contract.notes != null && contract.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Notizen', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(contract.notes!),
          ],
          const SizedBox(height: 24),
          if (contract.status == MaintenanceContractStatus.active) ...[
            if (contract.maxPenalty > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Vertragsstrafe bei Kündigung heute: ${formatAmount(_previewPenalty)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            FilledButton(
              onPressed: _submitting ? null : _cancel,
              child: const Text('Vertrag kündigen'),
            ),
          ] else if (contract.cancelledAt != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gekündigt am ${formatDate(contract.cancelledAt!)}'),
                    if (contract.penalty > 0)
                      Text('Vertragsstrafe: ${formatAmount(contract.penalty)}'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
