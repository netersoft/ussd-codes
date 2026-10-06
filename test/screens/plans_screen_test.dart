import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_codes/core/services/shared_preferences/keys.dart';
import 'package:ussd_codes/core/services/shared_preferences/service.dart';
import 'package:ussd_codes/view/modals/run_code_sheet.dart';
import 'package:ussd_codes/view/screens/plans/plans_screen.dart';

import '../helpers/app_harness.dart';
import '../helpers/test_utils.dart';

void main() {
  late SharedPreferencesService prefs;
  late FakeTelephonyService telephony;

  setUp(() async {
    prefs = await setupTestPreferences();
    telephony = FakeTelephonyService();
  });

  tearDown(teardownTestLocator);

  // The plans in the bundled catalog were checked on 2026-10-06.
  Future<void> pumpPlans(WidgetTester tester, String country, {DateTime? now}) async {
    await prefs.setString(PrefKeys.selectedCountry, country);
    await pumpApp(tester, const PlansScreen(), telephony: telephony, now: now ?? DateTime(2026, 10, 20));
  }

  List<String> titles(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) (tile.title! as Text).data!,
  ];

  testWidgets('lists the bundles of the country, cheapest per GB first', (tester) async {
    await pumpPlans(tester, 'tg');

    // Yas Net599 (5 GB for 599 F) beats every day-time bundle in Togo.
    expect(titles(tester).first, '5 Go · 24 h');
    expect(find.textContaining('Yas'), findsWidgets);
    expect(find.textContaining('Moov Africa'), findsWidgets);
  });

  testWidgets('night bundles show only on request', (tester) async {
    await pumpPlans(tester, 'tg');
    expect(titles(tester).where((title) => title.endsWith('Nuit')), isEmpty);

    await tester.tap(find.text('Nuit'));
    await tester.pumpAndSettle();

    expect(titles(tester), everyElement(endsWith('Nuit')));
  });

  testWidgets('a bundle opens its purchase code', (tester) async {
    await pumpPlans(tester, 'ci');

    await tester.tap(find.text('Prix'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    final sheet = tester.widget<RunCodeSheet>(find.byType(RunCodeSheet));
    expect(sheet.code.code, '#149*31#');
    expect(sheet.code.label.values.values.single, 'Forfait 220 Mo – 2 jours');
  });

  testWidgets('prices older than 90 days are to confirm', (tester) async {
    await pumpPlans(tester, 'bj', now: DateTime(2027, 2));
    expect(find.text('Prix à confirmer'), findsWidgets);
  });

  testWidgets('prices older than 180 days are hidden', (tester) async {
    await pumpPlans(tester, 'bj', now: DateTime(2027, 6));
    expect(find.byType(ListTile), findsNothing);
    expect(find.textContaining('Le comparateur couvre'), findsOneWidget);
  });
}
