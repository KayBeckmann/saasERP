import 'package:backend/src/waas_billing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'monthly periods anchor to start day and clamp short months without drifting',
    () {
      final start = DateTime.utc(2026, 1, 31);
      expect(periodAt(start, 0), (
        DateTime.utc(2026, 1, 31),
        DateTime.utc(2026, 2, 28),
      ));
      expect(periodAt(start, 1), (
        DateTime.utc(2026, 2, 28),
        DateTime.utc(2026, 3, 31),
      ));
    },
  );
  test('periods cannot start before activation or after contract end', () {
    expect(
      duePeriod(
        DateTime.utc(2026, 1, 31),
        DateTime.utc(2026, 2, 27),
        DateTime.utc(2026, 5),
      ),
      isNull,
    );
    expect(
      duePeriod(
        DateTime.utc(2026, 1, 31),
        DateTime.utc(2026, 2, 28),
        DateTime.utc(2026, 3, 15),
      ),
      (DateTime.utc(2026, 1, 31), DateTime.utc(2026, 2, 28)),
    );
  });
  test(
    'billing plan rejects invalid amounts, tax rates and effective dates',
    () {
      expect(
        () => BillingPlan(
          monthlyCents: -1,
          vatBasisPoints: 1900,
          effectiveFrom: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
      expect(
        () => BillingPlan(
          monthlyCents: 100,
          vatBasisPoints: 10001,
          effectiveFrom: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
      expect(
        () => BillingPlan(
          monthlyCents: 100,
          vatBasisPoints: 1900,
          effectiveFrom: DateTime.utc(2026, 1, 1, 12),
        ),
        throwsArgumentError,
      );
      expect(
        BillingPlan(
          monthlyCents: 1999,
          vatBasisPoints: 1900,
          effectiveFrom: DateTime.utc(2026),
        ).grossCents,
        2379,
      );
    },
  );
}
