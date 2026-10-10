import 'package:flutter/material.dart';

const billingIntervalLabels = <String, String>{
  'weekly': 'Wöchentlich',
  'monthly': 'Monatlich',
  'quarterly': 'Quartalsweise',
  'semiannual': 'Halbjährlich',
  'yearly': 'Jährlich',
};

String formatBillingDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String? subscriptionSummary(bool enabled, String? interval, DateTime? start) {
  if (!enabled) return null;
  final cadence = billingIntervalLabels[interval] ?? 'Intervall offen';
  return 'Abo · $cadence${start == null ? '' : ' · ab ${formatBillingDate(start)}'}';
}

/// Shared quote/order editor fields. Disabled documents never send stale cadence/date.
class SubscriptionFields extends StatelessWidget {
  const SubscriptionFields({
    super.key,
    required this.isSubscription,
    required this.billingInterval,
    required this.billingStartDate,
    required this.isQuote,
    required this.onChanged,
  });

  final bool isSubscription;
  final String? billingInterval;
  final DateTime? billingStartDate;
  final bool isQuote;
  final void Function(bool enabled, String? interval, DateTime? start)
  onChanged;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: billingStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(true, billingInterval, picked);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Abo'),
        value: isSubscription,
        onChanged: (enabled) => onChanged(
          enabled,
          enabled ? billingInterval : null,
          enabled ? billingStartDate : null,
        ),
      ),
      if (isSubscription) ...[
        DropdownButtonFormField<String>(
          key: ValueKey(billingInterval),
          initialValue: billingInterval,
          decoration: const InputDecoration(labelText: 'Abrechnungsintervall'),
          hint: const Text('Abrechnungsintervall'),
          items: [
            for (final entry in billingIntervalLabels.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          validator: (value) => value == null ? 'Intervall erforderlich' : null,
          onChanged: (value) => onChanged(true, value, billingStartDate),
        ),
        const SizedBox(height: 8),
        FormField<DateTime>(
          initialValue: billingStartDate,
          validator: (_) =>
              billingStartDate == null ? 'Startdatum erforderlich' : null,
          builder: (field) => InkWell(
            onTap: () => _pickDate(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Abrechnungsbeginn',
                errorText: field.errorText,
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              child: Text(
                billingStartDate == null
                    ? 'Startdatum auswählen'
                    : formatBillingDate(billingStartDate!),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isQuote
              ? 'Das Abo-Angebot ist ein Vorschlag. Erst ein Auftrag erzeugt automatisch Rechnungsentwürfe; kein automatischer Versand.'
              : 'Nur dieser Abo-Auftrag erzeugt automatisch Rechnungsentwürfe. Kein automatischer Versand.',
        ),
      ],
    ],
  );
}
