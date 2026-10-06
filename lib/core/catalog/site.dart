// Pure Dart: used by `tool/build_site.dart` and the site tests, never by the
// app itself.

import 'models.dart';

/// Where the site is served, and the Play Store page it points to.
const siteBaseUrl = 'https://netersoft.github.io/ussd-codes';
const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.neteru.mobileussdcodex';

/// Countries whose pages are in English (the others are in French).
const _englishCountries = {'ng'};

/// The public site generated from the catalog: one page per country, per
/// operator and for the phone codes, plus a sitemap. Keys are paths relative
/// to the site root (`ussd-codes/` on netersoft.github.io).
Map<String, String> buildSite(Catalog catalog) {
  final pages = <String, String>{
    'index.html': _homePage(catalog),
    'telephone/index.html': _devicePage(catalog),
    for (final country in catalog.countries) ...{
      '${country.id}/index.html': _countryPage(catalog, country),
      for (final op in country.operators) '${_operatorPath(op)}index.html': _operatorPage(catalog, country, op),
    },
  };
  pages['sitemap.xml'] = _sitemap(catalog, pages.keys.where((path) => path.endsWith('index.html')));
  return pages;
}

/// Directories the generator owns under the site root: removed before each
/// build so pages of removed countries or operators go away.
bool isGeneratedDirectory(String name) => name == 'telephone' || RegExp(r'^[a-z]{2}$').hasMatch(name);

String _operatorPath(Operator op) => '${op.countryId}/${op.id.substring(op.countryId.length + 1)}/';

class _Texts {
  final String lang;

  const _Texts(this.lang);

  bool get _fr => lang == 'fr';

  String category(CodeCategory category) => switch (category) {
    CodeCategory.account => _fr ? 'Compte et solde' : 'Account and balance',
    CodeCategory.recharge => _fr ? 'Recharge' : 'Top-up',
    CodeCategory.data => 'Internet',
    CodeCategory.transfer => _fr ? 'Transfert de crédit' : 'Credit transfer',
    CodeCategory.money => 'Mobile money',
    CodeCategory.help => _fr ? 'Bip et dépannage' : 'Beep and emergency credit',
    CodeCategory.services => 'Services',
    CodeCategory.device => _fr ? 'Téléphone' : 'Phone',
  };

  String placeholder(ParamType type) => switch (type) {
    ParamType.amount => _fr ? 'montant' : 'amount',
    ParamType.phone => _fr ? 'numéro' : 'number',
    ParamType.pin => _fr ? 'code secret' : 'PIN',
    ParamType.number => _fr ? 'valeur' : 'value',
  };

  String get appName => _fr ? 'Codes USSD' : 'USSD Codes';
  String get getApp => _fr ? "Télécharger l'application sur Google Play" : 'Get the app on Google Play';
  String get appPitch => _fr
      ? "L'application Codes USSD lance ces codes en un geste, remplit les numéros depuis vos contacts et affiche la réponse de l'opérateur. Gratuite, sans publicité, sans collecte de données."
      : 'The USSD Codes app runs these codes in one tap, fills numbers from your contacts and shows the operator’s answer. Free, no ads, no data collected.';
  String countryTitle(String country) => _fr ? 'Codes USSD – $country' : 'USSD codes – $country';
  String operatorTitle(String op, String country) => _fr ? 'Codes USSD $op $country' : '$op $country USSD codes';
  String operatorIntro(String op, String country) => _fr
      ? 'Les codes USSD $op ${_inCountry(country)} : solde, recharge, forfaits internet, transfert de crédit et mobile money. Tapez le code dans le composeur de votre téléphone, puis appelez.'
      : '$op $country USSD codes: balance, top-up, data bundles, airtime transfer and mobile money. Type the code in your phone’s dialer, then call.';
  // "au Bénin", but "en Côte d'Ivoire".
  String _inCountry(String country) => country.startsWith('Côte') ? 'en $country' : 'au $country';

  String formerly(String name) => _fr ? 'anciennement $name' : 'formerly $name';
  String get placeholders => _fr
      ? 'Les valeurs entre ‹ › sont à remplacer : par exemple ‹montant› par 500. Ne communiquez jamais votre code secret.'
      : 'Replace the values between ‹ ›: for instance ‹amount› with 500. Never share your PIN.';
  String get countries => _fr ? 'Pays' : 'Countries';
  String get operators => _fr ? 'Opérateurs' : 'Operators';
  String get phoneCodes => _fr ? 'Codes du téléphone' : 'Phone codes';
  String get phoneIntro => _fr
      ? "Codes gérés par le téléphone lui-même, quel que soit l'opérateur : IMEI, menus de test, renvoi d'appel."
      : 'Codes handled by the phone itself, whatever the operator: IMEI, test menus, call forwarding.';
  String updated(String isoDate) {
    final date = DateTime.parse(isoDate);
    const fr = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    const en = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return _fr
        ? 'Codes vérifiés le ${date.day} ${fr[date.month - 1]} ${date.year}. Une erreur ? Écrivez à '
        : 'Codes checked on ${en[date.month - 1]} ${date.day}, ${date.year}. Spotted an error? Write to ';
  }

