import 'dart:convert';

import '../catalog/models.dart';
import '../services/shared_preferences/keys.dart';
import '../services/shared_preferences/service.dart';
import '../services/telephony/service.dart';

/// A code the user added to an operator's list.
class CustomCode {
  final String id;
  final String operatorId;
  final String label;
  final String code;

  const CustomCode({required this.id, required this.operatorId, required this.label, required this.code});

  factory CustomCode.fromJson(Map<String, dynamic> json) => CustomCode(
    id: json['id'] as String,
    operatorId: json['operatorId'] as String,
    label: json['label'] as String,
    code: json['code'] as String,
  );

  static const idPrefix = 'custom.';

  static bool isCustomId(String id) => id.startsWith(idPrefix);

  /// The same code as a catalog one, so screens show both the same way.
  UssdCode toUssdCode() => UssdCode(
    id: id,
    label: LocalizedText({'fr': label, 'en': label}),
    code: code,
    category: CodeCategory.services,
  );

  Map<String, dynamic> toJson() => {'id': id, 'operatorId': operatorId, 'label': label, 'code': code};
}

/// The user's own data (favorites, personal codes), kept on the device only.
class LibraryStore {
  final SharedPreferencesService _prefs;

  LibraryStore(this._prefs);

  List<String> readFavorites() => _prefs.getListString(PrefKeys.favorites) ?? const [];

  Future<void> writeFavorites(List<String> ids) => _prefs.setStringList(PrefKeys.favorites, ids);

  List<CustomCode> readCustomCodes() {
    final raw = _prefs.getString(PrefKeys.customCodes);
    if (raw == null) return const [];
    return [for (final json in jsonDecode(raw) as List<dynamic>) CustomCode.fromJson(json as Map<String, dynamic>)];
  }

  Future<void> writeCustomCodes(List<CustomCode> codes) => _prefs.setString(PrefKeys.customCodes, jsonEncode([for (final code in codes) code.toJson()]));

  bool get legacyImported => _prefs.getBool(PrefKeys.legacyImported) ?? false;

  /// Brings in what the legacy app saved, once: personal codes, favorites
  /// (matched to the catalog by label, then by code) and the default country.
  /// Returns the legacy default country, mapped to the new country ids.
  Future<String?> importLegacy(LegacyData? data, Catalog catalog) async {
    if (legacyImported) return null;
    await _prefs.setBool(PrefKeys.legacyImported, true);
    if (data == null) return null;

    final favorites = [...readFavorites()];
    final customCodes = [...readCustomCodes()];

    for (final (index, row) in data.codes.indexed) {
      final operatorId = legacyFragments[row.fragment];

      if (!row.isNative) {
        if (operatorId == null || row.code.trim().isEmpty) continue;
        final custom = CustomCode(
          id: '${CustomCode.idPrefix}legacy-$index',
          operatorId: operatorId,
          label: row.description.trim(),
          code: row.code.replaceAll(RegExp(r'\s+'), ''),
        );
        customCodes.add(custom);
        if (row.isFavorite) favorites.add(custom.id);
        continue;
      }

      final candidates = row.fragment == 'utilities' ? catalog.deviceCodes : catalog.operatorById(operatorId)?.codes ?? const <UssdCode>[];
      final match = _matchLegacyCode(row, candidates);
      if (match != null && !favorites.contains(match.id)) favorites.add(match.id);
    }

    await writeCustomCodes(customCodes);
    await writeFavorites(favorites);
    return legacyCountries[data.country];
  }

  static UssdCode? _matchLegacyCode(LegacyCode row, List<UssdCode> candidates) {
    String normalize(String text) => text.replaceAll(RegExp('^(SAMSUNG|HTC) - '), '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

    final label = normalize(row.description);
    final code = row.code.replaceAll(RegExp(r'\s+'), '');
    for (final candidate in candidates) {
      if (candidate.label.values.values.any((text) => normalize(text) == label)) return candidate;
    }
    for (final candidate in candidates) {
      if (candidate.code == code) return candidate;
    }
    return null;
  }

  /// Legacy list ids ("fragments") to operator ids.
  static const legacyFragments = {
    'bnMoov': 'bj-moov',
    'bnMtn': 'bj-mtn',
    'niMoov': 'ne-moov',
    'niOrange': 'ne-orange',
    'maOrange': 'ml-orange',
    'ciMoov': 'ci-moov',
    'ciMtn': 'ci-mtn',
    'ngAirtel': 'ng-airtel',
    'ngEtisalat': 'ng-9mobile',
    'ngGlo': 'ng-glo',
    'ngMtn': 'ng-mtn',
    'snOrange': 'sn-orange',
    'cmOrange': 'cm-orange',
    'tgMoov': 'tg-moov',
    'tgTogocel': 'tg-togocel',
  };

  /// Legacy country codes (not ISO for Benin, Mali and Niger) to country ids.
  static const legacyCountries = {
    'bn': 'bj',
    'cm': 'cm',
    'ci': 'ci',
    'ma': 'ml',
    'ni': 'ne',
    'ng': 'ng',
    'sn': 'sn',
    'tg': 'tg',
  };
}
