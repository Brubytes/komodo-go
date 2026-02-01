# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Komodo Go is a Flutter app for controlling the Komodo infrastructure management platform. It uses a modern Flutter stack with Riverpod state management, functional programming patterns, and clean architecture principles.

## Project Structure

- `lib/`: application code.
  - `lib/core/`: shared infrastructure (API client/interceptors, routing, storage, theming, utilities).
  - `lib/features/<feature>/`: feature modules split into:
    - `data/` (datasources, repositories, models)
    - `presentation/` (views, widgets, providers)
  - `lib/shared/`: shared models/providers used across features.
- `test/`: Flutter tests (`test/unit/**` for unit tests, `test/widget_test.dart` for smoke/widget tests).
- `android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/`: Flutter platform projects (tool-managed).
- Generated output (do not edit by hand): `build/`, `.dart_tool/`, `**/*.g.dart`, `**/*.freezed.dart`.

## Development Commands

Flutter is pinned via FVM (`.fvmrc`) to `3.38.5`. All Flutter commands must be prefixed with `fvm`:

```bash
# Install dependencies
fvm flutter pub get

# Run the app
fvm flutter run

# Code generation (required after model/provider changes)
fvm dart run build_runner build --delete-conflicting-outputs

# Watch mode for continuous code generation during development
fvm dart run build_runner watch --delete-conflicting-outputs

# Run tests
fvm flutter test

# Run specific test file
fvm flutter test test/unit/features/auth/data/repositories/auth_repository_test.dart

# Run backend contract tests (loads .env if present)
./scripts/run_test.sh test/integration/backend/stack_contract_test.dart

# Lint and analyze
fvm flutter analyze

# Clean build artifacts
fvm flutter clean
```

## Coding Style

- Use standard Dart formatting (2-space indentation, trailing commas where appropriate).
- Names:
  - Files: `lower_snake_case.dart`
  - Types: `UpperCamelCase`
  - Locals: `lowerCamelCase`
- Riverpod:
  - Keep providers in `lib/features/**/presentation/providers/` or `lib/core/providers/`.
  - Don’t modify generated `*.g.dart` files.

## Architecture

### State Management: Riverpod with Code Generation

- All state, repositories, and services are Riverpod providers using `@riverpod` annotation
- Code generation creates provider implementations (`*.g.dart` files)
- Some providers use `keepAlive: true` to persist across invalidations (e.g., auth state, base URL)
- Root `ProviderScope` implements exponential backoff retry for network errors (up to 3 retries)

### Error Handling: Either<Failure, T>

- Uses `fpdart` package for functional error handling
- All repository methods return `Either<Failure, T>` instead of throwing exceptions
- Sealed union `Failure` type with variants: `NetworkFailure`, `ServerFailure`, `AuthFailure`, `UnknownFailure`
- Providers unwrap `Either` using `fold()` and throw exceptions for UI error handling
- User-friendly error messages via `FailureX.displayMessage` extension

### Data Models: Freezed + JSON Serialization

- All models use `@freezed` annotation for immutability
- Sealed union types for state enums (e.g., `DeploymentState`)
- Custom `@JsonKey(readValue: ...)` for complex JSON parsing (e.g., MongoDB ObjectId format)
- Models have private constructors to allow custom methods/getters
- Run code generation after modifying any `@freezed` or `@riverpod` annotated classes
- To get the official API documentation use the komodo-docs MCP server.

### API Client: RPC-Style Pattern

The Komodo API uses a custom RPC-like format where all requests are POST to module endpoints:

- `KomodoApiClient` provides `read()`, `write()`, and `execute()` methods
- Type-safe wrapper: `RpcRequest<T>` with `type` and `params`
- Responses can be `Map<String, dynamic>` (detail endpoints) or `List<dynamic>` (list endpoints)
- Auth headers (`X-Api-Key`, `X-Api-Secret`) added via interceptor

### Feature Structure

Each feature follows clean architecture with three layers:

```
lib/features/{feature_name}/
├── data/
│   ├── models/           # Freezed models with JSON serialization
│   └── repositories/     # Business logic, API calls, Either<Failure, T>
└── presentation/
    ├── providers/        # Riverpod state management
    ├── views/           # Full-screen pages
    └── widgets/         # Reusable UI components
```

## Key Patterns

### Repository Pattern

Repositories catch exceptions and map to domain-level failures:

