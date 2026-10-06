# Codes USSD

[![Flutter CI](https://github.com/netersoft/ussd-codes/actions/workflows/flutter.yml/badge.svg)](https://github.com/netersoft/ussd-codes/actions/workflows/flutter.yml)

## Description

A directory of USSD codes for mobile operators in West and Central Africa: Benin, Cameroon, Côte d'Ivoire, Mali, Niger, Nigeria, Senegal and Togo. Users run codes in one tap and no longer need to remember them. The app also works offline.

This Flutter app replaces the legacy native Java app ([Play Store](https://play.google.com/store/apps/details?id=com.neteru.mobileussdcodex)). It keeps the same application id, so it ships as an update of the legacy app. It was bootstrapped from the edpage [flutter-starter](https://github.com/edpage-hq/flutter-starter), without its auth, account, media, location and REST API packs.

Features:

- **Codes by country and operator.** The app opens on the user's SIM operator (MCC/MNC, read without any permission).
- **Typed parameters.** Amounts, phone numbers and PINs each get the right keyboard. A PIN is masked and never stored. Every code is confirmed before it runs.
- **Direct run.** The app runs codes directly on Android with the Phone permission, and falls back to the dialer pre-filled with the code. iOS doesn't let apps dial `*`/`#` codes, so the app copies the code there.
- **Personal data.** Users keep favorites and their own codes, and search covers every country.
- **Device codes.** IMEI and test menus, filtered by brand.
- **Catalog updates.** Codes are a versioned catalog, separate from the app (see [catalog/](catalog/README.md)), and can be updated without a store release.
- **Legacy migration.** The first launch imports the legacy app's favorites, personal codes and default country.

## Tech stack

- Mobile: Flutter, Dart SDK `>=3.8.0 <4.0.0`
- State management: Riverpod (`riverpod_generator`, code-gen)
- Routing: go_router (`go_router_builder`)
- Local storage: SharedPreferences
- i18n: [Slang](https://pub.dev/packages/slang) (French base, English)
- Crash reporting and analytics: Firebase (Crashlytics + Analytics), inactive until configured
- Native: a small Kotlin channel (`ussd_codes/telephony` in `MainActivity.kt`) to dial, read the SIM operators and read the legacy app's database

## Prerequisites

- Flutter SDK matching `>=3.8.0 <4.0.0` (CI runs on the `stable` channel)
- A `.env` file (see [Environment variables](#environment-variables))

## Installation

```bash
cp .env.example .env
flutter pub get
dart run slang
dart run build_runner build
flutter run --flavor dev
```

## Environment variables

The app bundles `.env` as an asset, so every value in it is **public**.

| Variable | Description | Example |
|----------|-------------|---------|
| `APP_CATALOG_URL` | Public URL of the built catalog, which the app downloads to update its codes. When empty, the app only uses its bundled catalog. | `https://example.com/catalog.json` |
| `APP_CONTACT_EMAIL` | Where users send code suggestions and corrections. When empty, the contact and report actions are hidden. | `neterustudio@gmail.com` |
| `APP_PRIMARY_COLOR` | Primary theme color, hex | `#008000` |
| `APP_SECONDARY_COLOR` | Secondary theme color, hex | `#32DC32` |
| `APP_ACCENT_COLOR` | Accent theme color, hex | `#f5f5f5` |

`APP_CATALOG_URL` must be reachable without authentication. This repository is private, so its `raw.githubusercontent.com` URLs don't qualify. Publish `assets/catalog/catalog.json` somewhere public (GitHub Pages, a public repo, Firebase Hosting...) before you set it.

## USSD catalog

The codes live in [`catalog/`](catalog/README.md), one JSON file per operator. After editing them:

```bash
dart run tool/build_catalog.dart   # validates and builds assets/catalog/catalog.json
```

[catalog/README.md](catalog/README.md) describes the format, the update flow and the data still to verify.

## Running tests

```bash
flutter test
# with coverage, as run in CI:
flutter test --coverage
```

## Environments

| Env        | URL | Deployment |
|------------|-----|------------|
| Production | [Play Store](https://play.google.com/store/apps/details?id=com.neteru.mobileussdcodex) | Manual upload of the `prod` flavor |

## Contacts

- Tech lead:
- Product owner:

## Architecture

- `lib/core/catalog/`: the catalog in pure Dart (models, validation, search, source assembly), plus `CatalogRepository`. The repository uses the bundled copy, downloads newer versions and caches them on disk.
- `lib/core/library/`: the user's own data (favorites, personal codes) and the one-time legacy import.
- `lib/core/services/telephony/`: dialing, SIM detection and reading the legacy database, through the Android channel.
- `lib/core/providers/`: Riverpod providers.
  - `catalog_provider.dart` holds the catalog, the SIM operators and the device codes.
  - `library_provider.dart` holds favorites, personal codes, the selected country, direct call and startup.
  - `settings_provider.dart` holds language, theme, sharing and contact.
- `lib/view/`: screens, components, modals and theme.
  - Screens: the main shell with the operators, favorites and phone tabs, plus search and settings.
  - Components and modals: code tile, run sheet, add sheet, country picker.
- `tool/build_catalog.dart`: the catalog build and check script.

Runtime composition starts from `lib/main.dart` → `lib/core/bootstrap/app_bootstrap.dart` (env, Firebase, DI, locale) → `lib/app.dart`. `MainScreen` waits for `appStartupProvider` while the native splash stays up. That provider loads the catalog and runs the legacy import.

Generated files (`*.g.dart`, `*.config.dart`) are excluded from git. To rebuild them, run `dart run slang` and `dart run build_runner build`.

## Firebase (Crash Reporting + Analytics)

`lib/firebase_options.dart` is still the starter's placeholder, so Crashlytics and Analytics stay silent no-ops. To turn them on, run `flutterfire configure` with the project's Firebase project. Running a code logs a `run_code` event with the code id and the outcome, never the values typed.

## Quality

```bash
dart format .
flutter analyze
flutter test
```

## Build Flavors (dev / staging / prod)

```bash
flutter run --flavor dev
flutter build appbundle --flavor prod --release
```

Each flavor has its own `applicationId` suffix (`.dev`, `.staging`, none for `prod`) and app name, so all three can be installed side by side. Only `prod` (`com.neteru.mobileussdcodex`) updates the Play Store app.

To update the existing Play Store listing:

- Sign `prod` with the legacy app's upload key (`android/key.properties`, see `android/app/build.gradle`), or request a key reset in the Play Console.
- Keep `versionCode` above the legacy `12` (`version` in `pubspec.yaml`).

iOS flavors need a one-time Xcode setup (schemes and configurations per flavor) before `--flavor` works there. Until then, use `flutter run` without a flavor.

## Release Builds

Pushing a `v*` tag (or running the workflow manually) builds an Android APK (`prod` flavor) and an unsigned iOS build in CI. Both builds need the quality job to pass first. The `ENV_FILE` secret, when set, provides the production `.env`; without it, CI uses `.env.example`.
