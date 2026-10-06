// Pure Dart (no Flutter import): `tool/build_catalog.dart` uses these models
// to validate and assemble the catalog outside of the app.

import 'package:collection/collection.dart';

/// A text available in one or more languages, e.g. `{"fr": "Solde"}`.
class LocalizedText {
  final Map<String, String> values;

  const LocalizedText(this.values);

  factory LocalizedText.fromJson(Object? json) => switch (json) {
    final String text => LocalizedText({'fr': text}),
    final Map<String, dynamic> map => LocalizedText(map.map((key, value) => MapEntry(key, value as String))),
    _ => throw FormatException('Invalid localized text: $json'),
  };

  /// The text in [languageCode], falling back to French, English, then any
  /// available language: most codes are only described in the operator's
  /// language.
  String resolve(String languageCode) => values[languageCode] ?? values['fr'] ?? values['en'] ?? values.values.first;

  Map<String, String> toJson() => values;
}

enum ParamType {
  /// An amount of money (digits).
  amount,

  /// A phone number (digits).
  phone,

  /// A PIN or secret code: never stored, masked on screen.
  pin,

  /// Any other numeric value (voucher, merchant code, position...).
  number,
}

class UssdParam {
  final String key;
  final ParamType type;
  final LocalizedText label;

  const UssdParam({required this.key, required this.type, required this.label});

  factory UssdParam.fromJson(Map<String, dynamic> json) => UssdParam(
    key: json['key'] as String,
    type: ParamType.values.byName(json['type'] as String),
    label: LocalizedText.fromJson(json['label']),
  );

  bool get isSecret => type == ParamType.pin;

  Map<String, dynamic> toJson() => {'key': key, 'type': type.name, 'label': label.toJson()};
}

/// Display order of the categories in an operator's list.
enum CodeCategory { account, recharge, data, transfer, money, help, services, device }

class UssdCode {
  /// Stable identifier (`<operator id>.<slug>`): favorites refer to it, so it
  /// must never change once published.
  final String id;
  final LocalizedText label;

  /// The code to dial, with `{key}` placeholders for [params].
  final String code;
  final CodeCategory category;
  final List<UssdParam> params;

  /// For device codes, the manufacturer they are specific to (lowercase).
  final String? brand;

  const UssdCode({
    required this.id,
    required this.label,
    required this.code,
    required this.category,
    this.params = const [],
    this.brand,
  });

  factory UssdCode.fromJson(Map<String, dynamic> json) => UssdCode(
    id: json['id'] as String,
    label: LocalizedText.fromJson(json['label']),
    code: json['code'] as String,
    category: CodeCategory.values.byName(json['category'] as String),
    params: [for (final param in (json['params'] as List<dynamic>? ?? const [])) UssdParam.fromJson(param as Map<String, dynamic>)],
    brand: json['brand'] as String?,
  );

  static final placeholderPattern = RegExp(r'\{([a-z][a-z0-9_]*)\}');

  /// Characters a dialable code may contain once its placeholders are filled.
  static final dialablePattern = RegExp(r'^[0-9*#+]+$');

  bool get hasParams => params.isNotEmpty;

  /// Device (MMI) codes are handled by the phone itself, not the operator.
  bool get isDeviceCode => category == CodeCategory.device;

  List<String> get placeholders => [for (final match in placeholderPattern.allMatches(code)) match.group(1)!];

  /// The code with each placeholder replaced by its value, positionally: a
  /// value can never be confused with another param, unlike the legacy
  /// label-based `String.replace`.
  String fill(Map<String, String> values) => code.replaceAllMapped(placeholderPattern, (match) {
    final value = values[match.group(1)!];
    if (value == null || value.isEmpty) {
      throw ArgumentError.value(values, 'values', 'Missing value for {${match.group(1)}}');
    }
    return value;
  });

  /// The code as shown on screen: secret values are masked, missing values
  /// are shown with [placeholder].
  String preview(Map<String, String> values, {required String Function(UssdParam param) placeholder}) => code.replaceAllMapped(placeholderPattern, (match) {
    final param = params.firstWhereOrNull((p) => p.key == match.group(1));
    final value = values[match.group(1)!] ?? '';
    if (param == null) return match.group(0)!;
    if (value.isEmpty) return placeholder(param);
    return param.isSecret ? '•' * value.length : value;
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label.toJson(),
    'code': code,
    'category': category.name,
    if (params.isNotEmpty) 'params': [for (final param in params) param.toJson()],
    if (brand != null) 'brand': brand,
  };
}

class Operator {
  final String id;
  final String countryId;
  final String name;

  /// Name before a rebranding (e.g. 9mobile, formerly Etisalat), so users can
  /// still find it.
  final String? formerName;

  /// MCC+MNC of the operator's SIM cards, used to detect the user's operator.
  final List<String> mccMnc;
  final List<UssdCode> codes;

  const Operator({
    required this.id,
    required this.countryId,
    required this.name,
    required this.codes,
    this.formerName,
    this.mccMnc = const [],
  });

  factory Operator.fromJson(Map<String, dynamic> json, {String? countryId}) => Operator(
    id: json['id'] as String,
    countryId: countryId ?? json['country'] as String,
    name: json['name'] as String,
    formerName: json['formerName'] as String?,
    mccMnc: [for (final value in (json['mccMnc'] as List<dynamic>? ?? const [])) value as String],
    codes: [for (final code in json['codes'] as List<dynamic>) UssdCode.fromJson(code as Map<String, dynamic>)],
  );

