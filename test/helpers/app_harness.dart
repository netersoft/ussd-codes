import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ussd_codes/core/catalog/catalog_repository.dart';
import 'package:ussd_codes/core/providers/catalog_provider.dart';
import 'package:ussd_codes/core/services/i18n/translations.g.dart';
import 'package:ussd_codes/core/services/shared_preferences/service.dart';
import 'package:ussd_codes/core/services/telephony/service.dart';

import 'test_utils.dart';

/// Records dial requests instead of reaching the platform.
class FakeTelephonyService extends TelephonyService {
  final List<String> sims;

  /// Countries of the networks the phone is on.
  List<String> networkCountryIds;
  final dialed = <({String code, bool direct})>[];
  int reviewRequests = 0;
  bool reviewAvailable = true;

  /// What the contact picker answers (null: cancelled).
  String? pickedNumber;

  FakeTelephonyService({this.sims = const [], this.networkCountryIds = const []});

  @override
  Future<List<String>> networkCountries() async => networkCountryIds;

  @override
  bool get canPickContact => true;

  @override
  Future<String?> pickPhoneNumber() async => pickedNumber;

  @override
  Future<List<String>> simOperators() async => sims;

  @override
  Future<DialOutcome> dial(String code, {required bool direct, bool isDeviceCode = false}) async {
    dialed.add((code: code, direct: direct));
    return DialOutcome.dialerOpened;
  }

  @override
  Future<LegacyData?> readLegacyData() async => null;

  @override
  Future<bool> requestReview() async {
    reviewRequests++;
    return reviewAvailable;
  }
}

/// Real preferences (cleared), registered in the locator like at runtime.
Future<SharedPreferencesService> setupTestPreferences() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await SharedPreferencesService.getInstance())!;
  await prefs.preferences!.clear();
  await setupTestLocator(sharedPreferencesService: prefs);
  return prefs;
}

/// Pumps [child] with the app's providers, translations (French) and the
/// bundled catalog, the telephony layer replaced by [telephony].
Future<void> pumpApp(WidgetTester tester, Widget child, {required FakeTelephonyService telephony}) async {
  final cacheDir = Directory.systemTemp.createTempSync('catalog_cache');
  addTearDown(() => cacheDir.deleteSync(recursive: true));

  final container = ProviderContainer(
    overrides: [
      telephonyServiceProvider.overrideWithValue(telephony),
      catalogRepositoryProvider.overrideWithValue(CatalogRepository(remoteUrl: '', cacheDir: () async => cacheDir)),
    ],
  );
  addTearDown(container.dispose);

  // The catalog loads from assets and disk: real async work, outside the
  // fake clock.
  await tester.runAsync(() async {
    await container.read(currentCatalogProvider.future);
    await container.read(simOperatorsProvider.future);
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(child: MaterialApp(home: child)),
    ),
  );
  await tester.pumpAndSettle();
}
