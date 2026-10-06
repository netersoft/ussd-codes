import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_codes/core/catalog/models.dart';
import 'package:ussd_codes/core/providers/catalog_provider.dart';
import 'package:ussd_codes/core/providers/library_provider.dart';
import 'package:ussd_codes/core/services/shared_preferences/keys.dart';
import 'package:ussd_codes/core/services/shared_preferences/service.dart';

import '../helpers/app_harness.dart';
import '../helpers/test_utils.dart';

Country _country(String id) => Country(id: id, name: LocalizedText({'fr': id}), operators: const []);

final _catalog = Catalog(version: 1, updatedAt: '2026-10-06', countries: [_country('bj'), _country('tg')], deviceCodes: const []);

void main() {
  late SharedPreferencesService prefs;
  late FakeTelephonyService telephony;
  late ProviderContainer container;

  setUp(() async {
    prefs = await setupTestPreferences();
    telephony = FakeTelephonyService();
    container = ProviderContainer(overrides: [telephonyServiceProvider.overrideWithValue(telephony)]);
  });

  tearDown(() {
    container.dispose();
    teardownTestLocator();
  });

  Future<Country?> followNetwork(List<String> networks) {
    telephony.networkCountryIds = networks;
    return container.read(selectedCountryProvider.notifier).followNetwork(_catalog);
  }

  String? selected() => container.read(selectedCountryProvider);

  test('selects the country the phone is in, silently the first time', () async {
    expect(await followNetwork(['tg']), isNull);
    expect(selected(), 'tg');
    expect(prefs.getString(PrefKeys.selectedCountry), 'tg');
  });

  test('switches when the user travels, and says so', () async {
    await followNetwork(['bj']);

    final switched = await followNetwork(['tg']);

    expect(switched?.id, 'tg');
    expect(selected(), 'tg');
  });

  test('keeps a country picked by hand while the user stays in the same country', () async {
    await followNetwork(['bj']);
    await container.read(selectedCountryProvider.notifier).select('tg');

    expect(await followNetwork(['bj']), isNull);
    expect(selected(), 'tg');
  });

  test('replaces the country saved by the legacy app', () async {
    await container.read(selectedCountryProvider.notifier).select('bj');

    expect((await followNetwork(['tg']))?.id, 'tg');
  });

  test('ignores countries missing from the catalog and the lack of signal', () async {
    await container.read(selectedCountryProvider.notifier).select('bj');

    expect(await followNetwork(['fr']), isNull);
    expect(await followNetwork([]), isNull);
    expect(selected(), 'bj');
  });

  test('uses the first network the catalog has (dual SIM)', () async {
    await followNetwork(['fr', 'tg', 'bj']);
    expect(selected(), 'tg');
  });
}
