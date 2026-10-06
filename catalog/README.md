# USSD catalog

The codes shown by the app live here, separate from the app code. The app bundles a built copy (`assets/catalog/catalog.json`) and, when `APP_CATALOG_URL` is set, downloads newer versions of that file. A corrected code reaches users without a new store release.

## Files

```txt
catalog/
├── meta.json             # version (integer) and updatedAt (date)
├── countries.json        # countries, in display order, with their operators
├── operators/<id>.json   # one file per operator: its codes
└── device.json           # codes handled by the phone (IMEI, test menus...)
```

### Country

```json
{
  "id": "ng",
  "name": { "fr": "Nigeria", "en": "Nigeria" },
  "dialCode": "234",
  "trunkPrefix": "0",
  "operators": ["ng-airtel", "ng-mtn"]
}
```

- `dialCode`: the international calling code, without "+". A number picked from the contacts in the international format (`+234 803…`) is turned into the local format the USSD menus expect.
- `trunkPrefix` (optional): the digit dialed before local numbers that the international format drops (`0` in Nigeria: `+234 803…` → `0803…`).

### Operator

```json
{
  "id": "bj-mtn",
  "country": "bj",
  "name": "MTN",
  "formerName": "Etisalat",
  "mccMnc": ["61603"],
  "codes": []
}
```

- `id`: `<country>-<operator>`, where the country is its ISO 3166-1 alpha-2 code.
- `formerName` (optional): the name before a rebranding. Search finds the operator by both names.
- `redirects` (optional): ids of removed codes to the id of the code replacing them (e.g. an expired bundle to the bundles menu). Favorites follow them, including those imported from the legacy app. Never reuse a redirected id.
- `mccMnc`: the operator's SIM MCC+MNC codes. The app uses them to open on the user's operator.

### Code

```json
{
  "id": "bj-mtn.mtn-transfert-de-credit",
  "label": { "fr": "MTN Transfert de crédit" },
  "code": "*155*{amount}*{recipient}*{pin}#",
  "category": "transfer",
  "params": [
    { "key": "amount", "type": "amount", "label": { "fr": "Montant", "en": "Amount" } },
    { "key": "recipient", "type": "phone", "label": { "fr": "Numéro du destinataire", "en": "Recipient number" } },
    { "key": "pin", "type": "pin", "label": { "fr": "Code secret", "en": "PIN" } }
  ]
}
```

- `id`: `<operator id>.<slug>`. **Never change the id of a published code.** Users' favorites refer to it.
- `label`: by language. When the current language is missing, the app falls back to French, then English.
- `code`: the digits, `*`, `#` and `+` to dial. A `{key}` placeholder marks each value the user types.
- `category`: one of `account`, `recharge`, `data`, `transfer`, `money`, `help`, `services` (`device` is for `device.json`).
- `params`: one entry per placeholder, in the same order.
  - `amount` and `number` show a number keyboard.
  - `phone` shows a phone keyboard.
  - `pin` is masked on screen and never stored.
- `brand` (device codes only): the manufacturer the code works on, lowercase (`samsung`).

### Internet bundles

Operators that publish their price list also carry `plans`, for the comparator in the app and the `<country>/forfaits/` pages of the site, and `plansSource`, the page they were checked on:

```json
{
  "id": "tg-togocel.forfait-599",
  "price": 599,
  "volumeMb": 5120,
  "validityHours": 24,
  "note": { "fr": "Net599", "en": "Net599" },
  "code": "*909*241#",
  "checkedAt": "2026-10-06"
}
```

- `price` is in the country's currency (FCFA). `volumeMb` counts 1 GB as 1024 MB, as the operators do.
- `night: true` marks bundles valid at night only (their hours go in `note`). They are compared separately.
- `code` buys the bundle, or opens the operator's bundles menu when there is no direct code.
- `checkedAt` is the day the price was checked. After 90 days the app and the site show « prix à confirmer »; after 180 days they hide the bundle. `tool/build_catalog.dart` warns about bundles older than 90 days: **check the prices every month** on `plansSource`, update them and their `checkedAt`, then publish.
- Leave out bundles limited to some apps (social media passes): they don't compare per GB.

