import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ussd_codes/core/services/review/service.dart';
import 'package:ussd_codes/core/services/shared_preferences/service.dart';

import '../helpers/app_harness.dart';

void main() {
  late SharedPreferencesService prefs;
  late FakeTelephonyService telephony;
  late DateTime now;

  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  setUp(() async {
    prefs = (await SharedPreferencesService.getInstance())!;
    await prefs.preferences!.clear();
    telephony = FakeTelephonyService();
    now = DateTime(2026, 10, 6);
  });

  Future<void> launch(int times) async {
    for (var i = 0; i < times; i++) {
      await ReviewPrompt(prefs, telephony, now: () => now).onLaunch();
    }
  }

  test('asks after 10 launches over at least 10 days, like the legacy app', () async {
    await launch(9);
    now = now.add(const Duration(days: 10));
    expect(telephony.reviewRequests, 0);

    await launch(1);
    expect(telephony.reviewRequests, 1);
  });

  test('waits for 10 days even after many launches', () async {
    await launch(30);
    now = now.add(const Duration(days: 9));
    await launch(1);

    expect(telephony.reviewRequests, 0);
  });

  test('asks only once', () async {
    await launch(10);
    now = now.add(const Duration(days: 10));
    await launch(5);

    expect(telephony.reviewRequests, 1);
  });

  test('tries again on the next launch when the review flow could not run', () async {
    telephony.reviewAvailable = false;
    await launch(1);
    now = now.add(const Duration(days: 10));
    await launch(9);
    expect(telephony.reviewRequests, 1);

    telephony.reviewAvailable = true;
    await launch(2);
    expect(telephony.reviewRequests, 2);
  });
}
