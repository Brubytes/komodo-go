# Repository Guidelines

## Project Structure & Module Organization

- `lib/`: application code.
  - `lib/core/`: shared infrastructure (API client/interceptors, routing, storage, theming, utilities).
  - `lib/features/<feature>/`: feature modules split into `data/` (datasources, repositories, models) and `presentation/` (views, widgets, providers).
  - `lib/shared/`: shared models/providers used across features.
- `test/`: Flutter tests (`test/unit/**` for unit tests, `test/widget_test.dart` for smoke/widget tests).
- `docs/`: project documentation (see `docs/komodo_api.md` for the API reference used by the app).
- `android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/`: Flutter platform projects (usually tool-managed).
- Generated output: `build/`, `.dart_tool/`, `**/*.g.dart`, `**/*.freezed.dart` (do not edit by hand).

## Build, Test, and Development Commands

This repo is pinned to Flutter `3.38.5` via FVM (`.fvmrc`). Prefer running:

- `fvm flutter pub get`: install dependencies.
- `fvm flutter run`: run the app on a connected device/simulator.
- `fvm flutter analyze`: static analysis (lints from `very_good_analysis`).
- `fvm flutter test`: run all tests.
- `dart run build_runner build --delete-conflicting-outputs`: regenerate code for Riverpod/Freezed/JSON (`part '*.g.dart'`, `*.freezed.dart`).

## Coding Style & Naming Conventions

- Use standard Dart formatting (`dart format .`), 2-space indentation, and trailing commas where appropriate.
- File names: `lower_snake_case.dart`; types: `UpperCamelCase`; locals: `lowerCamelCase`.
- Riverpod: keep providers in `presentation/providers/` (or `core/providers/`) and don’t modify generated `*.g.dart` files.

## Testing Guidelines

- Name tests `*_test.dart` and mirror the production path where possible (example: `test/unit/features/auth/...`).
- Use `mocktail` for mocking; keep unit tests fast and deterministic.

## Commit & Pull Request Guidelines

- Follow the existing commit style where possible: short, imperative subjects with a type prefix (examples: `refactor: ...`, `fix: ...`, `feat: ...`).
- PRs should include: a clear description, what changed/why, how it was tested (commands), and screenshots for UI changes.

## Security & Configuration Tips

- Never commit real API credentials. The app uses `flutter_secure_storage`; keep secrets out of logs and sample configs.
