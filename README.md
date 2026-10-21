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

 Komodo Go is a native iOS/Android application that allows you to control Komodo on the go. While it covers many options, it is not feature-complete compared to the Komodo Web UI.

 The app is currently in beta, if you want to join you can find the download links [on the website](https://komodogo.eu/beta).

## Komodo project

Komodo Go is a third-party client for [Komodo 🦎](https://komo.do).

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
- RC verification includes static analysis and the unit/widget suite. CI enforces `pubspec.lock` so verification and publishing use the same resolved packages.
- `v*` tags trigger actual release workflows (`release-android`, `release-ios`).
- Release version name is taken from the tag (for example `v1.2.3` -> `1.2.3`), while release build number is auto-incremented from Google Play/TestFlight.
- Version 0.6.0 requires iOS 15 or later.

Use the interactive helper from the repository root:

```bash
./scripts/release_tag.sh
```

The helper can also optionally create a GitHub Release for `v*` tags when `gh` is installed and authenticated. If `release-notes/<version>.md` exists, the helper uses those curated notes; otherwise it generates notes from merged changes.
On non-`main` branches, it can also open a PR to `main` for version-bump commits.

Release notes for each version come from one place and reach GitHub, the App Store, and Google Play:

- `release-notes/<version>.md`: GitHub release body. Codemagic converts it to plain text for TestFlight "What to Test" and App Store "What's New" (max 4,000 characters).
- `release-notes/<version>.store.txt`: Google Play release notes (max 500 characters).
- `metadata/version/<version>/en-US.json` (optional): App Store description, keywords, promotional text, and URLs submitted with the release.

`scripts/store_release_notes.py` builds Codemagic's `release_notes.json` from these files during `v*` builds, and `rc-*` builds fail early if they're missing or too long. Check locally with `python3 scripts/store_release_notes.py check <version>`. `v*` iOS builds are submitted for App Store review with a manual release.

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

The flows (`.maestro/screenshots*.yaml`) run against a demo build (`--dart-define=KOMODO_DEMO_MODE=true`, mock backend, no real server needed). The default `mixed` mode captures shots 01-05 in dark mode and 06-08 in light mode:

| # | Screen | Mode |
|---|--------|------|
| 01 | Home dashboard ("Needs attention") | dark |
| 02 | Servers list | dark |
| 03 | Server detail | dark |
| 04 | Stack config (compose) | dark |
| 05 | Stack logs | dark |
| 06 | Containers | light |
| 07 | Resources overview | light |
| 08 | Notifications | light |

```bash
# Modes: mixed (default) | light | dark | all
.maestro/run_screenshots.sh --build mixed
```

Options: `--build` (always rebuild the simulator app), `--device "<simulator name>"` (or env `DEVICE_NAME`, default `iPhone 14 Plus`), `--output <dir>` (or env `OUTPUT_DIR`, default `.maestro/screenshots`). Simulators booted by the script are shut down again afterwards. Pick one of `xcrun simctl list devices available`; the capture size is the simulator's native resolution.

Capture the App Store sizes (iPhone 6.9" = 1320x2868, iPad 13" = 2064x2752):

```bash
.maestro/run_screenshots.sh --build --device "iPhone 18 Pro Max" --output .maestro/screenshots/iPhone
.maestro/run_screenshots.sh --device "iPad Pro 13-inch (M5)" --output .maestro/screenshots/iPad
```

Notes:

- Use an iPad Pro 13" simulator for 2064x2752. The iPad Air 13" is 2048x2732 and fails storepix validation.
- If Maestro hangs at startup, something on your machine is listening on a local port that Maestro's Android (adb) discovery probes. Check with `lsof -iTCP -sTCP:LISTEN -P`, or wrap Maestro with a sandbox profile that denies that port via `MAESTRO_CMD_PREFIX="sandbox-exec -f deny.sb"`.
- The raw PNGs are git-ignored. Review every PNG before framing (no spinners, errors or debug banner).

### Prepare Storepix inputs

Copy the raw captures into the per-device Storepix input folders (same file names in both):

```bash
cp .maestro/screenshots/iPhone/*.png storepix/screenshots/iPhone/
cp .maestro/screenshots/iPad/*.png   storepix/screenshots/iPad/
```

Storepix picks `storepix/screenshots/iPhone/` for `iphone-*` devices and `storepix/screenshots/iPad/` for `ipad-*` devices (the config references `./screenshots/<file>.png`).

### Generate App Store assets (storepix)

Run from the project root. The config generates `iphone-6.9` (1320x2868), `iphone-6.5` (1284x2778) and `ipad-13` (2064x2752). The 6.5" size is scaled from the 6.9" captures, which storepix rejects by default, so skip its exact-size validation:

```bash
storepix generate --skip-validation
```

Outputs are saved to `storepix/output/<device>/` (git-ignored):

- `storepix/output/iphone-6.9/`
- `storepix/output/iphone-6.5/`
- `storepix/output/ipad-13/`

Apple requires 6.9" (or 6.5") iPhone and 13" iPad screenshots; PNGs must have no alpha channel (`sips -g hasAlpha <file>` should print `no`). Captions are defined in `storepix/storepix.config.js`.

### Generate Google Play feature graphic (storepix)

This repo includes a dedicated Storepix config for the Google Play feature graphic (1024×500):

- `storepix/storepix.feature-graphic.config.js`

Run from the project root:

```bash
storepix generate \
  --device android-feature-graphic \
  --template feature-graphic \
  --config ./storepix/storepix.feature-graphic.config.js
```

Output:

- `storepix/output/feature-graphic/android-feature-graphic/feature-graphic.png`

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, workflow, and test guidance.

## Community

- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security Policy](SECURITY.md)
