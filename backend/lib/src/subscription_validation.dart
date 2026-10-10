/// Reject incomplete recurring subscriptions before reserving a document number.
void validateSubscription(
  bool enabled,
  String? interval,
  DateTime? start,
  String? customer,
) {
  if (!enabled) return;
  if (!const {
        'weekly',
        'monthly',
        'quarterly',
        'semiannual',
        'yearly',
      }.contains(interval) ||
      start == null ||
      customer == null ||
      customer.isEmpty) {
    throw ArgumentError(
      'Subscription requires a customer, billing interval and start date',
    );
  }
}
