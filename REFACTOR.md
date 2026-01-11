# Refactor Audit & Plan

## Scope
Repository audit of `komodo-go` (Flutter + Riverpod). Focus: inconsistencies, bugs, security/perf issues, bad practices, large files, duplication.

## Findings (ordered by severity)

1) **Security: secrets and sensitive payloads are logged in all builds**
- `AuthInterceptor` logs an API key prefix and `LoggingInterceptor` logs full request/response bodies, including error payloads.
- Both interceptors are always attached in `dio_provider.dart` and `createValidationDio`.
- `GoRouter` diagnostics are always enabled.
- Risk: leaking credentials and server data in production logs.
- Files: `lib/core/api/interceptors/auth_interceptor.dart`, `lib/core/api/interceptors/logging_interceptor.dart`, `lib/core/providers/dio_provider.dart`, `lib/core/router/app_router.dart`.

2) **Performance/battery: periodic polling runs even when views are off‑screen**
- `ServerDetailView` and `StackDetailView` start timers in `initState` with no visibility or lifecycle guard.
- `ContainersView` polls every 2.5s across all servers.
- Risk: background network churn, wasted battery, stale UI updates.
- Files: `lib/features/servers/presentation/views/server_detail_view.dart`, `lib/features/stacks/presentation/views/stack_detail_view.dart`, `lib/features/containers/presentation/views/containers_view.dart`, `lib/features/containers/presentation/providers/containers_provider.dart`.

3) **Reliability: dynamic JSON usage for alerters**
- Alerter detail UI mutates and persists `Map<String, dynamic>` directly, with manual parsing inside a giant view.
- Risk: schema drift and runtime errors; inconsistent with the rest of the app’s Freezed models.
- Files: `lib/features/alerters/presentation/views/alerter_detail_view.dart`, `lib/features/alerters/presentation/providers/alerters_provider.dart`, `lib/features/alerters/data/repositories/alerter_repository.dart`.

4) **Observability: debug logging enabled in production**
- `debugLogDiagnostics: true` in router config.
- Risk: internal routing info in production logs + perf overhead.
- File: `lib/core/router/app_router.dart`.

5) **Inconsistent error handling**
- Some providers return empty lists when unauthenticated; others throw exceptions.
- Some repository errors use `print()` while others return structured failures.
- Files: multiple providers/repositories under `lib/features/**`.

6) **Duplication: repository boilerplate repeated across features**
- Common `try/catch`, `Failure` mapping, and “empty query” constants repeated.
- Risk: divergence and maintenance overhead.

7) **Large/monolithic UI files**
- Top non‑generated sizes:
  - `lib/features/alerters/presentation/views/alerter_detail_view.dart` (~77 KB)
  - `lib/features/home/presentation/views/home_view.dart` (~33 KB)
  - `lib/features/stacks/presentation/views/stack_detail_view.dart` (~29 KB)
  - `lib/features/servers/presentation/views/server_detail_view.dart` (~29 KB)
  - `lib/core/router/app_router.dart` (~22 KB)

8) **Test coverage gaps**
- Only model tests and auth repository are covered. No tests for most repositories, providers, or UI flows.
- Files: `test/**`.

## Refactoring Plan (prioritized)

### P0 — Security & release hygiene
- Gate HTTP logging and router diagnostics behind `kDebugMode` / `kReleaseMode`.
- Redact sensitive headers/fields in logs if logging is kept.
- Remove `print()` statements from repositories; replace with a controlled logger compiled out in release.
- Files: `lib/core/api/interceptors/*.dart`, `lib/core/providers/dio_provider.dart`, `lib/core/router/app_router.dart`, `lib/features/*/data/repositories/*_repository.dart`.

### P1 — Polling + resource usage
- Centralize polling into a reusable helper tied to app lifecycle + route visibility.
- Reduce polling frequency or add backoff for expensive endpoints (containers/logs/stats).
- Add concurrency limits or batching for fan‑out calls.

### P2 — Data modeling consistency (Alerters)
- Introduce Freezed models for alerter config + endpoint settings.
- Move parsing/serialization into data layer; UI works with typed state.
- Split `alerter_detail_view.dart` into section widgets.

### P2 — Repository/provider consolidation
- Add shared API call helper to standardize `try/catch` + `Failure` mapping.
- Share common “empty query” constants.
- Standardize provider error behavior (consistent exceptions vs. `AsyncValue.error`).

### P3 — Maintainability
- Split large views into smaller widgets/files.
- Extract reusable detail/pill sections to reduce repetition.

### P3 — Testing
- Add repository tests (mock `KomodoApiClient`).
- Add provider tests for error propagation + polling cancellation.
- Add a widget test for auth flow + connection switching.
