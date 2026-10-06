import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_codes/core/services/shared_preferences/keys.dart';
import 'package:ussd_codes/core/services/shared_preferences/service.dart';
import 'package:ussd_codes/view/screens/operators/operators_screen.dart';

import '../helpers/app_harness.dart';
import '../helpers/test_utils.dart';

void main() {
  late SharedPreferencesService prefs;

  setUp(() async => prefs = await setupTestPreferences());

  tearDown(teardownTestLocator);

  testWidgets("opens on the SIM's country and operator", (tester) async {
    // 61603: MTN Benin.
    await pumpApp(tester, const OperatorsScreen(), telephony: FakeTelephonyService(sims: ['61603']));

    expect(find.text('🇧🇯  Bénin'), findsOneWidget);
    expect(find.byIcon(Icons.sim_card_outlined), findsOneWidget);
    expect(find.text('Solde MTN'), findsOneWidget);
  });

  testWidgets('the country picked by the user wins over the SIM', (tester) async {
    await prefs.setString(PrefKeys.selectedCountry, 'sn');
    await pumpApp(tester, const OperatorsScreen(), telephony: FakeTelephonyService(sims: ['61603']));

    expect(find.text('🇸🇳  Sénégal'), findsOneWidget);
    expect(find.text('Solde MTN'), findsNothing);
  });

  testWidgets('a star adds the code to the favorites', (tester) async {
    await pumpApp(tester, const OperatorsScreen(), telephony: FakeTelephonyService(sims: ['61603']));

    final tile = find.ancestor(of: find.text('Solde MTN'), matching: find.byType(ListTile));
    await tester.tap(find.descendant(of: tile, matching: find.byIcon(Icons.star_border)));
    await tester.pump();

    expect(prefs.getListString(PrefKeys.favorites), ['bj-mtn.solde-mtn']);
    expect(find.descendant(of: tile, matching: find.byIcon(Icons.star)), findsOneWidget);
  });

  testWidgets('favorites come first in the operator list, like in the legacy app', (tester) async {
    await prefs.setStringList(PrefKeys.favorites, ['bj-mtn.mtn-bip-me']);
    await pumpApp(tester, const OperatorsScreen(), telephony: FakeTelephonyService(sims: ['61603']));

    final favoritesHeader = tester.getTopLeft(find.text('FAVORIS'));
    final favorite = tester.getTopLeft(find.text('MTN Bip Me'));
    final balance = tester.getTopLeft(find.text('Solde MTN'));
    expect(favorite.dy, greaterThan(favoritesHeader.dy));
    expect(favorite.dy, lessThan(balance.dy));
    expect(find.text('MTN Bip Me'), findsOneWidget);
  });
}
