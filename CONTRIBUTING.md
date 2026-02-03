# Contributing

Thanks for taking the time to contribute to Komodo Go!

## Setup

- Install FVM and use the pinned Flutter version in `.fvmrc`.
- Install dependencies:
  - `fvm flutter pub get`

## Development workflow

- Run the app: `fvm flutter run`
- Lint: `fvm flutter analyze`
- Tests: `fvm flutter test`
- Codegen (after any `@freezed` or `@riverpod` changes):
  - `fvm dart run build_runner build --delete-conflicting-outputs`

## Pull requests

- Keep changes focused and small when possible.
- Include tests when adding or changing behavior.
- Avoid editing generated files (`*.g.dart`, `*.freezed.dart`).
- Note any migration steps in the PR description.

## Security and secrets

- Never commit API keys, secrets, or real credentials.
- Use `.env.example` to document required environment variables.

## Reporting issues

If you find a bug, open an issue with steps to reproduce, expected behavior,
and actual behavior.
