/// Fixed-point net price and tax, effective at a monthly period boundary.
class BillingPlan {
  BillingPlan({
    required this.monthlyCents,
    required this.vatBasisPoints,
    required this.effectiveFrom,
  }) {
    if (monthlyCents <= 0 ||
        vatBasisPoints < 0 ||
        vatBasisPoints > 10000 ||
        effectiveFrom !=
            DateTime.utc(
              effectiveFrom.year,
              effectiveFrom.month,
              effectiveFrom.day,
            )) {
      throw ArgumentError('Invalid price, VAT or effective date');
    }
  }

  final int monthlyCents;
  final int vatBasisPoints;
  final DateTime effectiveFrom;
  int get grossCents =>
      monthlyCents + (monthlyCents * vatBasisPoints / 10000).round();
}

/// Half-open monthly billing windows anchored to the original start date.
/// UTC calendar dates only; a short month never changes the original anchor.
(DateTime, DateTime) periodAt(DateTime start, int index) {
  if (index < 0) throw ArgumentError.value(index, 'index');
  DateTime boundary(int months) {
    final month = start.month + months;
    final first = DateTime.utc(start.year, month);
    final lastDay = DateTime.utc(start.year, month + 1, 0).day;
    return DateTime.utc(
      first.year,
      first.month,
      start.day > lastDay ? lastDay : start.day,
    );
  }

  return (boundary(index), boundary(index + 1));
}

/// Last fully elapsed window, null until the first window ends.
(DateTime, DateTime)? duePeriod(
  DateTime start,
  DateTime asOf,
  DateTime contractEnd,
) {
  if (!asOf.isAfter(start)) return null;
  var index = 0;
  while (index < 1200) {
    final window = periodAt(start, index);
    if (window.$2.isAfter(asOf) || window.$2.isAfter(contractEnd))
      return index == 0 ? null : periodAt(start, index - 1);
    index++;
  }
  throw StateError('billing horizon exceeded');
}
