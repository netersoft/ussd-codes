import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_codes/core/catalog/models.dart';
import 'package:ussd_codes/core/services/shared_preferences/keys.dart';
import 'package:ussd_codes/view/modals/run_code_sheet.dart';

import 'package:ussd_codes/core/services/shared_preferences/service.dart';

import '../helpers/app_harness.dart';
import '../helpers/test_utils.dart';

const _transfer = UssdCode(
  id: 'bj-mtn.mtn-transfert-de-credit',
  label: LocalizedText({'fr': 'MTN Transfert de crédit'}),
  code: '*155*{amount}*{recipient}*{pin}#',
  category: CodeCategory.transfer,
  params: [
    UssdParam(key: 'amount', type: ParamType.amount, label: LocalizedText({'fr': 'Montant'})),
    UssdParam(key: 'recipient', type: ParamType.phone, label: LocalizedText({'fr': 'Numéro du destinataire'})),
    UssdParam(key: 'pin', type: ParamType.pin, label: LocalizedText({'fr': 'Code secret'})),
  ],
);

void main() {
  late FakeTelephonyService telephony;
  late SharedPreferencesService prefs;

  setUp(() async {
    prefs = await setupTestPreferences();
    telephony = FakeTelephonyService();
  });

  tearDown(teardownTestLocator);

  Future<void> pumpSheet(WidgetTester tester, UssdCode code) => pumpApp(
    tester,
    Scaffold(body: RunCodeSheet(code: code)),
    telephony: telephony,
  );

  testWidgets('fills the params into the code and dials it', (tester) async {
    await pumpSheet(tester, _transfer);

    await tester.enterText(find.widgetWithText(TextFormField, 'Montant'), '500');
    await tester.enterText(find.widgetWithText(TextFormField, 'Numéro du destinataire'), '97000000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Code secret'), '1234');
    await tester.pump();

    // The PIN is masked in the preview (and only typed in its obscured field).
    expect(find.text('*155*500*97000000*••••#'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is Text && (widget.data ?? '').contains('1234')), findsNothing);

    await tester.tap(find.text('Composer'));
    await tester.pumpAndSettle();

    expect(telephony.dialed, [(code: '*155*500*97000000*1234#', direct: true)]);
  });

  testWidgets('does not dial until every param is filled', (tester) async {
    await pumpSheet(tester, _transfer);

    await tester.enterText(find.widgetWithText(TextFormField, 'Montant'), '500');
    await tester.tap(find.text('Composer'));
    await tester.pumpAndSettle();

    expect(find.text('Champ obligatoire'), findsNWidgets(2));
    expect(telephony.dialed, isEmpty);
  });

  testWidgets('only digits can be typed in a param', (tester) async {
    await pumpSheet(tester, _transfer);

    await tester.enterText(find.widgetWithText(TextFormField, 'Montant'), '5*0#0a');
    await tester.pump();

    expect(find.text('*155*500*‹numéro›*‹code›#'), findsOneWidget);
  });

  testWidgets('a code without params is dialed after confirmation', (tester) async {
    const balance = UssdCode(id: 'bj-mtn.solde-mtn', label: LocalizedText({'fr': 'Solde MTN'}), code: '*124#', category: CodeCategory.account);
    await pumpSheet(tester, balance);

    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Composer'));
    await tester.pumpAndSettle();

    expect(telephony.dialed.single.code, '*124#');
  });

  testWidgets('fills a phone param from the contacts, in the local format', (tester) async {
    await prefs.setString(PrefKeys.selectedCountry, 'bj');
    telephony.pickedNumber = '+229 01 97 00 00 00';
    await pumpSheet(tester, _transfer);

    await tester.tap(find.byTooltip('Choisir un contact'));
    await tester.pumpAndSettle();

    expect(find.text('*155*‹montant›*0197000000*‹code›#'), findsOneWidget);
  });

  testWidgets('a cancelled contact pick leaves the param as it was', (tester) async {
    await pumpSheet(tester, _transfer);

    await tester.enterText(find.widgetWithText(TextFormField, 'Numéro du destinataire'), '97');
    await tester.tap(find.byTooltip('Choisir un contact'));
    await tester.pumpAndSettle();

    expect(find.text('*155*‹montant›*97*‹code›#'), findsOneWidget);
  });
}
