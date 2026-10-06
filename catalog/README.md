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

## Changing the catalog

1. Edit the files above.
2. Bump `version` in `meta.json` and set `updatedAt` to today's date. The app only downloads a catalog with a higher version than the one it has.
3. Build and check:

   ```bash
   dart run tool/build_catalog.dart
   flutter test test/catalog
   ```

   The build refuses duplicate ids, placeholders without a param and characters that cannot be dialed. CI fails when `assets/catalog/catalog.json` was not rebuilt.

A change to the format itself (a new field the app must understand) needs an app release first. Bump `Catalog.supportedSchemaVersion` in `lib/core/catalog/models.dart`. Apps that only know the older format then ignore the new catalog rather than misreading it.

## Data status

The codes come from the legacy app (v1.3.3, last updated around 2020) and have **not been checked since**. Known points to verify:

- **Prices and bundles.** These change every few months, and most `data` codes are likely out of date.
- **Etisalat Nigeria** has been renamed **9mobile** (`ng-9mobile`). Its codes are the old Etisalat ones.
- **Togocel and Orange Niger.** These operators may also have been rebranded.
- **MCC/MNC values.** These were filled in from public references and should be confirmed on real SIMs.
