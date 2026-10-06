# Codes USSD - Agent Guide

## Project Setup

```bash
# Install dependencies
flutter pub get

# Generate Slang translations
dart run slang

# Run codegen (Riverpod, go_router, injectable)
dart run build_runner build

# Run app
flutter run --flavor dev
```

## USSD catalog

The codes live in `catalog/` (one JSON file per operator), not in the app code. See `catalog/README.md`.

```bash
# Validate catalog/ and rebuild the bundled assets/catalog/catalog.json
dart run tool/build_catalog.dart
```

- Never change the `id` of a published code: users' favorites refer to it.
- After a merged catalog change, publish with `dart run tool/build_site.dart <netersoft.github.io checkout>` (catalog + public site), then a PR there.
- Bump `version` in `catalog/meta.json` on every data change.

## Code Quality

```bash
flutter analyze
dart format .
flutter test
```

## Architecture

- **Entry point**: `lib/main.dart`
- **Catalog** (`lib/core/catalog/`): pure Dart models, validation and search (also used by `tool/`), plus the repository (bundled copy, remote updates, disk cache)
- **Core layer** (`lib/core/`): providers, services (telephony channel, prefs), library (favorites, personal codes, legacy import), routes
- **View layer** (`lib/view/`): screens, components, modals, themes
- **State management**: Riverpod with code generation (`riverpod_generator`)
- **Routing**: go_router
- **Local storage**: SharedPreferences
- **Native**: `android/app/src/main/kotlin/.../MainActivity.kt`, channel `ussd_codes/telephony` (dial, SIM operators, legacy database)

## Environment

- Copy `.env.example` to `.env` before running (all values are public)
- SDK: `>=3.8.0 <4.0.0`

## Testing

Unit and widget tests live under `test/`.

- `catalog/`: models, sources, repository, search.
- `library/`: legacy import.
- `screens/`: run sheet, operators screen.
- `providers/` and `services/`.

`test/helpers/app_harness.dart` pumps widgets with the bundled catalog and a fake telephony service.

```bash
flutter test
```
