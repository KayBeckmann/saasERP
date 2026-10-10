import 'dart:async';
import 'dart:io';
import 'package:backend/src/config.dart';
import 'package:backend/src/db.dart';
import 'package:backend/src/repositories/order_subscription_billing_repository.dart';

Future<void> main() async {
  final pool = createDbPool(AppConfig.fromEnvironment());
  final billing = OrderSubscriptionBillingRepository(pool);
  Future<void> tick() async {
    try {
      await billing.runDue();
    } catch (error, stack) {
      stderr.writeln('Subscription scheduler failed: $error\n$stack');
    }
  }

  try {
    // Catch up immediately on boot. Next wake is the following UTC midnight.
    while (true) {
      await tick();
      final now = DateTime.now().toUtc();
      final next = DateTime.utc(now.year, now.month, now.day + 1);
      await Future<void>.delayed(next.difference(now));
    }
  } finally {
    await pool.close();
  }
}
