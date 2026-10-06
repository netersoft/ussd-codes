import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_codes/core/catalog/sources.dart';

/// Guards the catalog data itself: what contributors edit in catalog/.
void main() {
  final catalog = assembleCatalog(Directory('catalog'));

  test('the catalog sources are valid', () {
    expect(catalog.validate(), isEmpty);
  });

  test('the bundled catalog is built from the current sources', () {
    expect(
      File(builtCatalogPath).readAsStringSync(),
      encodeCatalog(catalog),
      reason: 'Run `dart run tool/build_catalog.dart` after editing catalog/.',
    );
  });

  test('every operator has codes and a known MCC/MNC', () {
    for (final op in catalog.operators) {
      expect(op.codes, isNotEmpty, reason: op.id);
      expect(op.mccMnc, isNotEmpty, reason: op.id);
    }
  });

  test('no two operators share an MCC/MNC', () {
    final all = [for (final op in catalog.operators) ...op.mccMnc];
    expect(all.toSet().length, all.length);
  });
}
