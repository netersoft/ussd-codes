import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_codes/core/catalog/models.dart';
import 'package:ussd_codes/core/catalog/site.dart';
import 'package:ussd_codes/core/catalog/sources.dart';

void main() {
  final catalog = assembleCatalog(Directory('catalog'));
  final site = buildSite(catalog);

  test('has a page per country and per operator, plus the phone codes', () {
    for (final country in catalog.countries) {
      expect(site, contains('${country.id}/index.html'));
    }
    expect(site, contains('bj/mtn/index.html'));
    expect(site, contains('ng/9mobile/index.html'));
    expect(site, contains('telephone/index.html'));
    expect(site.keys.where((path) => path.endsWith('index.html')), hasLength(2 + catalog.countries.length + catalog.operators.length));
  });

  test('lists every code of an operator, with readable placeholders', () {
    final page = site['bj/mtn/index.html']!;
    final mtn = catalog.operatorById('bj-mtn')!;
    expect(RegExp('<code>').allMatches(page), hasLength(mtn.codes.length));
    expect(page, contains('<code>*133*77*‹montant›#</code>'));
    expect(page, isNot(contains('{amount}')));
  });

  test('writes Nigeria in English and the other countries in French', () {
    expect(site['ng/mtn/index.html'], contains('<html lang="en">'));
    expect(site['ng/mtn/index.html'], contains('Data plans'));
    expect(site['bj/mtn/index.html'], contains('<html lang="fr">'));
    expect(site['ci/orange/index.html'], contains("en Côte d'Ivoire"));
  });

  test('names rebranded operators by both names', () {
    expect(site['tg/index.html'], contains('(anciennement Togocel)'));
    expect(site['tg/togocel/index.html'], contains('Yas, anciennement Togocel.'));
  });

  test('escapes catalog text', () {
    final tricky = Catalog(
      version: 1,
      updatedAt: '2026-10-06',
      countries: [
        const Country(
          id: 'bj',
          name: LocalizedText({'fr': 'Bénin'}),
          operators: [
            Operator(
              id: 'bj-test',
              countryId: 'bj',
              name: 'A&B',
              codes: [
                UssdCode(id: 'bj-test.x', label: LocalizedText({'fr': 'Solde <b>'}), code: '*1#', category: CodeCategory.account),
              ],
            ),
          ],
        ),
      ],
      deviceCodes: const [],
    );
    final page = buildSite(tricky)['bj/test/index.html']!;
    expect(page, contains('Solde &lt;b&gt;'));
    expect(page, contains('A&amp;B'));
    expect(page, isNot(contains('<b>')));
  });

  test('the sitemap lists every page', () {
    final sitemap = site['sitemap.xml']!;
    final pages = site.keys.where((path) => path.endsWith('index.html'));
    expect(RegExp('<loc>').allMatches(sitemap), hasLength(pages.length));
    expect(sitemap, contains('<loc>$siteBaseUrl/bj/mtn/</loc>'));
  });

  test('owns only the country and phone directories', () {
    expect(isGeneratedDirectory('bj'), isTrue);
    expect(isGeneratedDirectory('telephone'), isTrue);
    expect(isGeneratedDirectory('privacy'), isFalse);
  });
}
