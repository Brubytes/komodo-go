<p align="center">
  <img src="assets/komodo-go-logo_circle.png" alt="Komodo Go logo" width="140">
</p>

# Komodo Go

[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![PR Checks](https://github.com/Brubytes/komodo-go/actions/workflows/flutter-analyze.yml/badge.svg)](https://github.com/Brubytes/komodo-go/actions/workflows/flutter-analyze.yml)

| Platform | Status |
| --- | --- |
| Android | [![Android CI](https://api.codemagic.io/apps/697fac44dbc045a607ea177d/release-android/status_badge.svg)](https://codemagic.io/app/697fac44dbc045a607ea177d/release-android/latest_build) |
| iOS | [![iOS CI](https://api.codemagic.io/apps/697fac44dbc045a607ea177d/release-ios/status_badge.svg)](https://codemagic.io/app/697fac44dbc045a607ea177d/release-ios/latest_build) |


Flutter app to control the Komodo infrastructure management platform.

Website: https://komodogo.eu

## Komodo project

Komodo Go is a third-party client for [Komodo 🦎](https://komo.do). Komodo Go is a native iOS/Android application that allows you to control Komodo on the go. While it covers many options, it is not feature-complete compared to the Komodo Web UI.

## Requirements

- Flutter, pinned via [FVM](https://fvm.app/) in `.fvmrc`
Optional tools:
- [Patrol](https://patrol.leancode.co/) for running integration tests
- [Maestro](https://docs.maestro.dev/) and [storepix](https://www.npmjs.com/package/storepix) for App Store screenshot generation

## Development

- `fvm flutter pub get` to install dependencies
- `fvm dart run build_runner build --delete-conflicting-outputs` to generate code
- `fvm flutter run` to run the app
- `fvm flutter analyze` to analyze the code
- `fvm flutter test` to run tests
  
## Testing

See [TESTING.md](TESTING.md) for the full testing strategy, available test suites, and
step-by-step commands.

### Integration tests (Patrol)

More advanced tests are implemented with [Patrol](https://patrol.leancode.co/) and located in `integration_test/`.

Run the Patrol iOS integration test suite on a simulator via the Patrol CLI:

- `patrol test -t integration_test/app_test.dart -d <SIMULATOR_UDID> -v`
- `patrol test -t integration_test/resource_flows/stacks_services_logs_test.dart -d <SIMULATOR_UDID> -v`

Tip: you can list simulator device IDs with `xcrun simctl list` or `fvm flutter devices`.

Note: Xcode UI tests often run on a temporary cloned simulator instance, which may shut down when the run finishes.

## Releases

- `rc-*` tags trigger Codemagic signed build verification (`release-verify-android`, `release-verify-ios`) without publishing.
- `v*` tags trigger actual release workflows (`release-android`, `release-ios`).
- Release version name is taken from the tag (for example `v1.2.3` -> `1.2.3`), while release build number is auto-incremented from Google Play/TestFlight.

Use the interactive helper from the repository root:

```bash
./scripts/release_tag.sh
```

The helper can also optionally create a GitHub Release for `v*` tags when `gh` is installed and authenticated.

## Demo mode

The app always exposes a demo connection backed by an in-process fake backend.
It is available as an option on the login screen.

- Auto-connect on startup: `--dart-define=KOMODO_DEMO_MODE=true`
- Optional overrides:
  - `KOMODO_DEMO_NAME` (default: `Komodo Demo`)
  - `KOMODO_DEMO_API_KEY` (default: `demo-key`)
  - `KOMODO_DEMO_API_SECRET` (default: `demo-secret`)
  - `KOMODO_DEMO_AVAILABLE` (default: `true`)

## Design system / theming

The app uses a single unified Material 3 theme on both iOS and Android (no platform-specific split, except for the main navigation bar).

- Brand colors:
  - Primary: `#014226`
  - Secondary: `#4EB333`
- Theme entry points:
  - Tokens: [`lib/core/theme/app_tokens.dart`](lib/core/theme/app_tokens.dart)
  - Theme: [`lib/core/theme/app_theme.dart`](lib/core/theme/app_theme.dart)

Guidelines:

- Prefer `Theme.of(context).colorScheme` for UI colors.
- Don’t hard-code hex colors in widgets unless there is a strong reason.

## App Store screenshots (Maestro + storepix)

The project includes a Maestro flow for capturing iOS screenshots and a storepix configuration for producing App Store-ready assets.

### Prerequisites

- [Maestro](https://docs.maestro.dev/getting-started/installing-maestro) installed globally
- [storepix](https://www.npmjs.com/package/storepix) installed globally
- Xcode + iOS Simulator for iOS screenshots
- Android Studio + Android Emulator for Android screenshots
- FVM Flutter (`fvm`)

### Generate raw screenshots (Maestro)

Run the mixed flow (dark for 1-3, light for 4-6):

```bash
.maestro/run_screenshots.sh mixed
```

Outputs are saved to:

- [`.maestro/screenshots/`](.maestro/screenshots/)

### Prepare Storepix inputs

Copy the Maestro outputs into Storepix inputs:

```bash
cp .maestro/screenshots/*.png storepix/screenshots/iPhone/
```

### Generate App Store assets (storepix)

Run from the project root:

```bash
storepix generate
```

Outputs are saved to:

- [`storepix/output/iphone-6.5/`](storepix/output/iphone-6.5/)

or elsewhere depending on your storepix configuration.

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, workflow, and test guidance.

## Community

- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security Policy](SECURITY.md)
