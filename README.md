# Komodo Go

Flutter app to control the Komodo infrastructure management platform.

## Requirements

- Flutter is pinned via FVM (`.fvmrc`) to `3.38.5`.

## Development

- `fvm flutter pub get`
- `fvm flutter run`
- `fvm flutter analyze`
- `fvm flutter test`

## Integration tests (Patrol)

Run the Patrol iOS integration test suite on the iPhone 17 Pro simulator:

- VS Code task: `Patrol: iOS (iPhone 17 Pro)`
- CLI:
  - `patrol test -t integration_test/app_test.dart -d BE3A6A62-DF90-4DC9-9249-37BFD2A75742 -v`

Note: Xcode UI tests often run on a temporary cloned simulator instance, which may shut down when the run finishes. The VS Code task re-opens Simulator and boots the target device afterwards.

## Demo mode

Demo mode spins up an in-process fake backend and auto-connects the app with seeded demo data.

- Enable: `--dart-define=KOMODO_DEMO_MODE=true`
- Optional overrides:
  - `KOMODO_DEMO_NAME` (default: `Komodo Demo`)
  - `KOMODO_DEMO_API_KEY` (default: `demo-key`)
  - `KOMODO_DEMO_API_SECRET` (default: `demo-secret`)

## Design system / theming

The app uses a single unified Material 3 theme on both iOS and Android (no platform-specific split).

- Brand colors:
  - Primary: `#014226`
  - Secondary: `#4EB333`
- Theme entry points:
  - Tokens: `lib/core/theme/app_tokens.dart`
  - Theme: `lib/core/theme/app_theme.dart`

Guidelines:

- Prefer `Theme.of(context).colorScheme` for UI colors.
- Don’t hard-code hex colors in widgets unless there is a strong reason.
