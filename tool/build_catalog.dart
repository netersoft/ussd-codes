// Validates the catalog sources (catalog/) and builds the file the app bundles
// and downloads (assets/catalog/catalog.json).
//
//   dart run tool/build_catalog.dart          # build
//   dart run tool/build_catalog.dart --check  # fail if the built file is stale

import 'dart:io';

import 'package:ussd_codes/core/catalog/models.dart';
import 'package:ussd_codes/core/catalog/sources.dart';

void main(List<String> args) {
  final catalog = assembleCatalog(Directory('catalog'));

  final errors = catalog.validate();
  if (errors.isNotEmpty) {
    stderr.writeln('Invalid catalog:\n${errors.map((e) => '  - $e').join('\n')}');
    exit(1);
  }

  // Prices go stale: a reminder to check them again (the app shows them as
  // "to confirm", then hides them).
  final now = DateTime.now();
  final stale = [
    for (final op in catalog.operators)
      if (op.plans.where((plan) => plan.freshness(now) != PlanFreshness.fresh).length case final count when count > 0) '${op.id} ($count)',
  ];
  if (stale.isNotEmpty) {
    stderr.writeln('Warning: plans checked more than ${DataPlan.staleAfter.inDays} days ago: ${stale.join(', ')}. Check them on plansSource.');
  }

  final output = File(builtCatalogPath);
  final content = encodeCatalog(catalog);

  if (args.contains('--check')) {
    if (!output.existsSync() || output.readAsStringSync() != content) {
      stderr.writeln('$builtCatalogPath is out of date: run `dart run tool/build_catalog.dart`.');
      exit(1);
    }
    stdout.writeln('$builtCatalogPath is up to date.');
    return;
  }

  output
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  final codes = catalog.operators.fold(0, (sum, op) => sum + op.codes.length);
  stdout.writeln(
    'Built $builtCatalogPath: catalog v${catalog.version}, ${catalog.countries.length} countries, '
    '${catalog.operators.length} operators, $codes operator codes, ${catalog.deviceCodes.length} device codes, '
    '${catalog.operators.fold(0, (sum, op) => sum + op.plans.length)} plans.',
  );
}
