import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_codes/core/catalog/models.dart';

UssdCode _transfer() => UssdCode.fromJson({
  'id': 'bj-mtn.transfer',
  'label': {'fr': 'Transfert de crédit'},
  'code': '*155*{amount}*{recipient}*{pin}#',
  'category': 'transfer',
  'params': [
    {'key': 'amount', 'type': 'amount', 'label': 'Montant'},
    {'key': 'recipient', 'type': 'phone', 'label': 'Numéro'},
    {'key': 'pin', 'type': 'pin', 'label': 'Code secret'},
  ],
});

Catalog _catalog({List<Map<String, dynamic>> codes = const [], List<Map<String, dynamic>> deviceCodes = const []}) => Catalog.fromJson({
  'schemaVersion': 1,
  'version': 1,
  'updatedAt': '2026-10-06',
  'countries': [
    {
      'id': 'bj',
      'name': {'fr': 'Bénin'},
      'operators': [
        {
          'id': 'bj-mtn',
          'name': 'MTN',
          'mccMnc': ['61603'],
          'codes': codes,
        },
      ],
    },
  ],
  'deviceCodes': deviceCodes,
});

void main() {
  group('UssdCode', () {
    test('fill replaces each placeholder by position', () {
      // The legacy app replaced param labels in the code: a value equal to
      // another param's label broke the code.
      expect(_transfer().fill({'amount': '500', 'recipient': '97000000', 'pin': '1234'}), '*155*500*97000000*1234#');
    });

    test('fill refuses a missing value', () {
      expect(() => _transfer().fill({'amount': '500', 'recipient': ''}), throwsArgumentError);
    });

    test('preview masks secret values and shows placeholders for missing ones', () {
      final preview = _transfer().preview({'amount': '500', 'pin': '1234'}, placeholder: (param) => '<${param.key}>');
      expect(preview, '*155*500*<recipient>*••••#');
    });

    test('a code without params has no placeholders', () {
      final code = UssdCode.fromJson({'id': 'x.balance', 'label': 'Solde', 'code': '*100#', 'category': 'account'});
      expect(code.hasParams, isFalse);
      expect(code.fill(const {}), '*100#');
    });
  });

  group('LocalizedText', () {
    test('falls back to French, then English, then any language', () {
      expect(const LocalizedText({'fr': 'Solde', 'en': 'Balance'}).resolve('en'), 'Balance');
      expect(const LocalizedText({'fr': 'Solde'}).resolve('en'), 'Solde');
      expect(const LocalizedText({'en': 'Data plans'}).resolve('fr'), 'Data plans');
      expect(const LocalizedText({'yo': 'Owo'}).resolve('fr'), 'Owo');
    });
  });

  test('Country.flag builds the flag emoji from the ISO code', () {
    expect(const Country(id: 'bj', name: LocalizedText({'fr': 'Bénin'}), operators: []).flag, '🇧🇯');
  });

  group('Catalog', () {
    test('finds operators by MCC/MNC and codes by id', () {
      final catalog = _catalog(codes: [_transfer().toJson()]);
      expect(catalog.operatorByMccMnc('61603')?.id, 'bj-mtn');
      expect(catalog.operatorByMccMnc('99999'), isNull);
      expect(catalog.entryById('bj-mtn.transfer')?.operator?.id, 'bj-mtn');
    });

    test('validate accepts a well-formed catalog', () {
      expect(_catalog(codes: [_transfer().toJson()]).validate(), isEmpty);
    });

    test('validate reports duplicate ids', () {
      final code = {'id': 'bj-mtn.balance', 'label': 'Solde', 'code': '*124#', 'category': 'account'};
      expect(_catalog(codes: [code, code]).validate(), contains('Duplicate code id: bj-mtn.balance'));
    });

    test('validate reports placeholders without a matching param', () {
      final code = {'id': 'bj-mtn.recharge', 'label': 'Recharge', 'code': '*125*{voucher}#', 'category': 'recharge'};
      expect(_catalog(codes: [code]).validate().single, contains('do not match params'));
    });

    test('validate reports codes that cannot be dialed', () {
      final code = {'id': 'device.test', 'label': 'Test', 'code': '*#0*#=', 'category': 'device'};
      expect(_catalog(deviceCodes: [code]).validate().single, contains('cannot be dialed'));
    });

    test('validate reports ids outside their operator', () {
      final code = {'id': 'bj-moov.balance', 'label': 'Solde', 'code': '*100#', 'category': 'account'};
      expect(_catalog(codes: [code]).validate().single, contains('must start with "bj-mtn."'));
    });

    test('toJson round-trips', () {
      final catalog = _catalog(codes: [_transfer().toJson()]);
      expect(Catalog.fromJson(catalog.toJson()).toJson(), catalog.toJson());
    });
  });

  group('Country.localNumber', () {
    const benin = Country(id: 'bj', name: LocalizedText({'fr': 'Bénin'}), operators: [], dialCode: '229');
    const nigeria = Country(id: 'ng', name: LocalizedText({'fr': 'Nigeria'}), operators: [], dialCode: '234', trunkPrefix: '0');

    test('keeps only the digits of a local number', () {
      expect(benin.localNumber('01 97-00.00 00'), '0197000000');
    });

    test('drops the calling code of the country', () {
      expect(benin.localNumber('+229 01 97 00 00 00'), '0197000000');
      expect(benin.localNumber('00229 0197000000'), '0197000000');
    });

    test('puts the trunk prefix back where the country has one', () {
      expect(nigeria.localNumber('+234 803 123 4567'), '08031234567');
    });

    test('dials foreign numbers in the international format', () {
      expect(benin.localNumber('+228 90 00 00 00'), '0022890000000');
    });
  });

  group('Catalog redirects', () {
    const code = UssdCode(id: 'bj-mtn.forfaits', label: LocalizedText({'fr': 'Forfaits'}), code: '*123#', category: CodeCategory.data);
    Catalog catalogWith(Map<String, String> redirects) => Catalog(
      version: 1,
      updatedAt: '2026-10-06',
      countries: [
        Country(
          id: 'bj',
          name: const LocalizedText({'fr': 'Bénin'}),
          operators: [
            Operator(id: 'bj-mtn', countryId: 'bj', name: 'MTN', codes: const [code], redirects: redirects),
          ],
        ),
      ],
      deviceCodes: const [],
    );

    test('finds a removed code under the code replacing it', () {
      final catalog = catalogWith({'bj-mtn.forfait-5mo': 'bj-mtn.forfaits'});
      expect(catalog.entryById('bj-mtn.forfait-5mo')?.code.id, 'bj-mtn.forfaits');
      expect(catalog.validate(), isEmpty);
    });

    test('rejects redirects to unknown codes, from live codes or other operators', () {
      expect(catalogWith({'bj-mtn.old': 'bj-mtn.missing'}).validate(), [contains('unknown code')]);
      expect(catalogWith({'bj-mtn.forfaits': 'bj-mtn.forfaits'}).validate(), [contains('still a code id')]);
      expect(catalogWith({'bj-moov.old': 'bj-mtn.forfaits'}).validate(), [contains('must start with')]);
    });
  });

  group('DataPlan', () {
    const plan = DataPlan(id: 'bj-mtn.forfait-500', price: 500, volumeMb: 1024, validityHours: 24, code: '*123#', checkedAt: '2026-10-06');

    test('costs its price per GB', () {
      expect(plan.pricePerGb, 500);
      expect(const DataPlan(id: 'x.y', price: 100, volumeMb: 256, validityHours: 24, code: '*1#', checkedAt: '2026-10-06').pricePerGb, 400);
    });

    test('is to confirm after 90 days and hidden after 180', () {
      expect(plan.freshness(DateTime(2026, 12)), PlanFreshness.fresh);
      expect(plan.freshness(DateTime(2027, 1, 10)), PlanFreshness.stale);
      expect(plan.freshness(DateTime(2027, 4, 10)), PlanFreshness.expired);
    });

    test('the catalog rejects unusable plans', () {
      Catalog withPlans(List<DataPlan> plans, {String? source = 'https://example.com'}) => Catalog(
        version: 1,
        updatedAt: '2026-10-06',
        countries: [
          Country(
            id: 'bj',
            name: const LocalizedText({'fr': 'Bénin'}),
            operators: [Operator(id: 'bj-mtn', countryId: 'bj', name: 'MTN', codes: const [], plans: plans, plansSource: source)],
          ),
        ],
        deviceCodes: const [],
      );

      expect(withPlans([plan]).validate(), isEmpty);
      expect(withPlans([plan], source: null).validate(), [contains('plansSource')]);
      expect(
        withPlans([const DataPlan(id: 'bj-mtn.free', price: 0, volumeMb: 10, validityHours: 24, code: '*1#', checkedAt: '2026-10-06')]).validate(),
        [contains('positive')],
      );
      expect(
        withPlans([const DataPlan(id: 'bj-mtn.x', price: 5, volumeMb: 10, validityHours: 24, code: '*1#', checkedAt: '6/10/2026')]).validate(),
        [contains('checkedAt')],
      );
    });
  });
}
