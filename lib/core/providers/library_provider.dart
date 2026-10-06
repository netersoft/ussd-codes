import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../catalog/models.dart';
import '../library/library_store.dart';
import '../services/di/locator.dart';
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

/// Country picked by the user (null until they pick one).
@Riverpod(keepAlive: true)
class SelectedCountry extends _$SelectedCountry {
  SharedPreferencesService get _prefs => locator<SharedPreferencesService>();

  @override
  String? build() => _prefs.getString(PrefKeys.selectedCountry);

  Future<void> select(String countryId) async {
    state = countryId;
    await _prefs.setString(PrefKeys.selectedCountry, countryId);
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

@Riverpod(keepAlive: true)
ReviewPrompt reviewPrompt(Ref ref) => ReviewPrompt(locator<SharedPreferencesService>(), ref.watch(telephonyServiceProvider));

/// One-time work before the first screen: the catalog is loaded and what the
/// legacy app saved (favorites, personal codes, country) is imported. Also
/// counts the launch for the review prompt.
@Riverpod(keepAlive: true)
Future<void> appStartup(Ref ref) async {
  final catalog = await ref.read(currentCatalogProvider.future);
  unawaited(ref.read(reviewPromptProvider).onLaunch());
  final store = ref.read(libraryStoreProvider);
  if (store.legacyImported) return;

  final legacy = await ref.read(telephonyServiceProvider).readLegacyData();
  final country = await store.importLegacy(legacy, catalog);
  ref
    ..invalidate(favoritesProvider)
    ..invalidate(customCodesProvider);
  if (country != null && ref.read(selectedCountryProvider) == null) {
    await ref.read(selectedCountryProvider.notifier).select(country);
  }
}
