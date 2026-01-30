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
  - `patrol test -t integration_test/resource_flows/stacks_services_logs_test.dart -d BE3A6A62-DF90-4DC9-9249-37BFD2A75742 -v`

Note: Xcode UI tests often run on a temporary cloned simulator instance, which may shut down when the run finishes. The VS Code task re-opens Simulator and boots the target device afterwards.

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

Demo mode includes a stack named **Demo Stack (UI Defined)** whose Compose
contents are loaded from:

- `assets/demo_mode/ui_defined_stack/compose.yml`

Edit that file and restart the app to see the Compose editor update.

## App Store screenshots (Maestro + Storepix)

The project includes a Maestro flow for capturing iOS screenshots and a Storepix
configuration for producing App Store-ready assets.

### Prerequisites

- Maestro installed globally
- Storepix installed globally
- Xcode + iOS Simulator
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

### Generate App Store assets (Storepix)

```bash
cd storepix
storepix
```

Outputs are saved to:

- `storepix/output/iphone-6.5/`

### Screenshot set

1. Home dashboard (dark)
2. Servers list (dark)
3. Server detail (dark)
4. Containers (light)
5. Deployments (light)
6. Settings (light)

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
