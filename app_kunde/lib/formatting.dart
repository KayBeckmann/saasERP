import 'package:saaserp_shared/saaserp_shared.dart';

import 'widgets/status_chip.dart';

/// Datum im deutschen Format `dd.MM.yyyy` — ohne `intl`-Package.
String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

/// Geldbetrag mit zwei Nachkommastellen und Euro-Symbol.
String formatAmount(double value) => '${value.toStringAsFixed(2)} €';

String quoteStatusLabel(QuoteStatus status) => switch (status) {
      QuoteStatus.draft => 'Entwurf',
      QuoteStatus.sent => 'Versendet',
      QuoteStatus.accepted => 'Angenommen',
      QuoteStatus.rejected => 'Abgelehnt',
    };

StatusTone quoteStatusTone(QuoteStatus status) => switch (status) {
      QuoteStatus.draft => StatusTone.neutral,
      QuoteStatus.sent => StatusTone.info,
      QuoteStatus.accepted => StatusTone.success,
      QuoteStatus.rejected => StatusTone.error,
    };
