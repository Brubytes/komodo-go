## Plan: Resource-Centric Patrol Testing (Android + iOS)

Prioritize Patrol integration coverage around “Resources” flows (view + execute + destructive actions), plus the few in-app CRUD areas you control end-to-end (tags/variables/providers/etc.). Build a single backend harness that can run the same Patrol tests in two modes: deterministic fake backend (local in-process HTTP server + fixtures) for CI and daily dev, and opt-in real backend mode (your locally hosted Komodo) for true E2E validation.

### Steps 6
1. Define a Patrol “flow matrix” for each resource type in [lib/features/](lib/features/) and map to `/read`/`/write`/`/execute` calls.
2. Add Patrol test targets for Resources execute/destructive actions: deployments/stacks/repos/builds/syncs/procedures/actions using their repositories under [lib/features/](lib/features/).
3. Add Patrol CRUD targets for in-app-managed entities (create/delete): tags/variables/providers/registries/builders/alerters (these have explicit create/delete RPCs and are ideal for deterministic fixtures).
4. Create a fake-backend mode: start a local HTTP server inside tests, serve scripted responses for `/auth`, `/read`, `/write`, `/execute`, and feed the app a baseUrl to that server.
5. Create a real-backend mode: read baseUrl + credentials from `--dart-define` (or a secure local file) and run the *same* Patrol flows against your local Komodo instance (including create/delete with a dedicated test namespace/prefix).
6. Stabilize selectors for Patrol: add/standardize Keys/Semantics for resource list rows, overflow menus, “Execute/Destroy/Delete” buttons, and confirm dialogs in the key screens under [lib/features/](lib/features/).

---

## Step 1: Resource Flow Matrix (routes → repositories → RPCs)

This app uses a Komodo RPC-like API:

- Endpoints: `/auth`, `/read`, `/write`, `/execute` (see [lib/core/api/api_client.dart](lib/core/api/api_client.dart))
- Request shape: `{ "type": "SomeRpc", "params": { ... } }` (see `RpcRequest` in [lib/core/api/api_client.dart](lib/core/api/api_client.dart))
- Error mapping: `apiCall(...)` wraps `ApiException`/`DioException` to `Failure` (see [lib/core/api/api_call.dart](lib/core/api/api_call.dart))

All Patrol integration tests should be able to run in:

- **Mocked mode**: a local fake backend responds to these endpoints deterministically.
- **Real-backend mode**: the same flows hit your local Komodo instance.

### Resources tab (most important)

Routes are defined in [lib/core/router/app_router.dart](lib/core/router/app_router.dart).

#### Servers
- **Routes**: `/resources/servers` → `/resources/servers/:id` (see `AppRoutes.servers` + `ServerDetailView` wiring)
- **Repository**: [lib/features/servers/data/repositories/server_repository.dart](lib/features/servers/data/repositories/server_repository.dart)
- **Read RPCs**:
	- `ListServers` (list)
	- `GetServer` (detail)
	- `GetSystemStats` (detail polling)
	- `GetSystemInformation` (detail)
- **Patrol flows**:
	- List → open detail → verify stats/info sections render
	- Navigate away/back (or background/foreground) → verify polling doesn’t crash and refreshes

#### Deployments
- **Routes**: `/resources/deployments` → `/resources/deployments/:id`
- **Repository**: [lib/features/deployments/data/repositories/deployment_repository.dart](lib/features/deployments/data/repositories/deployment_repository.dart)
- **Read RPCs**: `ListDeployments`, `GetDeployment`
- **Write RPCs**: `UpdateDeployment`
- **Execute RPCs**:
	- Lifecycle: `StartDeployment`, `StopDeployment`, `RestartDeployment`, `PauseDeployment`, `UnpauseDeployment`
	- Image/update: `Deploy` (creates/updates container), `PullDeployment`
	- Destructive: `DestroyDeployment`
