import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../catalog/catalog_repository.dart';
import '../catalog/models.dart';
import '../services/di/locator.dart';
import '../services/shared_preferences/keys.dart';
import '../services/shared_preferences/service.dart';
import '../services/telephony/service.dart';

part 'catalog_provider.g.dart';

@Riverpod(keepAlive: true)
CatalogRepository catalogRepository(Ref ref) => CatalogRepository(remoteUrl: dotenv.maybeGet('APP_CATALOG_URL') ?? '');

@Riverpod(keepAlive: true)
TelephonyService telephonyService(Ref ref) => TelephonyService();

/// The catalog in use. Starts from the local copy, then looks for a newer
/// remote one in the background (at most every [_autoCheckInterval]).
@Riverpod(keepAlive: true)
class CurrentCatalog extends _$CurrentCatalog {
  static const _autoCheckInterval = Duration(hours: 12);

  SharedPreferencesService get _prefs => locator<SharedPreferencesService>();

  @override
  Future<Catalog> build() async {
    final catalog = await ref.watch(catalogRepositoryProvider).loadLocal();
    unawaited(Future.microtask(_autoUpdate));
    return catalog;
  }

  Future<void> _autoUpdate() async {
    final lastCheck = DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(PrefKeys.catalogLastCheck) ?? 0);
    if (DateTime.now().difference(lastCheck) < _autoCheckInterval) return;
    await checkForUpdate();
  }

  Future<CatalogUpdateResult> checkForUpdate() async {
    final current = await future;
    final (result, remote) = await ref.read(catalogRepositoryProvider).fetchRemote(current);
    if (result == CatalogUpdateResult.updated || result == CatalogUpdateResult.upToDate) {
      unawaited(_prefs.setInt(PrefKeys.catalogLastCheck, DateTime.now().millisecondsSinceEpoch));
    }
    if (remote != null) state = AsyncData(remote);
    return result;
  }
}

/// MCC+MNC of the phone's SIM cards (empty when unknown).
@Riverpod(keepAlive: true)
Future<List<String>> simOperators(Ref ref) => ref.watch(telephonyServiceProvider).simOperators();

/// The catalog operators matching the phone's SIM cards.
@riverpod
List<Operator> simCatalogOperators(Ref ref) {
  final catalog = ref.watch(currentCatalogProvider).value;
  final sims = ref.watch(simOperatorsProvider).value ?? const [];
  if (catalog == null) return const [];
  return <Operator>{
    for (final mccMnc in sims) ?catalog.operatorByMccMnc(mccMnc),
  }.toList();
}

/// The phone's manufacturer, lowercase ("samsung"...), to show the device
/// codes specific to it.
@Riverpod(keepAlive: true)
Future<String> deviceManufacturer(Ref ref) async {
  try {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => (await DeviceInfoPlugin().androidInfo).manufacturer.toLowerCase(),
      TargetPlatform.iOS => 'apple',
      _ => '',
    };
  } catch (_) {
    return '';
  }
}

/// Device codes that apply to this phone: generic ones and its brand's.
@riverpod
List<UssdCode> deviceCodes(Ref ref) {
  final catalog = ref.watch(currentCatalogProvider).value;
  final manufacturer = ref.watch(deviceManufacturerProvider).value ?? '';
  if (catalog == null) return const [];
  return [
    for (final code in catalog.deviceCodes)
      if (code.brand == null || manufacturer.contains(code.brand!)) code,
  ];
}
