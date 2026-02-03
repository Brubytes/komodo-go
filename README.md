# Komodo Go

[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

Flutter app to control the Komodo infrastructure management platform.

## Requirements

- Flutter is pinned via [FVM](https://fvm.app/) in `.fvmrc`

## Development

- `fvm flutter pub get`
- `fvm flutter run`
- `fvm flutter analyze`
- `fvm flutter test`

## Integration tests (Patrol)

More advanced tests are implemented with [Patrol](https://patrol.leancode.co/) and located in `integration_test/`.

Run the Patrol iOS integration test suite on a simulator via the patrol cli:

- `patrol test -t integration_test/app_test.dart -d <SIMULATOR_UDID> -v`
- `patrol test -t integration_test/resource_flows/stacks_services_logs_test.dart -d <SIMULATOR_UDID> -v`

Tip: you can list simulator device IDs with `xcrun simctl list` or `fvm flutter devices`.

Note: Xcode UI tests often run on a temporary cloned simulator instance, which may shut down when the run finishes.

## Demo mode

The app always exposes a demo connection backed by an in-process fake backend.
It is available as an option on the login screen.

- Auto-connect on startup: `--dart-define=KOMODO_DEMO_MODE=true`
- Optional overrides:
  - `KOMODO_DEMO_NAME` (default: `Komodo Demo`)
  - `KOMODO_DEMO_API_KEY` (default: `demo-key`)
  - `KOMODO_DEMO_API_SECRET` (default: `demo-secret`)
  - `KOMODO_DEMO_AVAILABLE` (default: `true`)

### UI-defined demo stack

Demo mode includes a stack named **Demo Stack (UI Defined)** whose Compose contents are loaded from:

- `assets/demo_mode/ui_defined_stack/compose.yml`

Edit that file and restart the app to see the Compose editor update.

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

- `.maestro/screenshots/`

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

- `storepix/output/iphone-6.5/`

or elsewhere depending on your storepix configuration.

## Design system / theming

The app uses a single unified Material 3 theme on both iOS and Android (no platform-specific split, expect for the main navigation bar).

- Brand colors:
  - Primary: `#014226`
  - Secondary: `#4EB333`
- Theme entry points:
  - Tokens: `lib/core/theme/app_tokens.dart`
  - Theme: `lib/core/theme/app_theme.dart`

Guidelines:

- Prefer `Theme.of(context).colorScheme` for UI colors.
- Don’t hard-code hex colors in widgets unless there is a strong reason.

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, workflow, and test guidance.