- **Patrol flows (minimum set)**:
	- List → detail → run `Deploy` → assert UI updates to “running/updated” state
	- Detail → `StopDeployment` → `StartDeployment` → verify status changes
	- Detail → `DestroyDeployment` (confirm dialog) → verify removed from list
	- Detail → edit a single config field (write) → verify updated config displayed

#### Stacks
- **Routes**: `/resources/stacks` → `/resources/stacks/:id`
- **Repository**: [lib/features/stacks/data/repositories/stack_repository.dart](lib/features/stacks/data/repositories/stack_repository.dart)
- **Read RPCs**: `ListStacks`, `GetStack`, `ListStackServices`, `GetStackLog`
- **Write RPCs**: `UpdateStack`
- **Execute RPCs**:
	- `DeployStack`, `PullStack`, `RestartStack`, `PauseStack`, `StartStack`, `StopStack`, `DestroyStack`
- **Patrol flows (minimum set)**:
	- List → detail → open services → verify list renders
	- Detail → open logs → verify log view renders and refreshes
	- Detail → `DeployStack` → verify a “last updated / status” change (or equivalent)
	- Detail → `DestroyStack` (confirm dialog) → verify removed from list

#### Repos
- **Routes**: `/resources/repos` → `/resources/repos/:id`
- **Repository**: [lib/features/repos/data/repositories/repo_repository.dart](lib/features/repos/data/repositories/repo_repository.dart)
- **Read RPCs**: `ListRepos`, `GetRepo`
- **Write RPCs**: `UpdateRepo`
- **Execute RPCs**: `CloneRepo`, `PullRepo`, `BuildRepo`
- **Patrol flows (minimum set)**:
	- List → detail → `PullRepo` → verify success feedback + any updated metadata
	- Detail → change config via `UpdateRepo` → verify persisted

#### Syncs
- **Routes**: `/resources/syncs` → `/resources/syncs/:id`
- **Repository**: [lib/features/syncs/data/repositories/sync_repository.dart](lib/features/syncs/data/repositories/sync_repository.dart)
- **Read RPCs**: `ListResourceSyncs`, `GetResourceSync`
- **Write RPCs**: `UpdateResourceSync`
- **Execute RPCs**: `RunSync`
- **Patrol flows (minimum set)**:
	- List → detail → `RunSync` (optionally with resource filter) → verify run acknowledged
	- Detail → update config → verify persisted

#### Builds
- **Routes**: `/resources/builds` → `/resources/builds/:id`
- **Repository**: [lib/features/builds/data/repositories/build_repository.dart](lib/features/builds/data/repositories/build_repository.dart)
- **Read RPCs**: `ListBuilds`, `GetBuild`, `GetBuilder` (for name resolution)
- **Write RPCs**: `UpdateBuild`
- **Execute RPCs**: `RunBuild`, `CancelBuild`
- **Patrol flows (minimum set)**:
	- List → detail → `RunBuild` → verify build enters “running” state
	- While running → `CancelBuild` → verify “canceled” state

#### Procedures
- **Routes**: `/resources/procedures` → `/resources/procedures/:id`
- **Repository**: [lib/features/procedures/data/repositories/procedure_repository.dart](lib/features/procedures/data/repositories/procedure_repository.dart)
- **Read RPCs**: `ListProcedures`, `GetProcedure`
- **Write RPCs**: `UpdateProcedure`
- **Execute RPCs**: `RunProcedure`
- **Patrol flows (minimum set)**:
	- List → detail → `RunProcedure` → verify run acknowledged
	- Detail → update config → verify persisted

#### Actions
- **Routes**: `/resources/actions` → `/resources/actions/:id`
- **Repository**: [lib/features/actions/data/repositories/action_repository.dart](lib/features/actions/data/repositories/action_repository.dart)
- **Read RPCs**: `ListActions`, `GetAction`
- **Write RPCs**: `UpdateAction`
- **Execute RPCs**: `RunAction` (supports `args`)
- **Patrol flows (minimum set)**:
	- List → detail → run with args (if UI supports) → verify run acknowledged
	- Detail → update config → verify persisted

