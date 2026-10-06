import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_codes/core/catalog/models.dart';
import 'package:ussd_codes/core/catalog/search.dart';

void main() {
  const transfer = UssdCode(
    id: 'tg-moov.transfert-de-credit',
    label: LocalizedText({'fr': 'Transfert de crédit'}),
    code: '*102*{amount}*{recipient}*{pin}#',
    category: CodeCategory.transfer,
  );
  const op = Operator(id: 'ng-9mobile', countryId: 'ng', name: '9mobile', formerName: 'Etisalat', codes: []);

  test('ignores case and accents', () {
    expect(matchesQuery(code: transfer, query: 'CREDIT'), isTrue);
    expect(matchesQuery(code: transfer, query: 'crédit'), isTrue);
  });

  test('needs every word to match', () {
    expect(matchesQuery(code: transfer, query: 'transfert credit'), isTrue);
    expect(matchesQuery(code: transfer, query: 'transfert internet'), isFalse);
  });

  test('matches the code itself', () {
    expect(matchesQuery(code: transfer, query: '*102'), isTrue);
  });

  test("matches the operator's current and former names", () {
    expect(matchesQuery(code: transfer, operator: op, query: '9mobile'), isTrue);
    expect(matchesQuery(code: transfer, operator: op, query: 'etisalat'), isTrue);
  });

  test('an empty query matches nothing', () {
    expect(matchesQuery(code: transfer, query: '  '), isFalse);
  });
}
