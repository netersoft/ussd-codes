import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_codes/core/catalog/models.dart';
import 'package:ussd_codes/core/catalog/site.dart';
import 'package:ussd_codes/core/catalog/sources.dart';

void main() {
  final catalog = assembleCatalog(Directory('catalog'));
  // The bundles in the catalog were checked on 2026-10-06.
  final site = buildSite(catalog, now: DateTime(2026, 10, 20));

  test('has a page per country and per operator, plus the phone codes', () {
    for (final country in catalog.countries) {
      expect(site, contains('${country.id}/index.html'));
    }
    expect(site, contains('bj/mtn/index.html'));
    expect(site, contains('ng/9mobile/index.html'));
    expect(site, contains('telephone/index.html'));
    const plansPages = 3; // Bénin, Togo, Côte d'Ivoire
    expect(site.keys.where((path) => path.endsWith('index.html')), hasLength(2 + catalog.countries.length + catalog.operators.length + plansPages));
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

  group('bundle comparison', () {
    test('has a page for the countries with prices, linked from the country page', () {
      for (final country in ['bj', 'tg', 'ci']) {
        expect(site, contains('$country/forfaits/index.html'));
        expect(site['$country/index.html'], contains('$siteBaseUrl/$country/forfaits/'));
      }
      expect(site, isNot(contains('sn/forfaits/index.html')));
      expect(site['sitemap.xml'], contains('<loc>$siteBaseUrl/tg/forfaits/</loc>'));
    });

    test('lists the cheapest per GB first, with the price and purchase code', () {
      final page = site['tg/forfaits/index.html']!;
      final daily = page.substring(page.indexOf('À la journée'));
      // Yas Net599: 5 GB for 599 F.
      expect(daily.indexOf('5 Go · 24 h'), lessThan(daily.indexOf('45 Mo · 24 h')));
      expect(page, contains('599 F</strong> <code>*909*241#</code>'));
      expect(page, contains('15\u202f000 F'));
    });

    test('flags old prices, then drops them', () {
      expect(buildSite(catalog, now: DateTime(2027, 2))['bj/forfaits/index.html'], contains('prix à confirmer'));
      expect(buildSite(catalog, now: DateTime(2027, 6)), isNot(contains('bj/forfaits/index.html')));
    });
  });
}