### Containers tab (also critical)

#### Containers
- **Routes**: `/containers` → `/containers/:serverId/:container` (see `ContainerDetailView`)
- **Repository**: [lib/features/containers/data/repositories/container_repository.dart](lib/features/containers/data/repositories/container_repository.dart)
- **Read RPCs**: `ListDockerContainers`, `GetContainerLog`
- **Execute RPCs**: `StopContainer`, `RestartContainer`
- **Patrol flows (minimum set)**:
	- Pick a server → open a container → view logs
	- Run `RestartContainer` / `StopContainer` → verify state change (or at least success feedback)

### “Create/Delete” flows (best end-to-end coverage)

These are not under the Resources tab, but they’re the highest ROI for **true CRUD** because the app has explicit create/delete UI and calls `/write` with clear RPCs.

#### Tags
- **Route**: `/settings/komodo/tags`
- **Repository**: [lib/features/tags/data/repositories/tag_repository.dart](lib/features/tags/data/repositories/tag_repository.dart)
- **Read/Write RPCs**: `ListTags`, `CreateTag`, `DeleteTag`, `RenameTag`, `UpdateTagColor`

#### Variables
- **Route**: `/settings/komodo/variables`
- **Repository**: [lib/features/variables/data/repositories/variable_repository.dart](lib/features/variables/data/repositories/variable_repository.dart)
- **Read/Write RPCs**: `ListVariables`, `CreateVariable`, `DeleteVariable`, `UpdateVariableValue`, `UpdateVariableDescription`, `UpdateVariableIsSecret`

#### Providers (Git + Docker Registry)
- **Route**: `/settings/komodo/providers`
- **Repositories**:
	- [lib/features/providers/data/repositories/git_provider_repository.dart](lib/features/providers/data/repositories/git_provider_repository.dart)
	- [lib/features/providers/data/repositories/docker_registry_repository.dart](lib/features/providers/data/repositories/docker_registry_repository.dart)
- **Read/Write RPCs**:
	- Git: `ListGitProviderAccounts`, `CreateGitProviderAccount`, `UpdateGitProviderAccount`, `DeleteGitProviderAccount`
	- Docker: `ListDockerRegistryAccounts`, `CreateDockerRegistryAccount`, `UpdateDockerRegistryAccount`, `DeleteDockerRegistryAccount`

#### Builders
- **Route**: `/settings/komodo/builders`
- **Repository**: [lib/features/builders/data/repositories/builder_repository.dart](lib/features/builders/data/repositories/builder_repository.dart)
- **Read/Write RPCs**: `ListBuilders`, `GetBuilder`, `RenameBuilder`, `UpdateBuilder`, `DeleteBuilder`

#### Alerters
- **Route**: `/settings/komodo/alerters` → `/settings/komodo/alerters/:id`
- **Repository**: [lib/features/alerters/data/repositories/alerter_repository.dart](lib/features/alerters/data/repositories/alerter_repository.dart)
- **Read/Write/Execute RPCs**:
	- Read: `ListAlerters`, `GetAlerter`
	- Write: `RenameAlerter`, `UpdateAlerter`, `DeleteAlerter`
	- Execute: `TestAlerter`

### What every Patrol flow should assert (regardless of resource)

- **Screen contract**: list renders, item tap navigates, detail renders
- **Network contract**: correct module endpoint is hit (`/read` vs `/write` vs `/execute`) with the expected `type` string
- **UX contract**: loading state appears; on success, state is refreshed; on error, a visible error state is shown
- **Destructive safety**: confirmation dialog appears; cancel does nothing; confirm performs the action and refreshes list/detail

---

## Step 2: Patrol Scaffolding + Test Architecture (Android + iOS)

