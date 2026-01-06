# Komodo Go

Flutter app to control the Komodo infrastructure management platform.

## Requirements

- Flutter is pinned via FVM (`.fvmrc`) to `3.38.5`.

## Development

- `fvm flutter pub get`
- `fvm flutter run`
- `fvm flutter analyze`
- `fvm flutter test`

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