  String get home => _fr ? 'Accueil' : 'Home';
  String get homeTitle => _fr ? 'Codes USSD des opérateurs africains' : 'USSD codes of African operators';
  String get homeIntro => _fr
      ? 'Solde, recharge, forfaits internet, transfert de crédit et mobile money : les codes USSD des opérateurs mobiles, vérifiés et classés par pays.'
      : 'Balance, top-up, data bundles, airtime transfer and mobile money: mobile operators’ USSD codes, checked and sorted by country.';
  String codesCount(int count) => _fr ? '$count codes' : '$count codes';
}

String _esc(String text) => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _page({
  required String lang,
  required String title,
  required String description,
  required String path,
  required String body,
  List<(String, String)> breadcrumb = const [],
}) {
  final url = '$siteBaseUrl/${path.replaceAll('index.html', '')}';
  final crumbs = [
    for (final (index, (name, href)) in breadcrumb.indexed) '{"@type":"ListItem","position":${index + 1},"name":"${_esc(name)}","item":"$siteBaseUrl/$href"}',
  ];
  return '''
<!doctype html>
<html lang="$lang">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_esc(title)}</title>
<meta name="description" content="${_esc(description)}">
<link rel="canonical" href="$url">
<style>
  :root { color-scheme: light dark; --text: #202124; --muted: #5f6368; --bg: #ffffff; --accent: #007000; --line: #e0e0e0; --code-bg: #eef6ee; }
  @media (prefers-color-scheme: dark) {
    :root { --text: #f2f2f2; --muted: #a9a9a9; --bg: #202124; --accent: #7dd87d; --line: #3c4043; --code-bg: #2a332a; }
  }
  body { margin: 0; background: var(--bg); color: var(--text); font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  main { max-width: 720px; margin: 0 auto; padding: 24px 16px 48px; }
  nav { padding-bottom: 12px; border-bottom: 1px solid var(--line); font-size: 15px; }
  a { color: var(--accent); }
  h1 { font-size: 28px; line-height: 1.25; margin: 24px 0 8px; }
  h2 { font-size: 20px; margin: 28px 0 8px; }
  .muted { color: var(--muted); }
  ul.codes { list-style: none; padding: 0; margin: 0; }
  ul.codes li { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 4px 16px; padding: 10px 0; border-bottom: 1px solid var(--line); }
  code { font: 600 16px/1.4 ui-monospace, "SF Mono", Menlo, Consolas, monospace; background: var(--code-bg); color: var(--accent); padding: 2px 8px; border-radius: 6px; overflow-wrap: anywhere; }
  .cta { display: inline-block; margin: 16px 0; padding: 10px 18px; border-radius: 999px; background: var(--accent); color: var(--bg); text-decoration: none; font-weight: 600; }
  footer { margin-top: 40px; font-size: 14px; }
</style>
${crumbs.isEmpty ? '' : '<script type="application/ld+json">{"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[${crumbs.join(',')}]}</script>\n'}</head>
<body>
<main>
$body
</main>
</body>
</html>
''';
}

String _nav(_Texts t, List<(String, String)> links) =>
    '<nav>${[for (final (name, href) in links) '<a href="$siteBaseUrl/$href">${_esc(name)}</a>'].join(' › ')}</nav>';

String _footer(_Texts t, Catalog catalog) =>
    '<footer class="muted">${_esc(t.updated(catalog.updatedAt))}<a href="mailto:support.netersoft@gmail.com">support.netersoft@gmail.com</a>.</footer>';

String _appBlock(_Texts t) => '<p>${_esc(t.appPitch)}</p>\n<a class="cta" href="$playStoreUrl">${_esc(t.getApp)}</a>';

String _codeList(_Texts t, Iterable<UssdCode> codes) {
  final items = [
    for (final code in codes)
      '<li><span>${_esc(code.label.resolve(t.lang))}</span><code>${_esc(code.preview(const {}, placeholder: (param) => '‹${t.placeholder(param.type)}›'))}</code></li>',
  ];
  return '<ul class="codes">\n${items.join('\n')}\n</ul>';
}

String _codesByCategory(_Texts t, List<UssdCode> codes) => [
  for (final category in CodeCategory.values)
    if (codes.where((code) => code.category == category).toList() case final inCategory when inCategory.isNotEmpty)
      '<h2>${_esc(t.category(category))}</h2>\n${_codeList(t, inCategory)}',
].join('\n');

String _countryName(Country country, String lang) => country.name.resolve(lang);