Goal: make integration tests first-class (fast to run locally, stable in CI, and able to switch between fake and real backends).

### 2.1 Dependencies

- Add Patrol packages:
	- `dev_dependencies`: `patrol` (and optionally `patrol_finders` if you want the extended finder set)
	- Keep `integration_test` (already present in [pubspec.yaml](pubspec.yaml))

### 2.2 Folder structure (recommendation)

Use the standard integration test location to keep tooling conventional:

- `integration_test/`
	- `app_test.dart` (single entrypoint that wires config + runs grouped flows)
	- `flows/` (reusable flow helpers like `loginFlow`, `openResourceDetail`, `confirmDestructiveAction`)
	- `fixtures/` (JSON or Dart maps for fake backend responses)
	- `backend/` (fake server + request router)

Keep `test/` for unit + widget tests (as today). The current `test/integration/` folder is empty; new Patrol tests should go under `integration_test/`.

### 2.3 Test entrypoint pattern

- Prefer a single `integration_test/app_test.dart` entrypoint that:
	- boots the app in a known state
	- configures backend mode (fake vs real)
	- runs a suite of flows across resources

This keeps shared setup (login, permissions, backend config) in one place.

### 2.4 Backend mode switching (design constraint for later steps)

All Patrol tests should support:

- `BACKEND_MODE=fake` (default): deterministic fake HTTP server
- `BACKEND_MODE=real`: hit a real Komodo backend (locally hosted)

Recommended configuration interface (works on both Android and iOS):

- Use `--dart-define=KOMODO_TEST_BACKEND_MODE=fake|real`
- For real mode: `--dart-define=KOMODO_TEST_BASE_URL=...`, `--dart-define=KOMODO_TEST_API_KEY=...`, `--dart-define=KOMODO_TEST_API_SECRET=...`
- Safety gate for destructive tests:
	- `--dart-define=KOMODO_TEST_ALLOW_DESTRUCTIVE=true` (default false)

### 2.5 How to run (local developer commands)

Document these in the plan so everyone runs tests the same way:

- Unit/widget:
	- `fvm flutter test`
- Patrol (Android + iOS):
	- `fvm dart run patrol test -t integration_test/app_test.dart`
	- Optionally specify device: `--device <id>`

Note: exact Patrol CLI flags can vary by Patrol version; when implementing, lock a Patrol version and copy the recommended commands from Patrol docs into this plan.

### 2.6 Android & iOS project setup expectations

Patrol needs native test runner wiring.

- Android:
	- Ensure instrumentation runner + androidTest setup required by Patrol is added under `android/app/` (currently [android/app/build.gradle.kts](android/app/build.gradle.kts) has no test runner config).
- iOS:
	- Ensure the iOS Runner scheme includes UI tests as required by Patrol.
	- Current scheme file exists at [ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme](ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme).

Implementation detail will be done when we actually add Patrol (Step 4/5), but this plan assumes we will update both platforms.

### 2.7 What makes Patrol tests stable (selectors + structure)

- Avoid selecting by volatile text (timestamps, IDs) where possible.
- Prefer stable selectors:
	- `Key` / `ValueKey` on list rows and primary actions
	- `Semantics(label: ...)` for platform consistency
- Encapsulate UI operations into “flows” (one file per feature area), so tests read like:
	- `await loginFlow(patrol, backendMode);`
	- `await resourcesFlow.openStacks();`
	- `await stackFlow.destroyStack(name: 'patrol-stack-1');`

### 2.8 Offline + unhappy-flow coverage (must-have)

Add explicit integration coverage for failure states. The app already maps network failures and unauthorized errors in [lib/core/api/api_call.dart](lib/core/api/api_call.dart), so tests should validate the UX is correct.

Minimum unhappy-flow test cases (run in fake backend mode):

- **Server unreachable** (connection error / DNS / refused):
	- Launch app with baseUrl pointing to a non-listening port
	- Assert user-facing error: `Failure.network` message (“Cannot reach the server…”) is shown somewhere visible
