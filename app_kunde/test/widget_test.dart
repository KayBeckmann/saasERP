import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_kunde/main.dart';

void main() {
  testWidgets('Login screen is shown for unauthenticated users', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Kundenportal'), findsOneWidget);
    expect(find.text('Anmelden'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Einloggen'), findsOneWidget);
  });
}