  String get displayName => formerName == null ? name : '$name (ex-$formerName)';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (formerName != null) 'formerName': formerName,
    'mccMnc': mccMnc,
    'codes': [for (final code in codes) code.toJson()],
  };
}

class Country {
  /// ISO 3166-1 alpha-2 code, lowercase.
  final String id;
  final LocalizedText name;
  final List<Operator> operators;

  const Country({required this.id, required this.name, required this.operators});

  factory Country.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return Country(
      id: id,
      name: LocalizedText.fromJson(json['name']),
      operators: [for (final op in json['operators'] as List<dynamic>) Operator.fromJson(op as Map<String, dynamic>, countryId: id)],
    );
  }

  /// The country's flag emoji, built from its ISO code.
  String get flag => String.fromCharCodes(id.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41));

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.toJson(),
    'operators': [for (final op in operators) op.toJson()],
  };
}

/// A code with the operator it belongs to (null for device codes).
typedef CodeEntry = ({UssdCode code, Operator? operator});

class Catalog {
  /// Highest catalog format this app version understands: a remote catalog
  /// with a newer format is ignored until the app is updated.
  static const supportedSchemaVersion = 1;

  final int schemaVersion;

  /// Data revision, bumped on every change so the app knows a remote catalog
  /// is newer than the one it has.
  final int version;
  final String updatedAt;
  final List<Country> countries;
  final List<UssdCode> deviceCodes;

  Catalog({
    required this.version,
    required this.updatedAt,
    required this.countries,
    required this.deviceCodes,
    this.schemaVersion = supportedSchemaVersion,
  });

  factory Catalog.fromJson(Map<String, dynamic> json) => Catalog(
    schemaVersion: json['schemaVersion'] as int,
    version: json['version'] as int,
    updatedAt: json['updatedAt'] as String,
    countries: [for (final country in json['countries'] as List<dynamic>) Country.fromJson(country as Map<String, dynamic>)],
    deviceCodes: [for (final code in json['deviceCodes'] as List<dynamic>) UssdCode.fromJson(code as Map<String, dynamic>)],
  );

  Iterable<Operator> get operators => countries.expand((country) => country.operators);

  late final Map<String, CodeEntry> _codesById = {
    for (final op in operators)
      for (final code in op.codes) code.id: (code: code, operator: op),
    for (final code in deviceCodes) code.id: (code: code, operator: null),
  };

  Iterable<CodeEntry> get entries => _codesById.values;

  CodeEntry? entryById(String id) => _codesById[id];

  Country? countryById(String? id) => countries.firstWhereOrNull((country) => country.id == id);

  Operator? operatorById(String? id) => operators.firstWhereOrNull((op) => op.id == id);

  Operator? operatorByMccMnc(String mccMnc) => operators.firstWhereOrNull((op) => op.mccMnc.contains(mccMnc));

  /// Problems that make the catalog unsafe to publish: duplicate ids, codes
  /// that can't be dialed, placeholders without a param...
  List<String> validate() {
    final errors = <String>[];
    final ids = <String>{};

    void checkId(String id, String what) {
      if (!ids.add(id)) errors.add('Duplicate $what id: $id');
    }

    void checkCode(UssdCode code, String prefix) {
      checkId(code.id, 'code');
      if (!code.id.startsWith('$prefix.')) errors.add('${code.id}: id must start with "$prefix."');
      if (code.label.values.isEmpty || code.label.values.values.any((text) => text.trim().isEmpty)) {
        errors.add('${code.id}: empty label');
      }
      final placeholders = code.placeholders;
      final keys = code.params.map((param) => param.key).toList();
      if (!const ListEquality<String>().equals(placeholders, keys)) {
        errors.add('${code.id}: placeholders $placeholders do not match params $keys');
      }
      if (!UssdCode.dialablePattern.hasMatch(code.code.replaceAll(UssdCode.placeholderPattern, '0'))) {
        errors.add('${code.id}: "${code.code}" contains characters that cannot be dialed');
      }
    }

    if (schemaVersion != supportedSchemaVersion) errors.add('Unsupported schemaVersion $schemaVersion');
    for (final country in countries) {
      checkId(country.id, 'country');
      if (!RegExp(r'^[a-z]{2}$').hasMatch(country.id)) errors.add('${country.id}: country id must be an ISO 3166 alpha-2 code');
      for (final op in country.operators) {
        checkId(op.id, 'operator');
        if (!op.id.startsWith('${country.id}-')) errors.add('${op.id}: id must start with "${country.id}-"');
        for (final mccMnc in op.mccMnc) {
          if (!RegExp(r'^\d{5,6}$').hasMatch(mccMnc)) errors.add('${op.id}: invalid MCC/MNC $mccMnc');
        }
        for (final code in op.codes) {
          checkCode(code, op.id);
        }
      }
    }
    for (final code in deviceCodes) {
      checkCode(code, 'device');
    }
    return errors;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'version': version,
    'updatedAt': updatedAt,
    'countries': [for (final country in countries) country.toJson()],
    'deviceCodes': [for (final code in deviceCodes) code.toJson()],
  };
}