- **Timeout** (read and execute):
	- Fake backend delays response beyond Dio timeout (or simulates timeout)
	- Assert loading state appears, then a timeout/network error is shown
- **Unauthorized** (401 on `/read` or `/execute`):
	- Fake backend returns 401
	- Assert app redirects to login (router redirect in [lib/core/router/app_router.dart](lib/core/router/app_router.dart)) or shows auth error, depending on current behavior
- **Not found** (404):
	- Navigate to a detail view with an ID that the backend reports missing
	- Assert a clear “not found” message (many repos map `isNotFound` to a specific Failure)
- **Validation/server error** (400/500):
	- For create/update/execute: backend returns a structured error
	- Assert an error surface exists and does not crash

Optional but high-value unhappy flows:

- **Offline mid-flow**:
	- Start on a resource detail, then simulate network drop on refresh/polling
	- Assert the app keeps the screen usable and shows an error state non-destructively
- **Destructive cancel path**:
	- Open delete/destroy confirm dialog → tap Cancel → assert no `/write`/`/execute` request was made

---

## Step 3: Fake Backend Harness (deterministic, stateful, supports unhappy paths)

Goal: run Patrol tests without a real backend by simulating the Komodo HTTP+RPC API closely enough that UI flows are realistic, including errors/timeouts/offline.

### 3.1 Constraints from the real app

- The app uses `Dio(BaseOptions(baseUrl: ...))` with 30s connect/receive timeouts (see [lib/core/providers/dio_provider.dart](lib/core/providers/dio_provider.dart)).
- Auth validation uses `/read` with RPC type `GetVersion` (see [lib/features/auth/data/repositories/auth_repository.dart](lib/features/auth/data/repositories/auth_repository.dart)).
- Error parsing expects non-2xx JSON like `{ "error": "...", "trace": ["..."] }` (see [lib/core/api/api_exception.dart](lib/core/api/api_exception.dart)).

### 3.2 High-level approach

Implement an **in-process HTTP server** in Dart using `dart:io`:

- Start `HttpServer.bind(InternetAddress.loopbackIPv4, 0)` inside the Patrol test process.
- Use a base URL like `http://127.0.0.1:<port>`.
	- This works on both Android and iOS because the server runs inside the same app/test process.
	- Important: the login baseUrl normalizer defaults to `https://` if the user doesn’t include a scheme; therefore tests must provide an explicit `http://...` baseUrl.

The server implements exactly these endpoints:

- `POST /auth`
- `POST /read`
- `POST /write`
- `POST /execute`

Each request body is JSON: `{ "type": "RpcName", "params": <object> }`.

### 3.3 Core primitives

Define these test helpers (names are illustrative):

- `FakeKomodoBackend`
	- Starts/stops the `HttpServer`
	- Holds in-memory state (“database”)
	- Exposes `baseUrl` for the app
- `KomodoScenario`
	- A routing table mapping `(modulePath, rpcType)` → handler
	- Optional request expectations (order, count, predicates)
- `RecordedRequest`
	- Captures `path`, `rpcType`, `params`, `headers`, timestamp
	- Enables assertions like “DestroyStack was called once”

### 3.4 Authentication behavior (minimal)

The app does not use `/auth` today for login; it validates credentials by calling:

- `POST /read` with `type: "GetVersion"`.

So the fake backend must support:

- `GetVersion` returning a valid JSON response (any map is fine as long as parsing doesn’t crash).

Also implement header checking for realism:

- Read `X-Api-Key` and `X-Api-Secret` headers.
- If missing/wrong → respond `401` with `{ "error": "Unauthorized" }`.

This lets Patrol tests cover:

- invalid credentials (login error)
- session invalidation / redirect to login when unauthorized

### 3.5 State model (“fake database”)

Keep the state deliberately small and aligned with what the UI needs.