String _homePage(Catalog catalog) {
  const t = _Texts('fr');
  final countries = [
    for (final country in catalog.countries)
      '<li><a href="$siteBaseUrl/${country.id}/">${country.flag} ${_esc(_countryName(country, 'fr'))}</a> <span class="muted">· ${_esc(country.operators.map((op) => op.name).join(', '))}</span></li>',
  ];
  const app =
      '{"@context":"https://schema.org","@type":"MobileApplication","name":"Codes USSD","operatingSystem":"Android","applicationCategory":"UtilitiesApplication","offers":{"@type":"Offer","price":"0","priceCurrency":"XOF"},"url":"$playStoreUrl"}';
  return _page(
    lang: 'fr',
    title: '${t.homeTitle} – ${t.appName}',
    description: t.homeIntro,
    path: 'index.html',
    body:
        '''
<nav><strong>${t.appName}</strong></nav>
<h1>${_esc(t.homeTitle)}</h1>
<p>${_esc(t.homeIntro)}</p>
<h2>${t.countries}</h2>
<ul>
${countries.join('\n')}
<li><a href="$siteBaseUrl/telephone/">📱 ${_esc(t.phoneCodes)}</a></li>
</ul>
<h2>${t.appName}</h2>
${_appBlock(t)}
<script type="application/ld+json">$app</script>
${_footer(t, catalog)}''',
  );
}

String _countryPage(Catalog catalog, Country country) {
  final lang = _englishCountries.contains(country.id) ? 'en' : 'fr';
  final t = _Texts(lang);
  final name = _countryName(country, lang);
  final operators = [
    for (final op in country.operators)
      '<li><a href="$siteBaseUrl/${_operatorPath(op)}">${_esc(op.name)}</a>${op.formerName == null ? '' : ' <span class="muted">(${_esc(t.formerly(op.formerName!))})</span>'} <span class="muted">· ${t.codesCount(op.codes.length)}</span></li>',
  ];
  final breadcrumb = [(t.home, ''), (name, '${country.id}/')];
  return _page(
    lang: lang,
    title: t.countryTitle(name),
    description: '${t.countryTitle(name)} : ${country.operators.map((op) => op.name).join(', ')}.',
    path: '${country.id}/index.html',
    breadcrumb: breadcrumb,
    body:
        '''
${_nav(t, [(t.appName, '')])}
<h1>${country.flag} ${_esc(t.countryTitle(name))}</h1>
<h2>${t.operators}</h2>
<ul>
${operators.join('\n')}
</ul>
${_appBlock(t)}
${_footer(t, catalog)}''',
  );
}

String _operatorPage(Catalog catalog, Country country, Operator op) {
  final lang = _englishCountries.contains(country.id) ? 'en' : 'fr';
  final t = _Texts(lang);
  final countryName = _countryName(country, lang);
  final title = t.operatorTitle(op.name, countryName);
  final hasParams = op.codes.any((code) => code.hasParams);
  final breadcrumb = [(t.home, ''), (countryName, '${country.id}/'), (op.name, _operatorPath(op))];
  return _page(
    lang: lang,
    title: title,
    description: t.operatorIntro(op.name, countryName),
    path: '${_operatorPath(op)}index.html',
    breadcrumb: breadcrumb,
    body:
        '''
${_nav(t, [(t.appName, ''), ('${country.flag} $countryName', '${country.id}/')])}
<h1>${_esc(title)}</h1>
${op.formerName == null ? '' : '<p class="muted">${_esc(op.name)}, ${_esc(t.formerly(op.formerName!))}.</p>\n'}<p>${_esc(t.operatorIntro(op.name, countryName))}</p>
${hasParams ? '<p class="muted">${_esc(t.placeholders)}</p>\n' : ''}${_codesByCategory(t, op.codes)}
<h2>${t.appName}</h2>
${_appBlock(t)}
${_footer(t, catalog)}''',
  );
}

String _devicePage(Catalog catalog) {
  const t = _Texts('fr');
  final generic = catalog.deviceCodes.where((code) => code.brand == null);
  final brands = {for (final code in catalog.deviceCodes) ?code.brand};
  final sections = [
    _codeList(t, generic),
    for (final brand in brands)
      '<h2>${_esc(brand[0].toUpperCase() + brand.substring(1))}</h2>\n${_codeList(t, catalog.deviceCodes.where((code) => code.brand == brand))}',
  ];
  return _page(
    lang: 'fr',
    title: '${t.phoneCodes} – ${t.appName}',
    description: t.phoneIntro,
    path: 'telephone/index.html',
    breadcrumb: [(t.home, ''), (t.phoneCodes, 'telephone/')],
    body:
        '''
${_nav(t, [(t.appName, '')])}
<h1>${_esc(t.phoneCodes)}</h1>
<p>${_esc(t.phoneIntro)}</p>
${sections.join('\n')}
${_appBlock(t)}
${_footer(t, catalog)}''',
  );
}

String _sitemap(Catalog catalog, Iterable<String> pages) {
  final urls = [
    for (final path in pages) '  <url><loc>$siteBaseUrl/${path.replaceAll('index.html', '')}</loc><lastmod>${catalog.updatedAt}</lastmod></url>',
  ];
  return '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join('\n')}\n</urlset>\n';
}
