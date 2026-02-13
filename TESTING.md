# Testing

This repository uses a layered testing strategy to balance speed, coverage, and real-backend confidence.

## Test suites and locations

- Unit tests: `test/unit/`
  - Focus on models, repositories, providers, and error handling.
- Widget tests: `test/widget/` and `test/widget_test.dart`
  - Validate UI states and interactions in isolation.
- Backend contract tests (real backend): `test/integration/backend/`
  - Exercise repository calls against a real Komodo backend with golden request/response snapshots.
- Patrol integration tests (UI + backend): `integration_test/`
  - End-to-end resource flows with a fake backend by default, or a real backend when configured.

## Core commands (FVM required)

- Run the full unit + widget suite:
  - `fvm flutter test`
- Run a single test file:
  - `fvm flutter test test/unit/features/servers/data/repositories/server_repository_test.dart`

## Backend contract tests (real backend)

These tests call a real Komodo instance and require environment variables. They are destructive by design and will skip unless explicitly allowed. Make sure to use a test backend instance, do not run against a production system.

Required environment:

- `KOMODO_TEST_BASE_URL`
- `KOMODO_TEST_API_KEY`
- `KOMODO_TEST_API_SECRET`
- `KOMODO_TEST_ALLOW_DESTRUCTIVE=true`
- `KOMODO_TEST_RESET_COMMAND` (required for tests that need a clean backend state)

Recommended workflow:

1) Create a local `.env` file with the variables above.
2) Run the tests with the provided helper (loads `.env` automatically):
   - `./scripts/run_test.sh test/integration/backend/stack_contract_test.dart`
3) Or run the whole backend contract suite directly:
   - `KOMODO_TEST_ALLOW_DESTRUCTIVE=true fvm flutter test test/integration/backend`

Notes:

- Golden snapshots live in `test/golden/` and are checked by backend contract tests.
- Some tests will skip if `KOMODO_TEST_RESET_COMMAND` is not provided.

## Patrol integration tests (UI + backend)

Patrol tests live under `integration_test/` and are wired through a single entrypoint:

- `integration_test/app_test.dart` (aggregates all patrol flows)

Run the full Patrol suite:

- `fvm dart run patrol test -t integration_test/app_test.dart`

Run a single Patrol test file:

- `fvm dart run patrol test -t integration_test/resource_flows/stacks_destroy_test.dart`

### Backend modes for Patrol

Patrol tests default to an in-process fake backend. You can opt into a real backend via `--dart-define`.

Fake backend (default):

- No extra configuration needed.
- Uses an in-process HTTP server (`integration_test/support/fake_komodo_backend.dart`).

Real backend:

- `--dart-define=KOMODO_TEST_BACKEND_MODE=real`
- `--dart-define=KOMODO_TEST_BASE_URL=...`
- `--dart-define=KOMODO_TEST_API_KEY=...`
- `--dart-define=KOMODO_TEST_API_SECRET=...`
- `--dart-define=KOMODO_TEST_ALLOW_DESTRUCTIVE=true` (required for destructive Patrol flows)

Example:

- `fvm dart run patrol test -t integration_test/app_test.dart --dart-define=KOMODO_TEST_BACKEND_MODE=real --dart-define=KOMODO_TEST_BASE_URL=https://... --dart-define=KOMODO_TEST_API_KEY=... --dart-define=KOMODO_TEST_API_SECRET=... --dart-define=KOMODO_TEST_ALLOW_DESTRUCTIVE=true`

### Real-backend resource selectors (Patrol)

Some Patrol tests require known resource names/IDs when running in real-backend mode:

- `KOMODO_TEST_STACK_NAME`
- `KOMODO_TEST_SERVER_NAME`
- `KOMODO_TEST_BUILD_NAME`
- `KOMODO_TEST_PROCEDURE_NAME`
- `KOMODO_TEST_ACTION_NAME`
- `KOMODO_TEST_CONTAINER_NAME`
- `KOMODO_TEST_CONTAINER_ID`
- `KOMODO_TEST_DEPLOYMENT_NAME`
- `KOMODO_TEST_REPO_NAME`
- `KOMODO_TEST_SYNC_NAME`

These are parsed by `integration_test/support/patrol_test_config.dart` and used to decide whether to run or skip a test.

### Patrol helper script (IDE convenience)

- `scripts/flutter_test_to_patrol.sh` wraps `patrol test` and filters IDE-injected Flutter test flags.

## Test data and fixtures

- Golden snapshots: `test/golden/`
- Backend test helpers: `test/support/backend_test_helpers.dart`
- Patrol helpers and fake backend: `integration_test/support/`
- Patrol resource flows: `integration_test/resource_flows/`
- Patrol unhappy-path tests: `integration_test/unhappy/`

## What to run when

- Small refactors: `fvm flutter test`
- Repository/network changes: run relevant backend contract tests in `test/integration/backend/`
- UI/resource flows: run the matching Patrol flow under `integration_test/resource_flows/`
- Error handling changes: run Patrol unhappy-path tests in `integration_test/unhappy/`
