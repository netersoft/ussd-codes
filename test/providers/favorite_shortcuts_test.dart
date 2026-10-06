import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_codes/core/catalog/catalog_repository.dart';
import 'package:ussd_codes/core/providers/catalog_provider.dart';
import 'package:ussd_codes/core/providers/library_provider.dart';

import '../helpers/app_harness.dart';
import '../helpers/test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTelephonyService telephony;
  late ProviderContainer container;

  setUp(() async {
    await setupTestPreferences();
    telephony = FakeTelephonyService();
    final cacheDir = Directory.systemTemp.createTempSync('catalog_cache');
    addTearDown(() => cacheDir.deleteSync(recursive: true));
    container = ProviderContainer(
      overrides: [
        telephonyServiceProvider.overrideWithValue(telephony),
        catalogRepositoryProvider.overrideWithValue(CatalogRepository(remoteUrl: '', cacheDir: () async => cacheDir)),
      ],
    );
    await container.read(currentCatalogProvider.future);
    container
      ..listen(favoriteShortcutsProvider, (_, _) {}, fireImmediately: true)
      ..listen(quickSettingsTileProvider, (_, _) {}, fireImmediately: true);
  });

  tearDown(() {
    container.dispose();
    teardownTestLocator();
  });

  Future<void> favorite(String id) async {
    await container.read(favoritesProvider.notifier).toggle(id);
    await container.pump();
  }

  test('the app icon offers the latest favorites, newest first', () async {
    for (final id in ['bj-mtn.solde-mtn', 'bj-moov.solde', 'tg-moov.solde', 'ci-mtn.solde-du-compte', 'sn-orange.orange-money']) {
      await favorite(id);
    }

    expect(telephony.shortcuts.map((shortcut) => shortcut.id), [
      'sn-orange.orange-money',
      'ci-mtn.solde-du-compte',
      'tg-moov.solde',
      'bj-moov.solde',
    ]);
    expect(telephony.shortcuts.first.label, 'Orange Money');
  });

  test('a removed favorite leaves the shortcuts', () async {
    await favorite('bj-mtn.solde-mtn');
    await favorite('bj-mtn.solde-mtn');

    expect(telephony.shortcuts, isEmpty);
  });

  group('Quick Settings tile', () {
    test('opens the latest favorite by default', () async {
      expect(telephony.tileCode, isNull);

      await favorite('bj-mtn.solde-mtn');
      await favorite('bj-mtn.mtn-bip-me');

      expect(telephony.tileCode?.id, 'bj-mtn.mtn-bip-me');
      // Placeholders are left for the run sheet.
      expect(telephony.tileCode?.code, '*151*…#');
    });

    test('opens the favorite picked in the settings, until it stops being one', () async {
      await favorite('bj-mtn.solde-mtn');
      await favorite('bj-mtn.mtn-bip-me');
      await container.read(tileCodeChoiceProvider.notifier).set('bj-mtn.solde-mtn');
      await container.pump();

      expect(telephony.tileCode?.id, 'bj-mtn.solde-mtn');

      await favorite('bj-mtn.solde-mtn');
      expect(telephony.tileCode?.id, 'bj-mtn.mtn-bip-me');
    });
  });
}