```dart
Future<Either<Failure, List<Server>>> listServers() async {
  try {
    final response = await _client.read(...);
    return Right(servers);
  } on ApiException catch (e) {
    if (e.isUnauthorized) return const Left(Failure.auth());
    return Left(Failure.server(message: e.message));
  }
}
```

### Conditional Provider Initialization

Providers return `null` when prerequisites aren't met:

```dart
@riverpod
Dio? dio(DioRef ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  if (baseUrl == null) return null;  // No API calls without base URL
  // ... setup Dio
}
```

### Null-Safe Model Getters

Models use custom getters with fallback chains to handle API inconsistencies:

```dart
@freezed
class Server with _$Server {
  const Server._();  // Private constructor for custom methods

  const factory Server({
    ServerInfo? info,
    ServerConfig? config,
  }) = _Server;

  String get address => info?.address ?? config?.address ?? '';
}
```

## Design System

Material 3 theme unified across iOS and Android:

- Primary color: `#014226`
- Secondary color: `#4EB333`
- Theme entry points:
  - Tokens: `lib/core/theme/app_tokens.dart`
  - Theme: `lib/core/theme/app_theme.dart`

**Guidelines:**
- Always use `Theme.of(context).colorScheme` for colors
- Never hard-code hex colors in widgets
- Light mode: no gradients (use solid/tinted surfaces)
- Dark mode: subtle gradients are OK, sparingly
- Avoid platform-adaptive widgets/styles when the goal is consistent UI across platforms.
- Avoid too heavy android styles, should not feel and look like an android app on ios but rather a consistent compromise of ios and android design patterns.

### Detail Pages (Reusable UI Kit)

Detail screens should follow the same layout and components so we can apply a consistent, branded style across the app.

- Import: `package:komodo_go/core/widgets/detail/detail_widgets.dart`
- Components live in: `lib/core/widgets/detail/`

**Layout pattern**
- Hero/header panel: `DetailHeroPanel` with a compact info header + `DetailMetricGrid`
- Sections: `DetailSection` for primary blocks (e.g. Stats / Config / System)
- Inner grouping: `DetailSubCard` to break up long info into digestible chunks

**Surface & color rules**
- Use `DetailSurface` (via `DetailHeroPanel`/`DetailSection`/`DetailSubCard`) for consistent rounding, borders, and theming.
- Prefer a single tint color per screen (defaults to `colorScheme.primary`) instead of introducing many different card colors.
- Keep light mode clean (no gradients); allow subtle depth in dark mode only.

**Pills / badges**
- Use only these tones: `PillTone.success`, `PillTone.warning`, `PillTone.alert`, `PillTone.neutral`.
- Prefer `StatusPill` for boolean/on-off state, `ValuePill` for small key/value facts, `TextPill` for tags/labels.

**Charts**
- Use `DetailHistoryRow` + `SparklineChart` / `DualSparklineChart` for lightweight history graphs.
- Keep chart sizing stable and full-width (avoid layout that constrains the paint area).

## Testing

- Framework: `flutter_test` + `mocktail` for mocking
- Focus: Unit tests for models and repositories
- Mock only external dependencies (storage, API clients)
- Test structure: `setUpAll()` for registrations, `setUp()` for initialization
- Run `fvm flutter test` after changes to verify no regressions
- Lints are driven by `very_good_analysis` via `analysis_options.yaml`.

## Navigation

- `go_router` with single `appRouterProvider`
- Shell route with bottom navigation wrapper
- Auth guard: Unauthenticated users redirect to `/login`
- Router watches `authProvider` for automatic redirects

## Important Notes

### Code Generation is Required

After modifying:
- `@freezed` classes → regenerate with `build_runner`
- `@riverpod` providers → regenerate with `build_runner`
- `@JsonSerializable` models → regenerate with `build_runner`

Generated files (`*.g.dart`, `*.freezed.dart`) are excluded from version control per `.gitignore`.

### API Response Handling

The Komodo API has inconsistencies between endpoints:
- **ListServers**: Returns `info` object with server details
- **GetServer**: Returns `config` object instead, `info` is null
- Models use null-safe getters to handle both formats

### Authentication Flow

1. Credentials stored in `SecureStorageService` (flutter_secure_storage)
2. Base URL stored separately (required for API calls)
3. `authProvider.build()` validates credentials on startup
4. `AuthInterceptor` adds auth headers to all requests
5. Logout clears both credentials and base URL

## Contributing

## Security

- Never commit real API credentials.
- Secrets are stored via `flutter_secure_storage`; keep secrets out of logs and sample configs.
