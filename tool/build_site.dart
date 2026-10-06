// Generates the public site (https://netersoft.github.io/ussd-codes/) from
// `catalog/`, with the catalog the app downloads, into a netersoft.github.io
// checkout:
//
//   dart run tool/build_site.dart ../../../Web/netersoft.github.io
//
// Pages of removed countries or operators are deleted; the privacy policy
// pages are left alone. Publish the result through a pull request.

import 'dart:io';

import 'package:ussd_codes/core/catalog/site.dart';
import 'package:ussd_codes/core/catalog/sources.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/build_site.dart <netersoft.github.io checkout>');
    exit(64);
  }
  final root = Directory('${args.single}/ussd-codes');
  if (!root.existsSync()) {
    stderr.writeln('${root.path} not found: pass the netersoft.github.io checkout.');
    exit(66);
  }

  final catalog = assembleCatalog(Directory('catalog'));
  final errors = catalog.validate();
  if (errors.isNotEmpty) {
    stderr.writeln('Invalid catalog:\n${errors.join('\n')}');
    exit(1);
  }

  for (final dir in root.listSync().whereType<Directory>()) {
    if (isGeneratedDirectory(dir.uri.pathSegments.where((segment) => segment.isNotEmpty).last)) dir.deleteSync(recursive: true);
  }
  final pages = buildSite(catalog);
  for (final MapEntry(key: path, value: content) in pages.entries) {
    File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }
  File('${root.path}/catalog.json').writeAsStringSync(encodeCatalog(catalog));

  stdout.writeln('Wrote ${pages.length} files and catalog v${catalog.version} to ${root.path}.');
}
