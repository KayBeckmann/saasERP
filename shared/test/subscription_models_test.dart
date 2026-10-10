import 'package:saaserp_shared/saaserp_shared.dart';
import 'package:test/test.dart';

void main() {
  test(
    'all subscription intervals survive quote and order JSON round trips',
    () {
      for (final interval in [
        'weekly',
        'monthly',
        'quarterly',
        'semiannual',
        'yearly',
      ]) {
        final date = DateTime.utc(2026, 10, 31);
        final quote = CreateQuoteRequest(
          customerId: 'customer',
          title: 'Service',
          isSubscription: true,
          billingInterval: interval,
          billingStartDate: date,
        );
        final parsedQuote = CreateQuoteRequest.fromJson(quote.toJson());
        expect(parsedQuote.isSubscription, isTrue);
        expect(parsedQuote.billingInterval, interval);
        expect(parsedQuote.billingStartDate, date);
        final order = CreateOrderRequest(
          customerId: parsedQuote.customerId,
          title: parsedQuote.title,
          isSubscription: parsedQuote.isSubscription,
          billingInterval: parsedQuote.billingInterval,
          billingStartDate: parsedQuote.billingStartDate,
        );
        final parsedOrder = CreateOrderRequest.fromJson(order.toJson());
        expect(parsedOrder.isSubscription, isTrue);
        expect(parsedOrder.billingInterval, interval);
        expect(parsedOrder.billingStartDate, date);
      }
    },
  );

  test('older ordinary quote and order JSON defaults to no subscription', () {
    expect(
      CreateQuoteRequest.fromJson({'title': 'Old'}).isSubscription,
      isFalse,
    );
    expect(
      CreateOrderRequest.fromJson({'title': 'Old'}).isSubscription,
      isFalse,
    );
  });
}