## Changing the catalog

1. Edit the files above.
2. Bump `version` in `meta.json` and set `updatedAt` to today's date. The app only downloads a catalog with a higher version than the one it has.
3. Build and check:

   ```bash
   dart run tool/build_catalog.dart
   flutter test test/catalog
   ```

   The build refuses duplicate ids, placeholders without a param and characters that cannot be dialed. CI fails when `assets/catalog/catalog.json` was not rebuilt.

4. Once merged, publish: `dart run tool/build_site.dart <netersoft.github.io checkout>` writes `ussd-codes/catalog.json` and the site's pages there; open a PR in [netersoft.github.io](https://github.com/netersoft/netersoft.github.io). Installed apps pick it up within 12 hours, or right away with "Check for updates" in the settings.

A change to the format itself (a new field the app must understand) needs an app release first. Bump `Catalog.supportedSchemaVersion` in `lib/core/catalog/models.dart`. Apps that only know the older format then ignore the new catalog rather than misreading it.

## Data status

Checked in October 2026 (catalogs v3 and v4) against the operators' own sites and the regulators' lists:

| Operator | Sources |
|---|---|
| Moov Africa Bénin | moov-africa.bj/codes-utiles |
| Celtiis (Bénin) | Celtiis' official X account and celtiis.bj (Celtiis Cash) |
| MTN Bénin | my.mtn.bj, mtn.bj (`*123#` bundles), ARCEP Bénin list of assigned codes |
| Moov Africa Côte d'Ivoire | moov-africa.ci/codes-utiles, Moov Money codes |
| MTN Côte d'Ivoire | mtn.ci/deal/codes-ussd |
| Orange Côte d'Ivoire | business.orange.ci/codes-pratiques, orange.ci Orange Money codes |
| Orange and MTN Cameroun | art.cm (regulator), orange.cm/codes-utiles |
| Orange Mali | orangemali.com/codes-utiles |
| Moov Africa Malitel | Moov Africa Malitel's Facebook page (Moov Money only) |
| Airtel Niger | Airtel Niger's X account, 2018 (balance only) |
| Zamani Telecom (ex-Orange Niger) | zamanitelecom.com (Zamani Cash FAQ) |
| Nigeria (all four) | NCC harmonised codes, in force since 2023 |
| Orange Sénégal | orange.sn « Code USSD et numéros utiles » |
| Yas Sénégal (ex-Free) | yas.sn, list of USSD codes (2026) |
| Moov Africa Togo | moov-africa.tg/codes-utiles and FAQ |
| Yas Togo (ex-Togocel) | yas.tg FAQ and Mixx by Yas page |

- **Bundles with a price** (« 100Mo/1j/350F ») were removed: their menus and prices had all changed. Each operator now has its bundles menu, which the old ids redirect to.
- **Kept without a current source:** codes no source contradicts but none lists either, mostly voucher top-up syntaxes, Orange Mali Bip and SOS, Moov Niger's buddy numbers and credit transfer, the Zamani services other than Zamani Cash, and Orange Sénégal's Orange Money shortcuts. Check them first when a user reports a code.
- **Bundles** (checked 2026-10-06): Moov, MTN and Celtiis (Bénin), Moov and Yas (Togo), Orange (Côte d'Ivoire). Moov and MTN Côte d'Ivoire publish no price list for phones (MTN's bundles are personalised), so they have none. Celtiis only lists its monthly passes.
- **Thin operators:** Moov Africa Malitel and Airtel Niger have only the codes an official source lists; add codes as users report them.
- **Missing operator:** Expresso (Sénégal), for lack of an official list (third-party sites give `*222#` for the balance).
- **MCC/MNC values** match the public MCC/MNC tables; they are still to be confirmed on real SIMs.
