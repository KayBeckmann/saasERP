import 'package:backend/src/repositories/waas_billing_repository.dart';
import 'package:test/test.dart';

void main() {
  test('a recurring invoice cannot be published without explicit approval', () {
    expect(BillingRunState.draft.visibleToCustomer, isFalse);
    expect(BillingRunState.approved.visibleToCustomer, isTrue);
  });
}
