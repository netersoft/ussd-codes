import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../catalog/models.dart';
import '../helpers/logging/log_helper.dart';
import '../library/library_store.dart';
import '../services/di/locator.dart';
import '../services/i18n/translations.g.dart';
import '../services/review/service.dart';
import '../services/shared_preferences/keys.dart';
import '../services/shared_preferences/service.dart';
import 'catalog_provider.dart';

part 'library_provider.g.dart';

@Riverpod(keepAlive: true)
LibraryStore libraryStore(Ref ref) => LibraryStore(locator<SharedPreferencesService>());

/// Ids of the favorite codes, catalog or personal, most recent last.
@Riverpod(keepAlive: true)
class Favorites extends _$Favorites {
  @override
  List<String> build() => ref.watch(libraryStoreProvider).readFavorites();

  Future<void> toggle(String id) async {
    state = state.contains(id) ? [...state.where((other) => other != id)] : [...state, id];
    await ref.read(libraryStoreProvider).writeFavorites(state);
  }

  Future<void> remove(String id) async {
    if (!state.contains(id)) return;
    await toggle(id);
  }

  /// Follows the catalog's redirects for favorites of removed codes.
  Future<void> followRedirects(Catalog catalog) async {
    if (await ref.read(libraryStoreProvider).redirectFavorites(catalog.redirects)) ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
class CustomCodes extends _$CustomCodes {
  @override
  List<CustomCode> build() => ref.watch(libraryStoreProvider).readCustomCodes();

  Future<CustomCode> add({required String operatorId, required String label, required String code}) async {
    final custom = CustomCode(
      id: '${CustomCode.idPrefix}${DateTime.now().microsecondsSinceEpoch}',
      operatorId: operatorId,
      label: label.trim(),
      code: code.replaceAll(RegExp(r'\s+'), ''),
    );
    state = [...state, custom];
    await ref.read(libraryStoreProvider).writeCustomCodes(state);
    return custom;
  }

  Future<void> remove(String id) async {
    state = [...state.where((custom) => custom.id != id)];
    await ref.read(libraryStoreProvider).writeCustomCodes(state);
    await ref.read(favoritesProvider.notifier).remove(id);
  }
}

/// A code ready to show: catalog or personal, with its operator.
typedef ResolvedCode = ({UssdCode code, Operator? operator, bool isCustom});

/// Finds a code by id among the catalog and the personal codes.
@riverpod
ResolvedCode? resolvedCode(Ref ref, String id) {
  if (CustomCode.isCustomId(id)) {
    final custom = ref.watch(customCodesProvider).where((custom) => custom.id == id).firstOrNull;
    if (custom == null) return null;
    final operator = ref.watch(currentCatalogProvider).value?.operatorById(custom.operatorId);
    return (code: custom.toUssdCode(), operator: operator, isCustom: true);
  }
  final entry = ref.watch(currentCatalogProvider).value?.entryById(id);
  if (entry == null) return null;
  return (code: entry.code, operator: entry.operator, isCustom: false);
}

/// Country whose codes are shown: the one the phone is in, or the one the
/// user picked (null until either is known).
@Riverpod(keepAlive: true)
class SelectedCountry extends _$SelectedCountry {
  SharedPreferencesService get _prefs => locator<SharedPreferencesService>();

  @override
  String? build() => _prefs.getString(PrefKeys.selectedCountry);

  Future<void> select(String countryId) async {
    state = countryId;
    await _prefs.setString(PrefKeys.selectedCountry, countryId);
  }

  /// Switches to the country of the network the phone is on, when the
  /// catalog has it and it changed since the last detection: a country
  /// picked by hand stays until the user moves. Returns the new country when
  /// it replaced another one, for the UI to say so.
  Future<Country?> followNetwork(Catalog catalog) async {
    final networks = await ref.read(telephonyServiceProvider).networkCountries();
    final detected = networks.map(catalog.countryById).nonNulls.firstOrNull;
    if (detected == null || detected.id == _prefs.getString(PrefKeys.detectedCountry)) return null;

    await _prefs.setString(PrefKeys.detectedCountry, detected.id);
    final previous = state;
    if (previous == detected.id) return null;
    await select(detected.id);
    return previous == null ? null : detected;
  }
}

/// Run codes directly (Android, phone permission) rather than opening the
/// dialer with the code typed in.
@Riverpod(keepAlive: true)
class DirectCall extends _$DirectCall {
  SharedPreferencesService get _prefs => locator<SharedPreferencesService>();

  @override
  bool build() => _prefs.getBool(PrefKeys.directCall) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setBool(PrefKeys.directCall, value);
  }
}

/// Keeps the app icon's shortcuts (long press) on the latest favorites.
@Riverpod(keepAlive: true)
void favoriteShortcuts(Ref ref) {
  final shortcuts = [
    for (final id in ref.watch(favoritesProvider).reversed)
      if (ref.watch(resolvedCodeProvider(id)) case final entry?) (id: id, label: entry.code.label.resolve(LocaleSettings.instance.currentLocale.languageCode)),
  ].take(4).toList();
  unawaited(ref.read(telephonyServiceProvider).setShortcuts(shortcuts));
}

@Riverpod(keepAlive: true)
ReviewPrompt reviewPrompt(Ref ref) => ReviewPrompt(locator<SharedPreferencesService>(), ref.watch(telephonyServiceProvider));

/// One-time work before the first screen: the catalog is loaded, what the
/// legacy app saved (favorites, personal codes, country) is imported and the
/// country the phone is in is selected. Also counts the launch for the
/// review prompt. Returns the country selected in place of another one.
@Riverpod(keepAlive: true)
Future<Country?> appStartup(Ref ref) async {
  final catalog = await ref.read(currentCatalogProvider.future);
  unawaited(ref.read(reviewPromptProvider).onLaunch());
  await _importLegacy(ref, catalog);
  await ref.read(favoritesProvider.notifier).followRedirects(catalog);
  ref.listen(currentCatalogProvider, (_, next) {
    if (next.value case final updated?) unawaited(ref.read(favoritesProvider.notifier).followRedirects(updated));
  });
  return ref.read(selectedCountryProvider.notifier).followNetwork(catalog);
}

Future<void> _importLegacy(Ref ref, Catalog catalog) async {
  final store = ref.read(libraryStoreProvider);
  if (store.legacyImported) return;

  final legacy = await ref.read(telephonyServiceProvider).readLegacyData();
  final country = await store.importLegacy(legacy, catalog, removedIds: legacy == null ? const {} : await _removedLegacyIds());
  ref
    ..invalidate(favoritesProvider)
    ..invalidate(customCodesProvider);
  if (country != null && ref.read(selectedCountryProvider) == null) {
    await ref.read(selectedCountryProvider.notifier).select(country);
  }
}

/// Codes of the legacy app since removed from the catalog, to carry their
/// favorites over to the codes replacing them.
Future<Map<String, Map<String, String>>> _removedLegacyIds() async {
  try {
    final json = jsonDecode(await rootBundle.loadString('assets/catalog/legacy_codes.json')) as Map<String, dynamic>;
    return {for (final MapEntry(:key, :value) in json.entries) key: (value as Map<String, dynamic>).cast<String, String>()};
  } on Exception catch (e) {
    LogHelper.w('Unable to read the removed legacy codes', error: e);
    return const {};
  }
}
