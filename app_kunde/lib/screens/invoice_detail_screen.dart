import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../formatting.dart';
import '../state/auth_controller.dart';
import '../widgets/status_chip.dart';

/// Detailansicht einer Rechnung im Kundenportal: Positionen, Zahlungsstatus
/// und PDF-Download.
class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  bool _downloading = false;

  Future<void> _downloadPdf() async {
    final auth = context.read<AuthController>();
    setState(() => _downloading = true);
    try {
      final bytes = await auth.apiClient.getInvoicePdf(token: auth.token!, invoiceId: widget.invoice.id);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${widget.invoice.invoiceNumber}.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;

    return Scaffold(
      appBar: AppBar(title: Text(invoice.invoiceNumber)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(invoice.title, style: Theme.of(context).textTheme.titleLarge)),
              const SizedBox(width: 12),
              StatusChip(label: invoiceStatusLabel(invoice.status), tone: invoiceStatusTone(invoice.status)),
            ],
          ),
          if (invoice.dueDate != null) ...[
            const SizedBox(height: 8),
            Text('Fällig am: ${formatDate(invoice.dueDate!)}'),
          ],
          const SizedBox(height: 16),
          for (final group in invoice.groupedItems) _InvoiceGroupCard(group: group),
          _PaymentSummary(invoice: invoice),
          if (invoice.notes != null && invoice.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Notizen', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(invoice.notes!),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _downloading ? null : _downloadPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF herunterladen'),
          ),
        ],
      ),
    );
  }
}

class _InvoiceGroupCard extends StatelessWidget {
  const _InvoiceGroupCard({required this.group});

  final InvoiceGroupSummary group;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.label != null) ...[
              Text(group.label!, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
            ],
            for (final item in group.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(item.description)),
                    Text(formatAmount(item.totalGross)),
                  ],
                ),
              ),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Zwischensumme: ${formatAmount(group.totalGross)}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Gesamt: ${formatAmount(invoice.totalGross)}'),
            if (invoice.priorInvoicedTotal != null)
              Text('Bereits in Rechnung gestellt: ${formatAmount(invoice.priorInvoicedTotal!)}'),
            if (invoice.dunningFeeTotal > 0)
              Text('Mahngebühren: ${formatAmount(invoice.dunningFeeTotal)}'),
            const SizedBox(height: 4),
            Text(
              'Zu zahlen: ${formatAmount(invoice.totalDue)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
