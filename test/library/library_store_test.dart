import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ussd_codes/core/catalog/sources.dart';
import 'package:ussd_codes/core/library/library_store.dart';
import 'package:ussd_codes/core/services/shared_preferences/service.dart';
import 'package:ussd_codes/core/services/telephony/service.dart';

LegacyCode _row(String description, String code, String fragment, {bool isNative = true, bool isFavorite = true}) =>
    (description: description, code: code, fragment: fragment, isNative: isNative, isFavorite: isFavorite);

void main() {
  final catalog = assembleCatalog(Directory('catalog'));
  final removedIds = {
    for (final MapEntry(:key, :value) in (jsonDecode(File('assets/catalog/legacy_codes.json').readAsStringSync()) as Map<String, dynamic>).entries)
      key: (value as Map<String, dynamic>).cast<String, String>(),
  };
  late LibraryStore store;

  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  setUp(() async {
    // SharedPreferencesService keeps its SharedPreferences instance: clear it
    // through the service so no state leaks between tests.
    final prefs = (await SharedPreferencesService.getInstance())!;
    await prefs.preferences!.clear();
    store = LibraryStore(prefs);
  });

  test('redirectFavorites moves favorites of removed codes, once each', () async {
    await store.writeFavorites(['a.old', 'a.kept', 'a.other-old']);

    expect(await store.redirectFavorites({'a.old': 'a.new', 'a.other-old': 'a.new'}), isTrue);
    expect(store.readFavorites(), ['a.new', 'a.kept']);
    expect(await store.redirectFavorites({'a.old': 'a.new'}), isFalse);
  });

  group('importLegacy', () {
    test('maps legacy favorites to catalog ids, by label then by code', () async {
      await store.importLegacy(
        (
          codes: [
            // Relabelled since: matched by code.
            _row('Solde MTN', '*124#', 'bnMtn'),
            _row('Rechargement de compte', '*188*{voucher}#', 'cmOrange'),
            // Device code, listed with its brand prefix in the legacy app.
            _row('SAMSUNG - Test du micro', '*#0283#', 'utilities'),
            // Removed codes follow their redirect: an expired Etisalat (now
            // 9mobile) bundle to the data plans, a bonus check to the data
            // balance (code typo'd label, matched by code).
            _row('Daily Plan 10MB/24H/N100 ', '*229*3*1#', 'ngEtisalat'),
            _row('Consulttion de bonus data', '#145#', 'cmOrange'),
          ],
          country: null,
        ),
        catalog,
        removedIds: removedIds,
      );

      expect(store.readFavorites(), [
        'bj-mtn.solde-mtn',
        'cm-orange.rechargement-de-compte',
        'device.samsung-test-du-micro',
        'ng-9mobile.forfaits-internet',
        'cm-orange.solde-internet',
      ]);
    });

    test('keeps personal codes, with their favorite state', () async {
      await store.importLegacy((
        codes: [
          _row('Mon forfait', '*130 *1#', 'bnMtn', isNative: false),
          _row('Autre', '*100#', 'tgMoov', isNative: false, isFavorite: false),
        ],
        country: null,
      ), catalog);

      final custom = store.readCustomCodes();
      expect(custom.map((c) => (c.operatorId, c.label, c.code)), [
        ('bj-mtn', 'Mon forfait', '*130*1#'),
        ('tg-moov', 'Autre', '*100#'),
      ]);
      expect(store.readFavorites(), [custom.first.id]);
    });

    test('returns the legacy default country with its ISO id', () async {
      expect(await store.importLegacy((codes: const <LegacyCode>[], country: 'ma'), catalog), 'ml');
    });

    test('runs only once', () async {
      await store.importLegacy(null, catalog);
      expect(store.legacyImported, isTrue);

      await store.importLegacy((codes: [_row('Solde MTN', '*124#', 'bnMtn')], country: 'bn'), catalog);
      expect(store.readFavorites(), isEmpty);
    });
  });

  test('every legacy list maps to an operator of the catalog', () {
    for (final operatorId in LibraryStore.legacyFragments.values) {
      expect(catalog.operatorById(operatorId), isNotNull, reason: operatorId);
    }
    for (final countryId in LibraryStore.legacyCountries.values) {
      expect(catalog.countryById(countryId), isNotNull, reason: countryId);
    }
  });
}
