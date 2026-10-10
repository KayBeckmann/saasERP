import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_user/widgets/subscription_fields.dart';

void main() {
  testWidgets(
    'subscription requires interval and start date before form validates',
    (tester) async {
      final key = GlobalKey<FormState>();
      bool enabled = false;
      String? interval;
      DateTime? start;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Form(
                key: key,
                child: SingleChildScrollView(
                  child: SubscriptionFields(
                    isSubscription: enabled,
                    billingInterval: interval,
                    billingStartDate: start,
                    isQuote: true,
                    onChanged: (value, cadence, date) => setState(() {
                      enabled = value;
                      interval = cadence;
                      start = date;
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isTrue);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.textContaining('Angebot ist ein Vorschlag'), findsOneWidget);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Intervall erforderlich'), findsOneWidget);
      expect(find.text('Startdatum erforderlich'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quartalsweise').last);
      await tester.pumpAndSettle();
      expect(interval, 'quarterly');
      expect(key.currentState!.validate(), isFalse);
      await tester.tap(find.text('Startdatum auswählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK').last);
      await tester.pumpAndSettle();
      expect(start, isNotNull);
      expect(key.currentState!.validate(), isTrue);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(enabled, isFalse);
      expect(interval, isNull);
      expect(start, isNull);
      expect(key.currentState!.validate(), isTrue);
    },
  );

  test('subscription summary is absent for ordinary documents', () {
    expect(subscriptionSummary(false, null, null), isNull);
    expect(
      subscriptionSummary(true, 'monthly', DateTime(2026, 10, 12)),
      'Abo · Monatlich · ab 12.10.2026',
    );
  });
}