- Collections keyed by `id` (and optionally `name`):
	- servers, deployments, stacks, repos, syncs, builds, procedures, actions
	- tags, variables
	- providers (git + docker registry), builders, alerters
- Include only fields the UI renders (anything missing should be added iteratively as tests reveal it).

Seed data:

- Provide a default “happy path” seed scenario with at least 1 item per resource list so all list/detail flows have something to open.
- Add a “minimal seed” scenario for targeted tests to avoid over-stubbing.

### 3.6 Routing: mapping RPCs to handlers

Implement a dispatcher:

1) Parse JSON body (`type`, `params`)
2) Select handler based on request path:
	 - `/read` → read handlers
	 - `/write` → write handlers
	 - `/execute` → execute handlers
3) Handler returns either:
	 - `200` + JSON `Map` or `List`
	 - error status + `{ "error": "..." }`

Examples of minimal handlers required by Step 1 flows:

- `/read`:
	- `ListStacks` → list from in-memory stacks
	- `GetStack` → single stack by id/name
	- `GetStackLog` → return a stable log payload
	- `ListStackServices` → return stable service list
	- (repeat similarly for deployments/repos/syncs/builds/procedures/actions/servers)

- `/write`:
	- `UpdateStack` / `UpdateRepo` / `UpdateDeployment` ... → mutate the stored object and return updated object
	- CRUD settings screens:
		- `CreateTag`, `DeleteTag`, `CreateVariable`, `DeleteVariable`, etc.

- `/execute`:
	- `DeployStack`, `DestroyStack`, `RunBuild`, `CancelBuild`, `RunProcedure`, `RunAction`, etc.
	- These can be “ack-only” (200 + `{}`) but should also mutate state when the UI expects follow-up reads to show a changed status.

### 3.7 Deterministic unhappy-path simulation

Support fault injection per `(modulePath, rpcType)`:

- **Offline / unreachable**
	- Don’t start the fake server, or stop it mid-test.
	- App should surface `Failure.network` (see [lib/core/api/api_call.dart](lib/core/api/api_call.dart)).

- **Timeouts**
	- For specific RPCs, delay the response long enough to trigger Dio’s timeouts.
	- Alternatively, accept that 30s is too slow for CI and provide a “test timeouts” mode in the app later (e.g., `--dart-define=KOMODO_TEST_SHORT_TIMEOUTS=true`) to reduce timeouts for tests.
		- If we don’t want app changes, prefer simulating `connectionError` by closing the socket early.

- **HTTP error codes**
	- 401 unauthorized: `{ "error": "Unauthorized" }`
	- 404 not found: `{ "error": "Not found" }`
	- 500 server error: `{ "error": "Internal error" }`
	- Ensure body uses `error` key so [lib/core/api/api_exception.dart](lib/core/api/api_exception.dart) parses cleanly.

- **Scripted sequences**
	- Support “first call fails, second succeeds” (useful for retry/polling flows).

### 3.8 Assertions: verifying the app called the right RPC

Each Patrol flow should be able to assert backend interactions:

- `backend.expectCalled('/execute', 'DestroyStack', times: 1)`
- `backend.expectLastRequestParamsContains({'stack': 'patrol-stack-1'})`
- `backend.expectNoCallsTo('/write')` for destructive cancel tests

This is critical to ensure tests “make sense” and don’t just click UI without verifying behavior.

### 3.9 Fixture format

Start simple:

- Prefer inline Dart maps for early tests (fast iteration).
- Move stable fixtures to JSON in a dedicated folder once settled.

Recommended organization:

- `integration_test/fixtures/seeds/` (seed datasets)
- `integration_test/fixtures/responses/` (static response payloads like logs)



### Further Considerations 2
1. Test data strategy: dedicated “patrol-*” naming/tagging to find and clean up resources deterministically.
2. iOS + Android localhost differences: Android emulator uses `10.0.2.2`, iOS simulator can use `localhost`; plan config accordingly.
