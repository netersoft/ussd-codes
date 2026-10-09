import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ussd_codes/core/services/review/service.dart';
import 'package:ussd_codes/core/services/shared_preferences/service.dart';

import '../helpers/app_harness.dart';

void main() {
  late SharedPreferencesService prefs;
  late FakeTelephonyService telephony;
  late DateTime now;
  late ReviewPrompt prompt;

  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  setUp(() async {
    prefs = (await SharedPreferencesService.getInstance())!;
    await prefs.preferences!.clear();
    telephony = FakeTelephonyService();
    now = DateTime(2026, 10, 9);
    prompt = ReviewPrompt(prefs, telephony, now: () => now);
  });

  Future<void> launch(int times) async {
    for (var i = 0; i < times; i++) {
      await prompt.onLaunch();
    }
  }

  /// A regular user: 5 launches over 3 days.
  Future<void> becomeRegular() async {
    await launch(5);
    now = now.add(const Duration(days: 3));
  }

  Future<void> readReply() async {
    prompt.onCodeAnswered();
    await prompt.onSheetClosed();
  }

  Future<void> returnFromPhoneApp() async {
    prompt.onCodeSentToPhoneApp();
    await prompt.onResume();
  }

  test('launching the app never asks for a review', () async {
    await launch(20);
    now = now.add(const Duration(days: 30));
    await launch(1);

    expect(telephony.reviewRequests, 0);
  });

  test('asks when the sheet closes after the operator replied', () async {
    await becomeRegular();
    prompt.onCodeAnswered();
    expect(telephony.reviewRequests, 0, reason: 'not over the reply');

    await prompt.onSheetClosed();
    expect(telephony.reviewRequests, 1);
  });

  test('asks when the user is back from the phone app', () async {
    await becomeRegular();
    prompt.onCodeSentToPhoneApp();
    await prompt.onSheetClosed();
    expect(telephony.reviewRequests, 0, reason: 'the phone app is opening');

    await prompt.onResume();
    expect(telephony.reviewRequests, 1);
  });

  test('a reply continued in the dialer waits for the return to the app', () async {
    await becomeRegular();
    prompt
      ..onCodeAnswered()
      ..onCodeSentToPhoneApp();
    await prompt.onSheetClosed();
    expect(telephony.reviewRequests, 0);

    await prompt.onResume();
    expect(telephony.reviewRequests, 1);
  });

  test('without a code that worked, closing a sheet or coming back asks nothing', () async {
    await becomeRegular();
    await prompt.onSheetClosed();
    await prompt.onResume();

    expect(telephony.reviewRequests, 0);
  });

  test('waits for 5 launches and 3 days', () async {
    await launch(4);
    now = now.add(const Duration(days: 10));
    await readReply();
    expect(telephony.reviewRequests, 0);

    await prefs.preferences!.clear();
    await launch(10);
    now = now.add(const Duration(days: 2));
    await returnFromPhoneApp();
    expect(telephony.reviewRequests, 0);
  });

  test('asks only once, whatever the number of codes run', () async {
    await becomeRegular();
    for (var i = 0; i < 5; i++) {
      await readReply();
      await returnFromPhoneApp();
    }
    await launch(5);
    await readReply();

    expect(telephony.reviewRequests, 1);
  });

  test('tries again after the next code when the review flow could not run', () async {
    telephony.reviewAvailable = false;
    await becomeRegular();
    await readReply();
    expect(telephony.reviewRequests, 1);

    telephony.reviewAvailable = true;
    await returnFromPhoneApp();
    expect(telephony.reviewRequests, 2);
  });
}
