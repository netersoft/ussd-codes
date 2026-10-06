// Pure Dart: used by `tool/build_catalog.dart` and the catalog tests, never by
// the app itself (which only reads the built `assets/catalog/catalog.json`).

import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Where the app bundles the built catalog, relative to the project root.
const builtCatalogPath = 'assets/catalog/catalog.json';

/// Assembles the catalog sources of [dir] (`catalog/`): `meta.json`,
/// `countries.json`, one `operators/<id>.json` per operator and `device.json`.
Catalog assembleCatalog(Directory dir) {
  Map<String, dynamic> read(String path) => jsonDecode(File('${dir.path}/$path').readAsStringSync()) as Map<String, dynamic>;

  final meta = read('meta.json');
  final countries = [
    for (final country in read('countries.json')['countries'] as List<dynamic>)
      Country(
        id: country['id'] as String,
        name: LocalizedText.fromJson(country['name']),
        operators: [
          for (final opId in country['operators'] as List<dynamic>) _readOperator(read('operators/$opId.json'), opId as String, country['id'] as String),
        ],
        dialCode: country['dialCode'] as String?,
        trunkPrefix: country['trunkPrefix'] as String? ?? '',
      ),
  ];

  final referenced = {for (final country in countries) ...country.operators.map((op) => '${op.id}.json')};
  final orphans = Directory('${dir.path}/operators').listSync().map((file) => file.uri.pathSegments.last).where((name) => !referenced.contains(name));
  if (orphans.isNotEmpty) {
    throw FormatException('Operator files not listed in countries.json: ${orphans.join(', ')}');
  }

  return Catalog(
    version: meta['version'] as int,
    updatedAt: meta['updatedAt'] as String,
    countries: countries,
    deviceCodes: [for (final code in read('device.json')['codes'] as List<dynamic>) UssdCode.fromJson(code as Map<String, dynamic>)],
  );
}

Operator _readOperator(Map<String, dynamic> json, String expectedId, String countryId) {
  final op = Operator.fromJson(json);
  if (op.id != expectedId || op.countryId != countryId) {
    throw FormatException('operators/$expectedId.json declares id "${op.id}" in country "${op.countryId}"');
  }
  return op;
}

/// The built catalog file content: compact, since the app downloads it.
String encodeCatalog(Catalog catalog) => '${jsonEncode(catalog.toJson())}\n';
